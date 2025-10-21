type t = {
  timestamp : Ptime.t;
  observed_timestamp : Ptime.t option;
  severity : Severity.t;
  message : string;
  location : Location.t option;
  span_context : Trace_context.span_context option;
  attributes : (string * Value.t) list;
  body : Value.t option;
  event_name : string option;
  namespace : string option;
}

(* Get current time *)
let now () =
  match Ptime.of_float_s (Unix.gettimeofday ()) with
  | Some t -> t
  | None -> Ptime.epoch  (* Fallback to epoch if time is invalid *)

(* Construction *)
let make ~severity ~message = {
  timestamp = now ();
  observed_timestamp = None;
  severity;
  message;
  location = None;
  span_context = None;
  attributes = [];
  body = None;
  event_name = None;
  namespace = None;
}

let make_with_timestamp ~timestamp ~severity ~message = {
  timestamp;
  observed_timestamp = None;
  severity;
  message;
  location = None;
  span_context = None;
  attributes = [];
  body = None;
  event_name = None;
  namespace = None;
}

(* Builder pattern helpers *)
let with_location location record =
  { record with location = Some location }

let with_span_context span_context record =
  { record with span_context = Some span_context }

let with_attributes attributes record =
  { record with attributes = record.attributes @ attributes }

let with_body body record =
  { record with body = Some body }

let with_event_name event_name record =
  { record with event_name = Some event_name }

let with_observed_timestamp observed_timestamp record =
  { record with observed_timestamp = Some observed_timestamp }

let with_namespace namespace record =
  { record with namespace = Some namespace }

let namespace record =
  record.namespace

(* Utilities *)
let get_timestamp record =
  match record.observed_timestamp with
  | Some t -> t
  | None -> record.timestamp

let to_string record =
  let ts = Ptime.to_rfc3339 (get_timestamp record) in
  let severity_str = Severity.to_string record.severity in
  let loc_str = match record.location with
    | Some loc -> Printf.sprintf " [%s]" (Location.to_string loc)
    | None -> ""
  in
  let trace_str = match record.span_context with
    | Some ctx ->
        Printf.sprintf " trace_id=%s span_id=%s"
          ctx.trace_id ctx.span_id
    | None -> ""
  in
  let attrs_str = match record.attributes with
    | [] -> ""
    | attrs ->
        let pairs = List.map (fun (k, v) ->
          Printf.sprintf "%s=%s" k (Value.to_string v)
        ) attrs in
        Printf.sprintf " {%s}" (String.concat ", " pairs)
  in
  let event_str = match record.event_name with
    | Some name -> Printf.sprintf " event=%s" name
    | None -> ""
  in
  let namespace_str = match record.namespace with
    | Some ns -> Printf.sprintf " [%s]" ns
    | None -> ""
  in
  Printf.sprintf "[%s] %s%s%s: %s%s%s%s"
    ts severity_str namespace_str loc_str record.message trace_str event_str attrs_str
