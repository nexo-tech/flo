module type FORMATTER = sig
  val format : Record.t -> string
  val parse : string -> (Record.t, string) result
end

(* Convert record to JSON *)
let record_to_json record =
  let fields = [
    ("timestamp", `String (Ptime.to_rfc3339 (Record.get_timestamp record)));
    ("severity", `String (Severity.to_string record.severity));
    ("severity_number", `Int (Severity.to_number record.severity));
    ("message", `String record.message);
  ] in

  (* Add optional observed_timestamp *)
  let fields = match record.observed_timestamp with
    | Some ts ->
        ("observed_timestamp", `String (Ptime.to_rfc3339 ts)) :: fields
    | None -> fields
  in

  (* Add attributes if present *)
  let fields =
    if record.attributes <> [] then
      let attrs_json = `Assoc (List.map (fun (k, v) ->
        (k, Value.to_yojson v)
      ) record.attributes) in
      ("attributes", attrs_json) :: fields
    else
      fields
  in

  (* Add location if present *)
  let fields = match record.location with
    | Some loc ->
        let loc_json = `Assoc [
          ("file", `String loc.file);
          ("line", `Int loc.line);
          ("column", `Int loc.column);
          ("module_name", `String loc.module_name);
        ] in
        let loc_json = match loc.function_name with
          | Some fn ->
              (match loc_json with
               | `Assoc fields -> `Assoc (("function_name", `String fn) :: fields)
               | _ -> loc_json)
          | None -> loc_json
        in
        ("location", loc_json) :: fields
    | None -> fields
  in

  (* Add span_context if present *)
  let fields = match record.span_context with
    | Some ctx ->
        let ctx_fields = [
          ("trace_id", `String ctx.trace_id);
          ("span_id", `String ctx.span_id);
          ("trace_flags", `Int ctx.trace_flags);
        ] in
        let ctx_fields = match ctx.parent_span_id with
          | Some parent -> ("parent_span_id", `String parent) :: ctx_fields
          | None -> ctx_fields
        in
        ("span_context", `Assoc ctx_fields) :: fields
    | None -> fields
  in

  (* Add event_name if present *)
  let fields = match record.event_name with
    | Some name -> ("event_name", `String name) :: fields
    | None -> fields
  in

  (* Add body if present *)
  let fields = match record.body with
    | Some body -> ("body", Value.to_yojson body) :: fields
    | None -> fields
  in

  (* Add namespace if present *)
  let fields = match record.namespace with
    | Some ns -> ("namespace", `String ns) :: fields
    | None -> fields
  in

  `Assoc (List.rev fields)

(* Format record as JSON string *)
let format record =
  let json = record_to_json record in
  Yojson.Safe.to_string json

(* Parse JSON string to record *)
let parse json_str =
  try
    let open Yojson.Safe.Util in
    let json = Yojson.Safe.from_string json_str in

    (* Parse required fields *)
    let timestamp_str = json |> member "timestamp" |> to_string in
    let timestamp = match Ptime.of_rfc3339 timestamp_str with
      | Ok (t, _, _) -> t
      | Error _ -> failwith "Invalid timestamp"
    in

    let severity_str = json |> member "severity" |> to_string in
    let severity = match Severity.of_string severity_str with
      | Ok s -> s
      | Error _ -> failwith "Invalid severity"
    in

    let message = json |> member "message" |> to_string in

    (* Parse optional observed_timestamp *)
    let observed_timestamp =
      try
        let ts_str = json |> member "observed_timestamp" |> to_string in
        match Ptime.of_rfc3339 ts_str with
        | Ok (t, _, _) -> Some t
        | Error _ -> None
      with _ -> None
    in

    (* Parse optional attributes *)
    let attributes =
      try
        let attrs_json = json |> member "attributes" |> to_assoc in
        List.map (fun (k, v) -> (k, Value.of_yojson v)) attrs_json
      with _ -> []
    in

    (* Parse optional location *)
    let location =
      try
        let loc_json = json |> member "location" in
        let file = loc_json |> member "file" |> to_string in
        let line = loc_json |> member "line" |> to_int in
        let column = loc_json |> member "column" |> to_int in
        let module_name = loc_json |> member "module_name" |> to_string in
        let function_name =
          try Some (loc_json |> member "function_name" |> to_string)
          with _ -> None
        in
        Some { Location.file; line; column; module_name; function_name }
      with _ -> None
    in

    (* Parse optional span_context *)
    let span_context =
      try
        let ctx_json = json |> member "span_context" in
        let trace_id = ctx_json |> member "trace_id" |> to_string in
        let span_id = ctx_json |> member "span_id" |> to_string in
        let trace_flags = ctx_json |> member "trace_flags" |> to_int in
        let parent_span_id =
          try Some (ctx_json |> member "parent_span_id" |> to_string)
          with _ -> None
        in
        Some { Trace_context.trace_id; span_id; parent_span_id; trace_flags }
      with _ -> None
    in

    (* Parse optional event_name *)
    let event_name =
      try Some (json |> member "event_name" |> to_string)
      with _ -> None
    in

    (* Parse optional body *)
    let body =
      try
        let body_json = json |> member "body" in
        Some (Value.of_yojson body_json)
      with _ -> None
    in

    (* Parse optional namespace *)
    let namespace =
      try Some (json |> member "namespace" |> to_string)
      with _ -> None
    in

    (* Construct record *)
    let record = Record.make_with_timestamp ~timestamp ~severity ~message in
    let record = match observed_timestamp with
      | Some ts -> Record.with_observed_timestamp ts record
      | None -> record
    in
    let record = match location with
      | Some loc -> Record.with_location loc record
      | None -> record
    in
    let record = match span_context with
      | Some ctx -> Record.with_span_context ctx record
      | None -> record
    in
    let record = if attributes <> [] then
      Record.with_attributes attributes record
    else
      record
    in
    let record = match event_name with
      | Some name -> Record.with_event_name name record
      | None -> record
    in
    let record = match body with
      | Some b -> Record.with_body b record
      | None -> record
    in
    let record = match namespace with
      | Some ns -> Record.with_namespace ns record
      | None -> record
    in

    Ok record
  with
  | Yojson.Json_error msg -> Error (Printf.sprintf "JSON parse error: %s" msg)
  | exn -> Error (Printf.sprintf "Parse error: %s" (Printexc.to_string exn))
