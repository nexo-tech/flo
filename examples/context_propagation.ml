(* Advanced Context Propagation Examples
 *
 * This example demonstrates Flo's fiber-local context propagation using Eio,
 * including trace IDs, span contexts, and custom attributes.
 *)

open Flo

(* Example 1: Multi-Fiber Context Isolation *)
let example_fiber_isolation ~env =
  Eio.traceln "\n=== Multi-Fiber Context Isolation ===\n";

  Eio.Switch.run @@ fun _sw ->
    (* Spawn multiple fibers with isolated contexts *)
    Eio.Fiber.all [
      (fun () ->
        (* Fiber 1: User Alice *)
        Flo.with_user "alice" (fun () ->
          Flo.info "Fiber 1: Processing for Alice";
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
          Flo.info "Fiber 1: Alice processing complete";
        )
      );
      (fun () ->
        (* Fiber 2: User Bob *)
        Flo.with_user "bob" (fun () ->
          Flo.info "Fiber 2: Processing for Bob";
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
          Flo.info "Fiber 2: Bob processing complete";
        )
      );
      (fun () ->
        (* Fiber 3: User Charlie *)
        Flo.with_user "charlie" (fun () ->
          Flo.info "Fiber 3: Processing for Charlie";
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
          Flo.info "Fiber 3: Charlie processing complete";
        )
      );
    ];

  Eio.traceln "\nNote: Each fiber maintains its own context (user_id)";
  Eio.traceln "Context is isolated - Alice's logs only show user_id=alice"

(* Example 2: Parent-Child Context Inheritance *)
let example_context_inheritance () =
  Eio.traceln "\n=== Parent-Child Context Inheritance ===\n";

  (* Parent context *)
  Flo.with_trace_id "trace-abc-123" (fun () ->
    Flo.info "Parent: Starting request";

    (* Child context inherits parent's trace_id *)
    Flo.bind [("request_id", Value.String "req-001")];
    Flo.info "Parent: Added request_id";

    (* Nested child context *)
    Flo.with_span "database_query" (fun () ->
      Flo.info "Child: Inside database query span";
      Flo.bind [("table", Value.String "users"); ("query", Value.String "SELECT")];
      Flo.info "Child: Query executed";

      (* Grandchild context *)
      Flo.with_span "cache_check" (fun () ->
        Flo.info "Grandchild: Cache check";
        Flo.bind [("cache_key", Value.String "user:123")];
        Flo.info "Grandchild: Cache hit";
      );
    );

    Flo.info "Parent: Request completed";
  );

  Eio.traceln "\nNote: trace_id propagates through all nested contexts"

(* Example 3: Context Merging Strategies *)
let example_context_merging () =
  Eio.traceln "\n=== Context Merging Strategies ===\n";

  (* Strategy 1: Add to existing context *)
  Flo.with_user "alice" (fun () ->
    Flo.info "Initial context: user=alice";

    (* Add more fields to context *)
    Flo.bind [
      ("session_id", Value.String "sess-123");
      ("ip_address", Value.String "192.168.1.1");
    ];
    Flo.info "Merged context: user + session + ip";

    (* Add even more *)
    Flo.bind [("request_id", Value.String "req-456")];
    Flo.info "Further merged: + request_id";
  );

  Eio.traceln "\nStrategy: Accumulative merging (all fields preserved)"

(* Example 4: Custom Context Keys with Type Safety (GADT) *)
let example_custom_keys () =
  Eio.traceln "\n=== Custom Context Keys (Type-Safe) ===\n";

  (* Use predefined typed keys *)
  let user_key = Flo_structured.user_id_key in
  let request_key = Flo_structured.request_id_key in
  let trace_key = Flo_structured.trace_id_key in

  (* Use typed keys with type safety *)
  Flo_structured.with_binding user_key "alice" (fun () ->
    Flo.info "User context set";

    Flo_structured.add request_key "req-123";
    Flo_structured.add trace_key "trace-abc-456";

    Flo.info "Request context captured";

    (* Retrieve typed values *)
    match Flo_structured.get user_key with
    | Some user_id ->
        Eio.traceln "Retrieved user_id: %s (type-safe!)" user_id;

        (* All context fields appear in logs *)
        Flo.info "Processing user request"
    | None ->
        Eio.traceln "User ID not found"
  );

  Eio.traceln "\nType safety: Keys guarantee string type at compile time";
  Eio.traceln "Available keys: user_id, request_id, trace_id, session_id"

(* Example 5: HTTP Header Context Extraction/Injection *)
let example_http_context () =
  Eio.traceln "\n=== HTTP Header Context Extraction/Injection ===\n";

  (* Simulate incoming HTTP request with W3C Trace Context headers *)
  let incoming_headers = [
    ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    ("content-type", "application/json");
    ("user-agent", "curl/7.68.0");
  ] in

  Eio.traceln "Incoming request headers:";
  List.iter (fun (k, v) -> Eio.traceln "  %s: %s" k v) incoming_headers;

  (* Extract trace context *)
  match Flo_eio.extract_trace_context incoming_headers with
  | Some span_ctx ->
      Eio.traceln "\nExtracted trace context:";
      Eio.traceln "  trace_id: %s" span_ctx.Trace_context.trace_id;
      Eio.traceln "  span_id: %s" span_ctx.Trace_context.span_id;
      Eio.traceln "  sampled: %b" (span_ctx.Trace_context.trace_flags land 1 = 1);

      (* Use extracted context for logging *)
      Flo_eio.with_http_context ~headers:incoming_headers (fun () ->
        Flo.info "Processing request with extracted trace context";
        Flo.bind [("endpoint", Value.String "/api/orders")];
        Flo.info "Request processed";

        (* Inject context into outgoing request *)
        let outgoing_headers = Flo_eio.inject_trace_context span_ctx in
        Eio.traceln "\nOutgoing request headers:";
        List.iter (fun (k, v) -> Eio.traceln "  %s: %s" k v) outgoing_headers
      )
  | None ->
      Eio.traceln "\nNo trace context found in headers"

(* Example 6: Distributed Trace Across Services *)
let example_distributed_trace () =
  Eio.traceln "\n=== Distributed Trace Across Services ===\n";

  (* Service 1: API Gateway *)
  Flo.with_trace_id (Trace_context.generate_trace_id ()) (fun () ->
    let trace_id = Option.get (Flo.get_trace_id ()) in
    Eio.traceln "Service 1 (API Gateway): trace_id=%s" trace_id;

    Flo.with_span "api_request" (fun () ->
      Flo.info "API Gateway: Request received";
      let span_id = Option.get (Flo.get_span_id ()) in

      (* Create traceparent for downstream service *)
      let span_ctx = {
        Trace_context.trace_id;
        Trace_context.span_id;
        Trace_context.parent_span_id = None;
        Trace_context.trace_flags = 1;
      } in
      let traceparent = Trace_context.format_traceparent span_ctx in
      Eio.traceln "  Sending to Service 2: traceparent=%s" traceparent;

      (* Simulate Service 2: Order Service *)
      (match Trace_context.parse_traceparent traceparent with
       | Ok parent_ctx ->
           let child_ctx = Trace_context.create_child parent_ctx in
           Eio.traceln "\nService 2 (Order Service): trace_id=%s" child_ctx.trace_id;
           Eio.traceln "  parent_span_id=%s" child_ctx.span_id;

           (* Service 2 uses the child context *)
           Flo_eio.with_http_context ~headers:[("traceparent", traceparent)] (fun () ->
             Flo.info "Order Service: Processing order";
             Flo.bind [("service", Value.String "order-service")];
             Flo.info "Order Service: Order created";
           )
       | Error err ->
           Eio.traceln "Failed to parse traceparent: %s" err)
    );
  );

  Eio.traceln "\nResult: Single trace_id across multiple services"

(* Example 7: Concurrent Request Processing with Isolation *)
let example_concurrent_requests ~env =
  Eio.traceln "\n=== Concurrent Request Processing ===\n";

  Eio.Switch.run @@ fun _sw ->
    (* Simulate 3 concurrent HTTP requests, each with isolated context *)
    let requests = [
      ("req-1", "alice", "GET", "/api/users");
      ("req-2", "bob", "POST", "/api/orders");
      ("req-3", "charlie", "GET", "/api/products");
    ] in

    Eio.Fiber.all (List.map (fun (req_id, user, method_, path) ->
      fun () ->
        (* Each request gets its own trace_id and context *)
        Flo.with_trace_id (Trace_context.generate_trace_id ()) (fun () ->
          Flo.bind [
            ("request_id", Value.String req_id);
            ("user_id", Value.String user);
            ("method", Value.String method_);
            ("path", Value.String path);
          ];

          Flo.info "Request started";
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
          Flo.info "Request completed";
        )
    ) requests);

  Eio.traceln "\nEach request has isolated context with unique trace_id"

(* Example 8: Context Propagation in Library Code *)
let example_library_context () =
  Eio.traceln "\n=== Context Propagation for Libraries ===\n";

  (* Library function that logs with inherited context *)
  let library_function operation_name data =
    (* Library doesn't set context, it inherits from caller *)
    Flo.info (Printf.sprintf "Library: %s started" operation_name);
    Flo.bind [("library.operation", Value.String operation_name)];

    (* Simulate work *)
    let result = String.length data in

    Flo.info (Printf.sprintf "Library: %s completed" operation_name);
    result
  in

  (* Application sets context *)
  Flo.with_user "alice" (fun () ->
    Flo.bind [("app.version", Value.String "2.0.0")];
    Flo.info "Application: Starting operation";

    (* Library function inherits app context *)
    let result = library_function "process_data" "hello world" in

    Flo.info (Printf.sprintf "Application: Got result %d" result);
  );

  Eio.traceln "\nLibrary logs include app context (user_id, app.version)"

(* Main *)
let main env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Context Propagation Examples                      ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_fiber_isolation ~env;
  example_context_inheritance ();
  example_context_merging ();
  example_custom_keys ();
  example_http_context ();
  example_distributed_trace ();
  example_concurrent_requests ~env;
  example_library_context ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
