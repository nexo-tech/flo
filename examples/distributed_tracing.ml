(* Distributed Tracing Examples
 *
 * This example demonstrates W3C Trace Context for distributed tracing
 * across services, including trace propagation, span relationships, and
 * OpenTelemetry integration.
 *)

open Flo

(* Example 1: W3C Trace Context Parsing and Formatting *)
let example_w3c_trace_context () =
  Eio.traceln "\n=== W3C Trace Context Parsing/Formatting ===\n";

  (* Format 1: Create a new trace context *)
  let trace_id = Trace_context.generate_trace_id () in
  let span_id = Trace_context.generate_span_id () in

  Eio.traceln "Generated IDs:";
  Eio.traceln "  trace_id: %s (32 hex chars)" trace_id;
  Eio.traceln "  span_id: %s (16 hex chars)" span_id;

  let span_ctx = {
    Trace_context.trace_id;
    Trace_context.span_id;
    Trace_context.parent_span_id = None;
    Trace_context.trace_flags = 1;  (* Sampled *)
  } in

  (* Format as traceparent header *)
  let traceparent = Trace_context.format_traceparent span_ctx in
  Eio.traceln "\nW3C traceparent header:";
  Eio.traceln "  %s" traceparent;
  Eio.traceln "  Format: version-trace_id-span_id-flags";

  (* Parse it back *)
  match Trace_context.parse_traceparent traceparent with
  | Ok parsed ->
      Eio.traceln "\nParsed back:";
      Eio.traceln "  trace_id: %s ✓" parsed.trace_id;
      Eio.traceln "  span_id: %s ✓" parsed.span_id;
      Eio.traceln "  sampled: %b ✓" (parsed.trace_flags land 1 = 1)
  | Error err ->
      Eio.traceln "Parse error: %s" err

(* Example 2: Span Relationships (Parent/Child) *)
let example_span_relationships () =
  Eio.traceln "\n=== Span Relationships (Parent/Child) ===\n";

  (* Start parent span *)
  let parent = Flo_structured.start_span "parent_operation" () in
  Eio.traceln "Parent span:";
  Eio.traceln "  trace_id: %s" (Flo_structured.span_trace_id parent);
  Eio.traceln "  span_id: %s" (Flo_structured.span_id parent);

  (* Create child span *)
  let child1 = Flo_structured.start_span "child_operation_1" ~parent () in
  Eio.traceln "\nChild span 1:";
  Eio.traceln "  trace_id: %s (same as parent ✓)" (Flo_structured.span_trace_id child1);
  Eio.traceln "  span_id: %s (new)" (Flo_structured.span_id child1);

  (* Create another child *)
  let child2 = Flo_structured.start_span "child_operation_2" ~parent () in
  Eio.traceln "\nChild span 2:";
  Eio.traceln "  trace_id: %s (same as parent ✓)" (Flo_structured.span_trace_id child2);
  Eio.traceln "  span_id: %s (new, different from child1)" (Flo_structured.span_id child2);

  (* Create grandchild *)
  let grandchild = Flo_structured.start_span "grandchild_operation" ~parent:child1 () in
  Eio.traceln "\nGrandchild span:";
  Eio.traceln "  trace_id: %s (same as all ✓)" (Flo_structured.span_trace_id grandchild);
  Eio.traceln "  span_id: %s (new)" (Flo_structured.span_id grandchild);

  Eio.traceln "\nSpan tree: parent → [child1 → grandchild, child2]"

(* Example 3: End-to-End Trace Across Services *)
let example_end_to_end_trace () =
  Eio.traceln "\n=== End-to-End Trace Across Services ===\n";

  (* Service 1: Frontend (initial request) *)
  Flo.with_trace_id (Trace_context.generate_trace_id ()) (fun () ->
    let trace_id = Option.get (Flo.get_trace_id ()) in
    Eio.traceln "Service 1 (Frontend): trace_id=%s" trace_id;

    Flo.with_span "frontend_request" (fun () ->
      Flo.info "Frontend: User request received";
      let span_id = Option.get (Flo.get_span_id ()) in

      (* Create traceparent for backend *)
      let ctx1 = {
        Trace_context.trace_id;
        span_id;
        parent_span_id = None;
        trace_flags = 1;
      } in
      let traceparent1 = Trace_context.format_traceparent ctx1 in

      (* Service 2: Backend API *)
      Eio.traceln "\n→ Calling Service 2 (Backend API)";
      Eio.traceln "  Header: traceparent=%s" traceparent1;

      (match Trace_context.parse_traceparent traceparent1 with
       | Ok parent_ctx ->
           let child_ctx = Trace_context.create_child parent_ctx in
           Eio.traceln "\nService 2 (Backend): trace_id=%s" child_ctx.trace_id;

           Flo_eio.with_http_context ~headers:[("traceparent", traceparent1)] (fun () ->
             Flo.info "Backend: Processing API request";

             let traceparent2 = Trace_context.format_traceparent child_ctx in

             (* Service 3: Database Service *)
             Eio.traceln "\n→ Calling Service 3 (Database)";
             Eio.traceln "  Header: traceparent=%s" traceparent2;

             (match Trace_context.parse_traceparent traceparent2 with
              | Ok parent_ctx2 ->
                  let grandchild_ctx = Trace_context.create_child parent_ctx2 in
                  Eio.traceln "\nService 3 (Database): trace_id=%s" grandchild_ctx.trace_id;

                  Flo_eio.with_http_context ~headers:[("traceparent", traceparent2)] (fun () ->
                    Flo.info "Database: Executing query";
                  )
              | Error err ->
                  Eio.traceln "Parse error: %s" err)
           )
       | Error err ->
           Eio.traceln "Parse error: %s" err);

      Flo.info "Frontend: Request completed";
    );

    Eio.traceln "\n✓ Same trace_id across all 3 services!"
  )

(* Example 4: Trace Sampling Strategies *)
let example_trace_sampling () =
  Eio.traceln "\n=== Trace Sampling Strategies ===\n";

  (* Strategy 1: Always sample *)
  Eio.traceln "Strategy 1: Always sample (trace_flags = 1)";
  let always_sampled = {
    Trace_context.trace_id = Trace_context.generate_trace_id ();
    span_id = Trace_context.generate_span_id ();
    parent_span_id = None;
    trace_flags = 1;  (* Sampled *)
  } in
  Eio.traceln "  traceparent: %s" (Trace_context.format_traceparent always_sampled);

  (* Strategy 2: Never sample *)
  Eio.traceln "\nStrategy 2: Never sample (trace_flags = 0)";
  let never_sampled = {
    Trace_context.trace_id = Trace_context.generate_trace_id ();
    span_id = Trace_context.generate_span_id ();
    parent_span_id = None;
    trace_flags = 0;  (* Not sampled *)
  } in
  Eio.traceln "  traceparent: %s" (Trace_context.format_traceparent never_sampled);

  (* Strategy 3: Probabilistic sampling (10% sample rate) *)
  Eio.traceln "\nStrategy 3: Probabilistic sampling (10%% rate)";
  let sample_rate = 0.1 in
  for i = 1 to 5 do
    let sampled = Random.float 1.0 < sample_rate in
    let ctx = {
      Trace_context.trace_id = Trace_context.generate_trace_id ();
      span_id = Trace_context.generate_span_id ();
      parent_span_id = None;
      trace_flags = if sampled then 1 else 0;
    } in
    Eio.traceln "  Request %d: sampled=%b flags=%d" i sampled ctx.trace_flags
  done;

  Eio.traceln "\nSampling reduces tracing overhead for high-volume systems"

(* Example 5: Trace Visualization Structure *)
let example_trace_visualization () =
  Eio.traceln "\n=== Trace Visualization Structure ===\n";

  (* Create a trace with multiple spans for visualization *)
  Flo.with_trace_id (Trace_context.generate_trace_id ()) (fun () ->
    let trace_id = Option.get (Flo.get_trace_id ()) in

    Flo.with_span "http_request" (fun () ->
      let _span1_id = Option.get (Flo.get_span_id ()) in
      Flo.info "HTTP request started";

      Flo.with_span "auth_check" (fun () ->
        let _span2_id = Option.get (Flo.get_span_id ()) in
        Flo.info "Authentication check";
        Eio.traceln "  Span: auth_check (parent: http_request)";
      );

      Flo.with_span "database_query" (fun () ->
        let _span3_id = Option.get (Flo.get_span_id ()) in
        Flo.info "Database query";
        Eio.traceln "  Span: database_query (parent: http_request)";

        Flo.with_span "cache_lookup" (fun () ->
          Flo.info "Cache lookup";
          Eio.traceln "    Span: cache_lookup (parent: database_query)";
        );
      );

      Flo.with_span "response_formatting" (fun () ->
        Flo.info "Format response";
        Eio.traceln "  Span: response_formatting (parent: http_request)";
      );

      Flo.info "HTTP request completed";
    );

    Eio.traceln "\nTrace tree (all share trace_id=%s):" trace_id;
    Eio.traceln "http_request";
    Eio.traceln "├── auth_check";
    Eio.traceln "├── database_query";
    Eio.traceln "│   └── cache_lookup";
    Eio.traceln "└── response_formatting";
    Eio.traceln "\nVisualize in: Jaeger, Zipkin, or Grafana Tempo"
  )

(* Example 6: OpenTelemetry Integration Pattern *)
let example_otel_integration () =
  Eio.traceln "\n=== OpenTelemetry Integration Pattern ===\n";

  (* Create OTel-compliant log entries *)
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = Some "00f067aa0ba902b7";
    trace_flags = 1;
  } in

  let record = Record.make ~severity:Severity.Info ~message:"Order processing" in
  let record = Record.with_span_context span_ctx record in
  let record = Record.with_attributes [
    ("service.name", Value.String "order-service");
    ("service.version", Value.String "2.1.0");
    ("deployment.environment", Value.String "production");
    ("http.method", Value.String "POST");
    ("http.target", Value.String "/api/orders");
  ] record in

  Eio.traceln "OpenTelemetry-compliant log:";
  Eio.traceln "%s" (Flo_format_json.format record);

  Eio.traceln "\nExport to OTel collector:";
  Eio.traceln "  - OTLP/gRPC: localhost:4317";
  Eio.traceln "  - OTLP/HTTP: localhost:4318";
  Eio.traceln "  - Include trace_id, span_id in every log"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Distributed Tracing Examples                      ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_w3c_trace_context ();
  example_span_relationships ();
  example_end_to_end_trace ();
  example_trace_sampling ();
  example_trace_visualization ();
  example_otel_integration ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
