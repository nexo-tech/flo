(** Eio integration for distributed tracing.

    This module provides integration between Flo logging and Eio's
    fiber-local context, with support for:
    - W3C Trace Context extraction from HTTP headers
    - Trace context injection into HTTP headers
    - Fiber-local context propagation
    - HTTP request/response context management
*)

(** {1 OpenTelemetry HTTP Context Extraction} *)

(** Extract W3C Trace Context from HTTP headers.

    Looks for the "traceparent" header and parses it according to the
    W3C Trace Context specification. The traceparent format is:
    "00-{trace_id}-{span_id}-{trace_flags}"

    Example:
    {[
      let headers = [
        ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
        ("content-type", "application/json");
      ] in
      match extract_trace_context headers with
      | Some ctx -> Printf.printf "trace_id: %s\n" ctx.trace_id
      | None -> Printf.printf "No trace context\n"
    ]}

    @param headers List of (name, value) header pairs (case-insensitive)
    @return Some span_context if traceparent found and valid, None otherwise
*)
val extract_trace_context :
  (string * string) list -> Trace_context.span_context option

(** Inject W3C Trace Context into HTTP headers.

    Generates a "traceparent" header from the span context and returns
    the updated header list.

    Example:
    {[
      let ctx = {
        trace_id = "0af7651916cd43dd8448eb211c80319c";
        span_id = "b7ad6b7169203331";
        parent_span_id = None;
        trace_flags = 1;
      } in
      let headers = inject_trace_context ctx in
      (* headers = [("traceparent", "00-...-...-01")] *)
    ]}

    @param span_context The span context to inject
    @return List of headers with traceparent added
*)
val inject_trace_context :
  Trace_context.span_context -> (string * string) list

(** {1 HTTP Context Management} *)

(** Execute HTTP handler with extracted trace context.

    This function:
    1. Extracts W3C Trace Context from headers
    2. Creates a new span for the HTTP request
    3. Binds it to the current fiber's context
    4. Executes the handler function
    5. Automatically ends the span

    Example:
    {[
      let handle_request headers =
        with_http_context ~headers (fun () ->
          Flo.info "Processing request";
          (* trace_id and span_id are automatically in context *)
          process_request ()
        )
    ]}

    @param headers HTTP request headers
    @param f Handler function to execute
    @return Result of handler function
*)
val with_http_context :
  headers:(string * string) list ->
  (unit -> 'a) ->
  'a

(** Execute HTTP handler with full context setup.

    Similar to with_http_context but allows specifying additional attributes
    and a custom span name.

    @param headers HTTP request headers
    @param span_name Name for the HTTP request span
    @param attributes Additional attributes to add to context
    @param f Handler function to execute
    @return Result of handler function
*)
val with_http_request :
  headers:(string * string) list ->
  span_name:string ->
  attributes:(string * Value.t) list ->
  (unit -> 'a) ->
  'a

(** {1 Fiber-Local Context Helpers} *)

(** Execute function with fiber-local context.

    Convenience wrapper around Flo_context.with_context that allows
    setting trace_id, span_id, and attributes in one call.

    @param trace_id Optional trace ID
    @param span_id Optional span ID
    @param attributes Optional key-value attributes
    @param f Function to execute
    @return Result of function
*)
val with_context :
  ?trace_id:string ->
  ?span_id:string ->
  ?attributes:(string * Value.t) list ->
  (unit -> 'a) ->
  'a

(** Get current fiber's context.

    Wrapper around Flo_context.get_current for convenience.

    @return Some context if set, None otherwise
*)
val get_context : unit -> Flo_context.context option
