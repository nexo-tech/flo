(* Global logger state *)
let global_level = ref Severity.Info

let acquire_atomic_lock lock =
  let rec acquire () =
    if Atomic.compare_and_set lock false true then ()
    else (
      Domain.cpu_relax ();
      acquire ())
  in
  acquire ()

let release_atomic_lock lock =
  Atomic.set lock false

let with_atomic_lock lock f =
  acquire_atomic_lock lock;
  Fun.protect ~finally:(fun () -> release_atomic_lock lock) f

let output_lock = Atomic.make false
let logs_reporter_lock = Atomic.make false
let console_formatter = Flo_format_pretty.with_colors true

let write_line fd line =
  let payload = line ^ "\n" in
  let length = String.length payload in
  let rec write_from offset =
    if offset < length then
      match Unix.write_substring fd payload offset (length - offset) with
      | 0 -> ()
      | written -> write_from (offset + written)
      | exception Unix.Unix_error (Unix.EINTR, _, _) -> write_from offset
  in
  write_from 0

(* Cache for effective namespace levels to improve performance *)
(* Key: namespace string, Value: effective level *)
let level_cache : (string, Severity.t) Hashtbl.t = Hashtbl.create 32
let cache_lock = Atomic.make false

(* Get effective level for namespace with caching *)
let get_effective_level_cached namespace =
  let ns = match namespace with Some s -> s | None -> "" in
  (* Try cache first *)
  let cached =
    with_atomic_lock cache_lock (fun () -> Hashtbl.find_opt level_cache ns)
  in
  match cached with
  | Some level -> level
  | None ->
      (* Not in cache, compute and cache it *)
      let effective_level = Flo_namespace.get_effective_level
        ~namespace:ns ~root_level:!global_level in
      with_atomic_lock cache_lock (fun () ->
        Hashtbl.replace level_cache ns effective_level
      );
      effective_level

(* Clear the level cache (call when global or namespace levels change) *)
let clear_level_cache () =
  with_atomic_lock cache_lock (fun () ->
    Hashtbl.clear level_cache
  )

(* Dispatch record to console *)
let dispatch_record record =
  (* Get effective level for the record's namespace *)
  let effective_level = get_effective_level_cached record.Record.namespace in

  (* Check if record's severity meets the effective level *)
  if Severity.compare record.Record.severity effective_level >= 0 then
    let module F = (val console_formatter : Flo_format_pretty.FORMATTER) in
    let formatted = F.format record in
    with_atomic_lock output_lock (fun () -> write_line Unix.stderr formatted)

(* Helper to create and dispatch record *)
let log_message ?location severity message =
  let record = Record.make ~severity ~message in
  (* Check for namespace in context *)
  let record = match Flo_context.get_namespace () with
    | Some ns -> Record.with_namespace ns record
    | None -> record
  in
  let record = match location with
    | Some loc -> Record.with_location loc record
    | None -> record
  in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let attrs = Flo_context.to_list ctx in
        Record.with_attributes attrs record
    | None -> record
  in
  dispatch_record record

(* Helper to create and dispatch record with explicit namespace *)
let log_message_scoped ?location namespace severity message =
  let record = Record.make ~severity ~message in
  let record = Record.with_namespace namespace record in
  let record = match location with
    | Some loc -> Record.with_location loc record
    | None -> record
  in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let attrs = Flo_context.to_list ctx in
        Record.with_attributes attrs record
    | None -> record
  in
  dispatch_record record

(* Zero-configuration logging *)
let trace ?location msg = log_message ?location Severity.Trace msg
let debug ?location msg = log_message ?location Severity.Debug msg
let info ?location msg = log_message ?location Severity.Info msg
let success ?location msg = log_message ?location Severity.Success msg
let warn ?location msg = log_message ?location Severity.Warn msg
let error ?location msg = log_message ?location Severity.Error msg
let fatal ?location msg = log_message ?location Severity.Fatal msg

(* Printf-style logging *)
let tracef fmt = Printf.ksprintf trace fmt
let debugf fmt = Printf.ksprintf debug fmt
let infof fmt = Printf.ksprintf info fmt
let successf fmt = Printf.ksprintf success fmt
let warnf fmt = Printf.ksprintf warn fmt
let errorf fmt = Printf.ksprintf error fmt
let fatalf fmt = Printf.ksprintf fatal fmt

(* Scoped logging - with explicit namespace *)
let scoped_trace namespace ?location msg =
  log_message_scoped ?location namespace Severity.Trace msg

let scoped_debug namespace ?location msg =
  log_message_scoped ?location namespace Severity.Debug msg

let scoped_info namespace ?location msg =
  log_message_scoped ?location namespace Severity.Info msg

let scoped_success namespace ?location msg =
  log_message_scoped ?location namespace Severity.Success msg

let scoped_warn namespace ?location msg =
  log_message_scoped ?location namespace Severity.Warn msg

let scoped_error namespace ?location msg =
  log_message_scoped ?location namespace Severity.Error msg

let scoped_fatal namespace ?location msg =
  log_message_scoped ?location namespace Severity.Fatal msg

(* Scoped printf-style logging *)
let scoped_tracef namespace fmt =
  Printf.ksprintf (scoped_trace namespace) fmt

let scoped_debugf namespace fmt =
  Printf.ksprintf (scoped_debug namespace) fmt

let scoped_infof namespace fmt =
  Printf.ksprintf (scoped_info namespace) fmt

let scoped_successf namespace fmt =
  Printf.ksprintf (scoped_success namespace) fmt

let scoped_warnf namespace fmt =
  Printf.ksprintf (scoped_warn namespace) fmt

let scoped_errorf namespace fmt =
  Printf.ksprintf (scoped_error namespace) fmt

let scoped_fatalf namespace fmt =
  Printf.ksprintf (scoped_fatal namespace) fmt

(* Structured logging *)
let log_fields ?location severity message ~fields =
  let record = Record.make ~severity ~message in
  (* Check for namespace in context *)
  let record = match Flo_context.get_namespace () with
    | Some ns -> Record.with_namespace ns record
    | None -> record
  in
  let record = match location with
    | Some loc -> Record.with_location loc record
    | None -> record
  in
  let record = Record.with_attributes fields record in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let ctx_attrs = Flo_context.to_list ctx in
        Record.with_attributes ctx_attrs record
    | None -> record
  in
  dispatch_record record

let trace_fields ?location message ~fields =
  log_fields ?location Severity.Trace message ~fields

let debug_fields ?location message ~fields =
  log_fields ?location Severity.Debug message ~fields

let info_fields ?location message ~fields =
  log_fields ?location Severity.Info message ~fields

let success_fields ?location message ~fields =
  log_fields ?location Severity.Success message ~fields

let warn_fields ?location message ~fields =
  log_fields ?location Severity.Warn message ~fields

let error_fields ?location message ~fields =
  log_fields ?location Severity.Error message ~fields

let fatal_fields ?location message ~fields =
  log_fields ?location Severity.Fatal message ~fields

(* Scoped structured logging *)
let scoped_log_fields namespace ?location severity message ~fields =
  let record = Record.make ~severity ~message in
  let record = Record.with_namespace namespace record in
  let record = match location with
    | Some loc -> Record.with_location loc record
    | None -> record
  in
  let record = Record.with_attributes fields record in
  let record = match Flo_context.get_current () with
    | Some ctx ->
        let ctx_attrs = Flo_context.to_list ctx in
        Record.with_attributes ctx_attrs record
    | None -> record
  in
  dispatch_record record

let scoped_trace_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Trace message ~fields

let scoped_debug_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Debug message ~fields

let scoped_info_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Info message ~fields

let scoped_success_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Success message ~fields

let scoped_warn_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Warn message ~fields

let scoped_error_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Error message ~fields

let scoped_fatal_fields namespace ?location message ~fields =
  scoped_log_fields namespace ?location Severity.Fatal message ~fields

(* Common field shortcuts - OpenTelemetry semantic conventions *)
let http_method method_ = ("http.method", Value.string method_)
let http_status status = ("http.status_code", Value.int status)
let user_id id = ("user.id", Value.string id)
let duration_ms ms = ("duration_ms", Value.float ms)
let error_type type_ = ("error.type", Value.string type_)
let error_message msg = ("error.message", Value.string msg)

let severity_of_logs_level = function
  | Logs.App -> Severity.Info
  | Logs.Error -> Severity.Error
  | Logs.Warning -> Severity.Warn
  | Logs.Info -> Severity.Info
  | Logs.Debug -> Severity.Debug

let logs_level_of_severity = function
  | Severity.Trace | Severity.Debug -> Logs.Debug
  | Severity.Info | Severity.Success -> Logs.Info
  | Severity.Warn -> Logs.Warning
  | Severity.Error | Severity.Fatal -> Logs.Error

let trim_trailing_newlines text =
  let rec last_non_newline index =
    if index < 0 then -1
    else
      match text.[index] with
      | '\n' | '\r' -> last_non_newline (index - 1)
      | _ -> index
  in
  match last_non_newline (String.length text - 1) with
  | -1 -> ""
  | index -> String.sub text 0 (index + 1)

let format_tag_value (Logs.Tag.V (definition, value)) =
  Format.asprintf "%a" (Logs.Tag.printer definition) value

let fields_of_logs_tags = function
  | None -> []
  | Some tags ->
      Logs.Tag.fold
        (fun (Logs.Tag.V (definition, _) as tag) fields ->
          (Logs.Tag.name definition, Value.string (format_tag_value tag))
          :: fields)
        tags []
      |> List.rev

let logs_namespace source =
  let name = Logs.Src.name source in
  if String.equal name (Logs.Src.name Logs.default) then None else Some name

let logs_message ?header message =
  match header with
  | None | Some "" -> message
  | Some header -> Printf.sprintf "%s: %s" header message

let dispatch_logs_record source level ?header ?tags message =
  let record =
    Record.make ~severity:(severity_of_logs_level level)
      ~message:(logs_message ?header (trim_trailing_newlines message))
  in
  let record =
    match logs_namespace source with
    | Some namespace -> Record.with_namespace namespace record
    | None -> record
  in
  let fields = fields_of_logs_tags tags in
  let record =
    match fields with
    | [] -> record
    | fields -> Record.with_attributes fields record
  in
  dispatch_record record

let logs_reporter () =
  let report source level ~over continue message_callback =
    let buffer = Buffer.create 256 in
    let formatter = Format.formatter_of_buffer buffer in
    message_callback @@ fun ?header ?tags format_and_arguments ->
    Format.kfprintf
      (fun formatter ->
        Format.pp_print_flush formatter ();
        dispatch_logs_record source level ?header ?tags (Buffer.contents buffer);
        over ();
        continue ())
      formatter format_and_arguments
  in
  { Logs.report }

let install_logs_reporter ?(level = Severity.Trace) () =
  Logs.set_reporter_mutex
    ~lock:(fun () -> acquire_atomic_lock logs_reporter_lock)
    ~unlock:(fun () -> release_atomic_lock logs_reporter_lock);
  Logs.set_reporter (logs_reporter ());
  Logs.set_level ~all:true (Some (logs_level_of_severity level))

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
  (* Preserve existing namespace if present *)
  let ctx = Flo_context.empty in
  let ctx = match Flo_context.get_namespace () with
    | Some ns -> Flo_context.add Flo_context.namespace_key (Value.string ns) ctx
    | None -> ctx
  in
  let ctx = Flo_context.add "trace_id" (Value.string trace_id) ctx in
  Flo_context.with_context ctx f

let with_span span_name f =
  let trace_id = match get_trace_id () with
    | Some id -> id
    | None -> Trace_context.generate_trace_id ()
  in
  let span_id = Trace_context.generate_span_id () in
  (* Preserve existing namespace if present *)
  let ctx = Flo_context.empty in
  let ctx = match Flo_context.get_namespace () with
    | Some ns -> Flo_context.add Flo_context.namespace_key (Value.string ns) ctx
    | None -> ctx
  in
  let ctx = Flo_context.add "trace_id" (Value.string trace_id) ctx in
  let ctx = Flo_context.add "span_id" (Value.string span_id) ctx in
  let ctx = Flo_context.add "span_name" (Value.string span_name) ctx in
  Flo_context.with_context ctx f

let with_user user_id f =
  (* Preserve existing namespace if present *)
  let ctx = Flo_context.empty in
  let ctx = match Flo_context.get_namespace () with
    | Some ns -> Flo_context.add Flo_context.namespace_key (Value.string ns) ctx
    | None -> ctx
  in
  let ctx = Flo_context.add "user_id" (Value.string user_id) ctx in
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

(* Namespace context propagation *)
let with_namespace namespace f =
  Flo_context.with_namespace namespace f

let get_current_namespace () =
  Flo_context.get_namespace ()

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
  global_level := level;
  clear_level_cache ()

let get_level () =
  !global_level

(* Namespace configuration *)
let set_level_for namespace level =
  Flo_namespace.set_level namespace level;
  clear_level_cache ()

let get_level_for namespace =
  Flo_namespace.get_level namespace

let get_effective_level namespace =
  Flo_namespace.get_effective_level ~namespace ~root_level:!global_level

let clear_level_for namespace =
  Flo_namespace.clear_level namespace;
  clear_level_cache ()

let get_all_levels () =
  Flo_namespace.get_all_levels ()

(* Module re-exports for convenience *)
module Severity = Severity
module Location = Location
module Value = Value
module Trace_context = Trace_context
module Record = Record
module Flo_core = Flo_core
module Flo_context = Flo_context
module Flo_namespace = Flo_namespace
module Flo_format_pretty = Flo_format_pretty
module Flo_format_json = Flo_format_json
module Flo_format_logfmt = Flo_format_logfmt
module Flo_sink_console = Flo_sink_console
