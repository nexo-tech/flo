module type FORMATTER = sig
  val format : Record.t -> string
  val parse : string -> (Record.t, string) result
end

(* Helper: Check if string needs quoting *)
let needs_quoting s =
  s = "" ||
  String.contains s ' ' ||
  String.contains s '=' ||
  String.contains s '"' ||
  String.contains s '\n' ||
  String.contains s '\t' ||
  String.contains s '\\'

(* Helper: Escape string for logfmt *)
let escape_string s =
  let buf = Buffer.create (String.length s + 10) in
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string buf "\\\""
    | '\\' -> Buffer.add_string buf "\\\\"
    | '\n' -> Buffer.add_string buf "\\n"
    | '\r' -> Buffer.add_string buf "\\r"
    | '\t' -> Buffer.add_string buf "\\t"
    | _ -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

(* Helper: Format value for logfmt *)
let format_logfmt_value s =
  if needs_quoting s then
    Printf.sprintf "\"%s\"" (escape_string s)
  else
    s

(* Helper: Format key=value pair *)
let format_pair key value =
  Printf.sprintf "%s=%s" key (format_logfmt_value value)

(* Helper: Flatten Value.t to string representation *)
let value_to_logfmt_string = function
  | Value.String s -> s
  | Value.Int i -> Int64.to_string i
  | Value.Float f -> Printf.sprintf "%g" f
  | Value.Bool true -> "true"
  | Value.Bool false -> "false"
  | Value.Null -> "null"
  | Value.Array _ -> "[array]"  (* Arrays not fully supported in flat format *)
  | Value.Object _ -> "{object}"  (* Objects not fully supported in flat format *)
  | Value.Bytes b -> Printf.sprintf "<bytes:%d>" (Bytes.length b)

(* Format record to logfmt *)
let format record =
  let pairs = ref [] in

  (* Add timestamp *)
  pairs := format_pair "timestamp" (Ptime.to_rfc3339 (Record.get_timestamp record)) :: !pairs;

  (* Add severity *)
  pairs := format_pair "severity" (Severity.to_string record.severity) :: !pairs;
  pairs := format_pair "severity_number" (string_of_int (Severity.to_number record.severity)) :: !pairs;

  (* Add message *)
  pairs := format_pair "message" record.message :: !pairs;

  (* Add location fields if present *)
  (match record.location with
   | Some loc ->
       if loc.file <> "" then
         pairs := format_pair "location_file" loc.file :: !pairs;
       if loc.line > 0 then
         pairs := format_pair "location_line" (string_of_int loc.line) :: !pairs;
       if loc.column > 0 then
         pairs := format_pair "location_column" (string_of_int loc.column) :: !pairs;
       if loc.module_name <> "" then
         pairs := format_pair "location_module" loc.module_name :: !pairs;
       (match loc.function_name with
        | Some fn -> pairs := format_pair "location_function" fn :: !pairs
        | None -> ())
   | None -> ());

  (* Add span context fields if present *)
  (match record.span_context with
   | Some ctx ->
       pairs := format_pair "trace_id" ctx.trace_id :: !pairs;
       pairs := format_pair "span_id" ctx.span_id :: !pairs;
       pairs := format_pair "trace_flags" (string_of_int ctx.trace_flags) :: !pairs;
       (match ctx.parent_span_id with
        | Some parent -> pairs := format_pair "parent_span_id" parent :: !pairs
        | None -> ())
   | None -> ());

  (* Add event_name if present *)
  (match record.event_name with
   | Some name -> pairs := format_pair "event_name" name :: !pairs
   | None -> ());

  (* Add attributes (flattened) *)
  List.iter (fun (key, value) ->
    let value_str = value_to_logfmt_string value in
    pairs := format_pair key value_str :: !pairs
  ) record.attributes;

  (* Join all pairs with spaces *)
  String.concat " " (List.rev !pairs)

(* Parse logfmt string to record *)
let parse logfmt_str =
  try
    (* Simple parser: split by spaces, handling quoted values *)
    let parse_pairs s =
      let len = String.length s in
      let rec skip_whitespace i =
        if i >= len then i
        else if s.[i] = ' ' then skip_whitespace (i + 1)
        else i
      in
      let parse_key i =
        let rec collect j =
          if j >= len || s.[j] = '=' then
            (j, String.sub s i (j - i))
          else
            collect (j + 1)
        in
        if i >= len then (i, "")
        else if s.[i] = '=' then (i, "")
        else collect i
      in
      let parse_value i =
        if i >= len then (i, "")
        else if s.[i] = '"' then
          (* Quoted value *)
          let rec collect j buf =
            if j >= len then
              (j, Buffer.contents buf)
            else if s.[j] = '\\' && j + 1 < len then
              (Buffer.add_char buf s.[j + 1]; collect (j + 2) buf)
            else if s.[j] = '"' then
              (j + 1, Buffer.contents buf)
            else
              (Buffer.add_char buf s.[j]; collect (j + 1) buf)
          in
          collect (i + 1) (Buffer.create 20)
        else
          (* Unquoted value *)
          let rec collect j =
            if j >= len || s.[j] = ' ' then
              (j, String.sub s i (j - i))
            else
              collect (j + 1)
          in
          collect i
      in
      let rec parse_all i acc =
        let i = skip_whitespace i in
        if i >= len then List.rev acc
        else
          let (i, key) = parse_key i in
          if key = "" then parse_all (i + 1) acc
          else if i >= len || s.[i] <> '=' then parse_all (i + 1) acc
          else
            let (i, value) = parse_value (i + 1) in
            parse_all i ((key, value) :: acc)
      in
      parse_all 0 []
    in

    let pairs = parse_pairs logfmt_str in

    (* Extract required fields *)
    let timestamp_str = List.assoc "timestamp" pairs in
    let timestamp = match Ptime.of_rfc3339 timestamp_str with
      | Ok (t, _, _) -> t
      | Error _ -> failwith "Invalid timestamp"
    in

    let severity_str = List.assoc "severity" pairs in
    let severity = match Severity.of_string severity_str with
      | Ok s -> s
      | Error _ -> failwith "Invalid severity"
    in

    let message = List.assoc "message" pairs in

    (* Build record with optional fields *)
    let record = Record.make_with_timestamp ~timestamp ~severity ~message in

    (* Add attributes *)
    let record =
      let attrs = List.filter (fun (k, _) ->
        not (List.mem k ["timestamp"; "severity"; "severity_number"; "message";
                         "location_file"; "location_line"; "location_column";
                         "location_module"; "location_function";
                         "trace_id"; "span_id"; "trace_flags"; "parent_span_id";
                         "event_name"])
      ) pairs in
      if attrs <> [] then
        Record.with_attributes (List.map (fun (k, v) -> (k, Value.string v)) attrs) record
      else
        record
    in

    Ok record
  with
  | Not_found -> Error "Missing required field (timestamp, severity, or message)"
  | Failure msg -> Error msg
  | exn -> Error (Printf.sprintf "Parse error: %s" (Printexc.to_string exn))
