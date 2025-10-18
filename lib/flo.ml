(* Global logger state - simplified for Phase 1 *)
let global_level = ref Severity.Info

(* Dispatch record to console *)
let dispatch_record record =
  (* Check global level first *)
  if Severity.compare record.Record.severity !global_level >= 0 then
    (* For Phase 1, write directly to stderr using the formatter *)
    (* Note: This is not thread-safe. Proper implementation will use
       Eio.Mutex or other synchronization in later phases *)
    let formatted = Flo_format_pretty.format record in
    output_string stderr formatted;
    output_char stderr '\n';
    flush stderr

(* Helper to create and dispatch record *)
let log_message severity message =
  let record = Record.make ~severity ~message in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let attrs = Flo_context.to_list ctx in
        Record.with_attributes attrs record
    | None -> record
  in
  dispatch_record record

(* Zero-configuration logging *)
let trace msg = log_message Severity.Trace msg
let debug msg = log_message Severity.Debug msg
let info msg = log_message Severity.Info msg
let success msg = log_message Severity.Success msg
let warn msg = log_message Severity.Warn msg
let error msg = log_message Severity.Error msg
let fatal msg = log_message Severity.Fatal msg

(* Printf-style logging *)
let tracef fmt = Printf.ksprintf trace fmt
let debugf fmt = Printf.ksprintf debug fmt
let infof fmt = Printf.ksprintf info fmt
let successf fmt = Printf.ksprintf success fmt
let warnf fmt = Printf.ksprintf warn fmt
let errorf fmt = Printf.ksprintf error fmt
let fatalf fmt = Printf.ksprintf fatal fmt

(* Structured logging *)
let info_fields message ~fields =
  let record = Record.make ~severity:Severity.Info ~message in
  let record = Record.with_attributes fields record in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let ctx_attrs = Flo_context.to_list ctx in
        Record.with_attributes ctx_attrs record
    | None -> record
  in
  dispatch_record record

(* Common field shortcuts - OpenTelemetry semantic conventions *)
let http_method method_ = ("http.method", Value.string method_)
let http_status status = ("http.status_code", Value.int status)
let user_id id = ("user.id", Value.string id)
let duration_ms ms = ("duration_ms", Value.float ms)
let error_type type_ = ("error.type", Value.string type_)
let error_message msg = ("error.message", Value.string msg)

(* Context getters *)
let get_trace_id () =
  match Flo_context.get_current () with
  | Some ctx ->
      (match Flo_context.get "trace_id" ctx with
       | Some (Value.String s) -> Some s
       | _ -> None)
  | None -> None

let get_span_id () =
  match Flo_context.get_current () with
  | Some ctx ->
      (match Flo_context.get "span_id" ctx with
       | Some (Value.String s) -> Some s
       | _ -> None)
  | None -> None

(* Context propagation *)
let with_trace_id trace_id f =
  let ctx = Flo_context.add "trace_id" (Value.string trace_id) Flo_context.empty in
  Flo_context.with_context ctx f

let with_span span_name f =
  let trace_id = match get_trace_id () with
    | Some id -> id
    | None -> Trace_context.generate_trace_id ()
  in
  let span_id = Trace_context.generate_span_id () in
  let ctx = Flo_context.empty in
  let ctx = Flo_context.add "trace_id" (Value.string trace_id) ctx in
  let ctx = Flo_context.add "span_id" (Value.string span_id) ctx in
  let ctx = Flo_context.add "span_name" (Value.string span_name) ctx in
  Flo_context.with_context ctx f

let with_user user_id f =
  let ctx = Flo_context.add "user_id" (Value.string user_id) Flo_context.empty in
  Flo_context.with_context ctx f

let bind fields =
  match Flo_context.get_current () with
  | Some ctx ->
      let _ctx' = List.fold_left (fun acc (k, v) ->
        Flo_context.add k v acc
      ) ctx fields in
      (* Note: We can't actually update the context in place with Eio's API *)
      (* This is a limitation that will be addressed when we implement proper
         context management in the main API *)
      ()
  | None -> ()

(* Exception handling *)
let catch ?(level=Severity.Error) f =
  try
    Some (f ())
  with exn ->
    let msg = Printf.sprintf "Exception caught: %s" (Printexc.to_string exn) in
    let record = Record.make ~severity:level ~message:msg in
    let record = Record.with_attributes [
      error_type (Printexc.to_string exn);
      ("exception.stacktrace", Value.string (Printexc.get_backtrace ()));
    ] record in
    dispatch_record record;
    None

let exception_ exn =
  let msg = Printf.sprintf "Exception: %s" (Printexc.to_string exn) in
  let record = Record.make ~severity:Severity.Error ~message:msg in
  let record = Record.with_attributes [
    error_type (Printexc.to_string exn);
    ("exception.stacktrace", Value.string (Printexc.get_backtrace ()));
  ] record in
  dispatch_record record

(* Configuration *)
let set_level level =
  global_level := level

let get_level () =
  !global_level

(* Module re-exports for convenience *)
module Severity = Severity
module Location = Location
module Value = Value
module Trace_context = Trace_context
module Record = Record
module Flo_core = Flo_core
module Flo_context = Flo_context
module Flo_format_pretty = Flo_format_pretty
module Flo_format_json = Flo_format_json
module Flo_format_logfmt = Flo_format_logfmt
module Flo_sink_console = Flo_sink_console
