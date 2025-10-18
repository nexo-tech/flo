(** Eio integration for distributed tracing *)

(** {1 HTTP Context Extraction} *)

(** Extract W3C Trace Context from HTTP headers *)
let extract_trace_context headers =
  (* Look for traceparent header (case-insensitive) *)
  let traceparent = List.find_opt (fun (name, _) ->
    String.lowercase_ascii name = "traceparent"
  ) headers in

  match traceparent with
  | Some (_, value) ->
      (* Parse the traceparent value *)
      Trace_context.parse_traceparent value |> Result.to_option
  | None -> None

(** Inject W3C Trace Context into HTTP headers *)
let inject_trace_context span_context =
  let traceparent = Trace_context.format_traceparent span_context in
  [("traceparent", traceparent)]

(** {1 HTTP Context Management} *)

(** Execute HTTP handler with extracted trace context *)
let with_http_context ~headers f =
  match extract_trace_context headers with
  | Some span_ctx ->
      (* Create context with trace information *)
      let ctx = Flo_context.empty in
      let ctx = Flo_context.add "trace_id" (Value.String span_ctx.trace_id) ctx in
      let ctx = Flo_context.add "span_id" (Value.String span_ctx.span_id) ctx in
      (match span_ctx.parent_span_id with
       | Some parent_id ->
           let ctx = Flo_context.add "parent_span_id" (Value.String parent_id) ctx in
           Flo_context.with_context ctx f
       | None ->
           Flo_context.with_context ctx f)
  | None ->
      (* No trace context in headers, just execute *)
      f ()

(** Execute HTTP handler with full context setup *)
let with_http_request ~headers ~span_name ~attributes f =
  (* Extract trace context *)
  let parent_ctx = extract_trace_context headers in

  (* Start a span for the HTTP request *)
  let span = match parent_ctx with
    | Some parent ->
        (* Create child span from extracted parent *)
        Flo_structured.start_span span_name
          ~attributes
          ~parent:(Flo_structured.start_span "parent"
            ~attributes:[
              ("trace_id", Value.String parent.trace_id);
              ("span_id", Value.String parent.span_id);
            ]
            ())
          ()
    | None ->
        (* No parent, create new span *)
        Flo_structured.start_span span_name ~attributes ()
  in

  (* Execute within span context *)
  let result =
    try
      let res = Flo_structured.in_span span_name (fun _ -> f ()) in
      Flo_structured.end_span span;
      res
    with exn ->
      Flo_structured.end_span span;
      raise exn
  in
  result

(** {1 Fiber-Local Context Helpers} *)

(** Execute function with fiber-local context *)
let with_context ?trace_id ?span_id ?attributes f =
  let ctx = Flo_context.empty in

  (* Add trace_id if provided *)
  let ctx = match trace_id with
    | Some tid -> Flo_context.add "trace_id" (Value.String tid) ctx
    | None -> ctx
  in

  (* Add span_id if provided *)
  let ctx = match span_id with
    | Some sid -> Flo_context.add "span_id" (Value.String sid) ctx
    | None -> ctx
  in

  (* Add attributes if provided *)
  let ctx = match attributes with
    | Some attrs -> List.fold_left (fun c (k, v) ->
        Flo_context.add k v c
      ) ctx attrs
    | None -> ctx
  in

  Flo_context.with_context ctx f

(** Get current fiber's context *)
let get_context () =
  Flo_context.get_current ()
