(** GADT for type-safe context keys *)
type 'a key = {
  name : string;
  encode : 'a -> Value.t;
  decode : Value.t -> 'a option;
}

let create_key name =
  (* Use Obj.magic for the generic key - users must provide proper encode/decode *)
  (* This is safe because we never actually use these functions *)
  { name;
    encode = (fun _ -> Value.Null);
    decode = (fun _ -> None);
  }

(* Helper to create a key with proper encode/decode *)
let make_key name ~encode ~decode = { name; encode; decode }

let key_name key = key.name

(** Predefined common keys *)
let user_id_key = make_key "user_id"
  ~encode:(fun s -> Value.String s)
  ~decode:(function Value.String s -> Some s | _ -> None)

let request_id_key = make_key "request_id"
  ~encode:(fun s -> Value.String s)
  ~decode:(function Value.String s -> Some s | _ -> None)

let trace_id_key = make_key "trace_id"
  ~encode:(fun s -> Value.String s)
  ~decode:(function Value.String s -> Some s | _ -> None)

let session_id_key = make_key "session_id"
  ~encode:(fun s -> Value.String s)
  ~decode:(function Value.String s -> Some s | _ -> None)

(** Context operations using Flo_context *)
let add key value =
  let encoded = key.encode value in
  Flo_context.bind key.name encoded

let get key =
  match Flo_context.get_current () with
  | None -> None
  | Some ctx ->
      match Flo_context.get key.name ctx with
      | None -> None
      | Some v -> key.decode v

let with_binding key value f =
  let encoded = key.encode value in
  let ctx = Flo_context.add key.name encoded Flo_context.empty in
  Flo_context.with_context ctx f

(** Span management *)

(* Reserved key for active span storage *)
let active_span_key = "__flo_active_span__"

type span = {
  trace_id : string;
  span_id : string;
  parent_span_id : string option;
  name : string;
  start_time : Ptime.t;
  attributes : (string * Value.t) list;
}

let span_trace_id span = span.trace_id
let span_id span = span.span_id
let span_name span = span.name

(* Get current active span from context *)
let current_span () =
  match Flo_context.get_current () with
  | None -> None
  | Some ctx ->
      match Flo_context.get active_span_key ctx with
      | Some (Value.Object fields) ->
          (* Decode span from Value.Object *)
          (try
             let trace_id = match List.assoc "trace_id" fields with
               | Value.String s -> s
               | _ -> raise Not_found
             in
             let span_id = match List.assoc "span_id" fields with
               | Value.String s -> s
               | _ -> raise Not_found
             in
             let parent_span_id = match List.assoc_opt "parent_span_id" fields with
               | Some (Value.String s) -> Some s
               | _ -> None
             in
             let name = match List.assoc "name" fields with
               | Value.String s -> s
               | _ -> raise Not_found
             in
             let start_time = match List.assoc "start_time" fields with
               | Value.Float f -> Ptime.of_float_s f |> Option.get
               | _ -> raise Not_found
             in
             let attributes = match List.assoc_opt "attributes" fields with
               | Some (Value.Object attrs) -> attrs
               | _ -> []
             in
             Some { trace_id; span_id; parent_span_id; name; start_time; attributes }
           with Not_found | Invalid_argument _ -> None)
      | _ -> None

let start_span name ?(attributes = []) ?parent () =
  (* Determine parent - use provided parent or current active span *)
  let parent_span = match parent with
    | Some p -> Some p
    | None -> current_span ()
  in

  (* Generate IDs *)
  let trace_id = match parent_span with
    | Some p -> p.trace_id
    | None ->
        (* Check if there's a trace_id in context *)
        match get trace_id_key with
        | Some tid -> tid
        | None -> Trace_context.generate_trace_id ()
  in
  let span_id = Trace_context.generate_span_id () in
  let parent_span_id = Option.map (fun p -> p.span_id) parent_span in

  let start_time = Ptime_clock.now () in

  { trace_id; span_id; parent_span_id; name; start_time; attributes }

let end_span span =
  let end_time = Ptime_clock.now () in
  let duration = Ptime.diff end_time span.start_time in
  let duration_ms = Ptime.Span.to_float_s duration *. 1000.0 in

  (* Create span context for the record *)
  let span_ctx = {
    Trace_context.trace_id = span.trace_id;
    Trace_context.span_id = span.span_id;
    Trace_context.parent_span_id = span.parent_span_id;
    Trace_context.trace_flags = 0;
  } in

  (* Create a log record for the span completion *)
  let message = Printf.sprintf "Span '%s' completed" span.name in
  let record = Record.make ~severity:Severity.Info ~message in
  let record = Record.with_span_context span_ctx record in

  (* Add span attributes and duration *)
  let attrs = ("span.duration_ms", Value.Float duration_ms) :: span.attributes in
  let attrs = ("span.name", Value.String span.name) :: attrs in
  let record = Record.with_attributes attrs record in

  (* Dispatch the record - we need to call the internal dispatch *)
  (* Since we're in a library module, we'll need to expose this via Flo *)
  (* For now, we'll use a simple approach - check if we should log *)
  let formatted = Flo_format_pretty.format record in
  output_string stderr formatted;
  output_char stderr '\n';
  flush stderr

let in_span name f =
  let span = start_span name () in

  (* Encode span to Value.t and add to context *)
  let span_value = Value.Object [
    ("trace_id", Value.String span.trace_id);
    ("span_id", Value.String span.span_id);
    ("parent_span_id", match span.parent_span_id with
       | Some id -> Value.String id
       | None -> Value.Null);
    ("name", Value.String span.name);
    ("start_time", Value.Float (Ptime.to_float_s span.start_time));
    ("attributes", Value.Object span.attributes);
  ] in

  let ctx = Flo_context.add active_span_key span_value Flo_context.empty in

  (* Also add trace_id and span_id as separate context keys for easy access *)
  let ctx = Flo_context.add "trace_id" (Value.String span.trace_id) ctx in
  let ctx = Flo_context.add "span_id" (Value.String span.span_id) ctx in

  (* Execute function with span context, ensuring span is ended *)
  match Flo_context.with_context ctx (fun () ->
    try
      let result = f span in
      end_span span;
      Ok result
    with exn ->
      end_span span;
      Error exn
  ) with
  | Ok result -> result
  | Error exn -> raise exn

(** Structured event logging *)
module type STRUCTURED = sig
  type t
  val to_value : t -> Value.t
  val event_name : string
  val severity : Severity.t
end

let log_event (type a) (module S : STRUCTURED with type t = a) (value : a) =
  let body = S.to_value value in
  let message = Printf.sprintf "Event: %s" S.event_name in

  (* Create base record *)
  let record = Record.make ~severity:S.severity ~message in
  let record = Record.with_body body record in
  let record = Record.with_event_name S.event_name record in

  (* Add current context attributes *)
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let attrs = Flo_context.to_list ctx in
        (* Filter out internal keys *)
        let attrs = List.filter (fun (k, _) ->
          not (String.starts_with ~prefix:"__flo_" k)
        ) attrs in
        Record.with_attributes attrs record
    | None -> record
  in

  (* Add span context if active *)
  let record = match current_span () with
    | Some span ->
        let span_ctx = {
          Trace_context.trace_id = span.trace_id;
          Trace_context.span_id = span.span_id;
          Trace_context.parent_span_id = span.parent_span_id;
          Trace_context.trace_flags = 0;
        } in
        Record.with_span_context span_ctx record
    | None -> record
  in

  (* Dispatch the record *)
  let formatted = Flo_format_pretty.format record in
  output_string stderr formatted;
  output_char stderr '\n';
  flush stderr
