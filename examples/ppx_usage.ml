(* PPX Usage Examples
 *
 * This example demonstrates all PPX extensions provided by ppx_flo:
 * 1. Automatic location capture with [%log.level]
 * 2. Structured logging with labeled arguments
 * 3. Span annotations with [%span]
 *)

open Flo

(* ============================================================================
   Feature 1: Automatic Location Capture
   ============================================================================ *)

let example_location_capture () =
  Eio.traceln "\n=== Automatic Location Capture ===\n";

  (* Without PPX - no location information *)
  Flo.info "This log has no location info";

  (* With PPX - automatic location capture *)
  [%log.info "This log automatically captures file, line, column, module"];

  (* All severity levels support location capture *)
  [%log.trace "Trace level with location"];
  [%log.debug "Debug level with location"];
  [%log.info "Info level with location"];
  [%log.success "Success level with location"];
  [%log.warn "Warning level with location"];
  [%log.error "Error level with location"];
  [%log.fatal "Fatal level with location"];

  Eio.traceln "Location info includes: file path, line number, column, module name"

(* ============================================================================
   Feature 2: Structured Logging with Type Inference
   ============================================================================ *)

let example_structured_logging () =
  Eio.traceln "\n=== Structured Logging ===\n";

  (* Basic structured logging with automatic type inference *)
  [%log.info "User logged in"
    ~user_id:"alice"
    ~session_id:"abc123"
    ~ip_address:"192.168.1.1"];

  (* Mixed types - the PPX infers the correct Value.t constructor *)
  [%log.info "Order created"
    ~order_id:"ORD-12345"      (* String *)
    ~user_id:"alice"            (* String *)
    ~total:99.99                (* Float *)
    ~item_count:3               (* Int *)
    ~is_paid:true               (* Bool *)
    ~discount:10.0];            (* Float *)

  (* Integer fields *)
  [%log.info "Processing batch"
    ~batch_id:42
    ~size:1000
    ~processed:750
    ~remaining:250];

  (* Float fields for metrics *)
  [%log.info "Performance metrics"
    ~cpu_usage:85.5
    ~memory_mb:512.0
    ~duration_ms:123.45
    ~throughput:1000.0];

  (* Boolean flags *)
  [%log.info "Feature flags"
    ~dark_mode:true
    ~beta_features:false
    ~analytics_enabled:true];

  (* Empty lists and list literals *)
  [%log.info "List examples"
    ~tags:[]
    ~numbers:[1; 2; 3; 4; 5]];

  Eio.traceln "Structured fields are automatically converted to Value.t types"

(* ============================================================================
   Feature 3: Combining Location + Structured Logging
   ============================================================================ *)

let example_combined () =
  Eio.traceln "\n=== Combined: Location + Structured Logging ===\n";

  (* Both location capture AND structured fields work together *)
  [%log.info "HTTP request received"
    ~method_:"POST"
    ~path:"/api/orders"
    ~status:201
    ~duration_ms:42.5
    ~user_agent:"curl/7.68.0"];

  (* Complex real-world example *)
  [%log.warn "Rate limit approaching"
    ~user_id:"bob"
    ~endpoint:"/api/data"
    ~current_requests:95
    ~limit:100
    ~window_seconds:60
    ~should_throttle:true];

  Eio.traceln "Every structured log automatically includes location information"

(* ============================================================================
   Feature 4: Span Annotations for Distributed Tracing
   ============================================================================ *)

let example_span_basic () =
  Eio.traceln "\n=== Basic Span Annotation ===\n";

  (* Wrap any expression in a span *)
  let result = [%span
    begin
      [%log.info "Computing result"];
      21 + 21
    end
  ] in

  Eio.traceln "Result: %d (computed in span)" result;

  (* Spans work with function calls *)
  let compute x y = x * y in
  let result2 = [%span compute 6 7] in

  Eio.traceln "Result: %d (function call in span)" result2

let example_nested_spans () =
  Eio.traceln "\n=== Nested Spans ===\n";

  let outer_result = [%span
    begin
      [%log.info "Outer span started"];

      (* Inner span 1 *)
      let value1 = [%span
        begin
          [%log.info "Inner span 1"];
          10
        end
      ] in

      (* Inner span 2 *)
      let value2 = [%span
        begin
          [%log.info "Inner span 2"];
          32
        end
      ] in

      [%log.info "Combining results"];
      value1 + value2
    end
  ] in

  Eio.traceln "Outer result: %d (from nested spans)" outer_result

let example_span_with_structured_logging () =
  Eio.traceln "\n=== Span + Structured Logging ===\n";

  let process_order () = [%span
    begin
      [%log.info "Processing order"
        ~order_id:"ORD-123"
        ~user_id:"alice"
        ~total:99.99];

      (* Simulate some processing *)
      let _items = [%span
        begin
          [%log.debug "Fetching items" ~order_id:"ORD-123"];
          ["item1"; "item2"; "item3"]
        end
      ] in

      let _shipping = [%span
        begin
          [%log.debug "Calculating shipping" ~item_count:3];
          5.99
        end
      ] in

      [%log.success "Order processed"
        ~order_id:"ORD-123"
        ~item_count:3
        ~shipping_cost:5.99
        ~final_total:105.98];

      105.98
    end
  ] in

  let final_total = process_order () in
  Eio.traceln "Final total: $%.2f" final_total

(* ============================================================================
   Feature 5: Exception Handling with Spans
   ============================================================================ *)

let example_span_exception_handling () =
  Eio.traceln "\n=== Span Exception Handling ===\n";

  (* Spans automatically end even when exceptions occur *)
  let result = try
    [%span
      begin
        [%log.info "About to fail"];
        failwith "Intentional error for demo"
      end
    ]
  with Failure _msg ->
    [%log.error "Caught exception" ~error:"Intentional error for demo"];
    "error"
  in

  Eio.traceln "Result after exception: %s" result;
  Eio.traceln "The span was properly ended despite the exception"

(* ============================================================================
   Feature 6: Mixing PPX with Manual API
   ============================================================================ *)

let example_mixed_usage () =
  Eio.traceln "\n=== Mixing PPX with Manual API ===\n";

  (* Manual API - full control *)
  Flo.info_fields "Manual structured log" ~fields:[
    ("manual", Value.String "true");
    ("method", Value.String "API");
  ];

  (* PPX - convenience *)
  [%log.info "PPX structured log" ~manual:false ~method_:"PPX"];

  (* Manual API with explicit location *)
  let loc = Location.make_full
    ~file:"ppx_usage.ml"
    ~line:999
    ~column:10
    ~module_name:"Ppx_usage"
    ()
  in
  Flo.info ~location:loc "Manual log with custom location";

  (* PPX auto-captures location *)
  [%log.info "PPX log with auto location"];

  Eio.traceln "Both manual API and PPX can be used together seamlessly"

(* ============================================================================
   Feature 7: Real-World HTTP Service Example
   ============================================================================ *)

let handle_http_request method_ path user_id =
  [%span
    begin
      (* Note: PPX structured logging works best with literals, not variables *)
      (* For variables, use the manual API *)
      Flo.info_fields "HTTP request received" ~fields:[
        ("method", Value.String method_);
        ("path", Value.String path);
        ("user_id", Value.String user_id);
      ];

      (* Simulate request processing in a span *)
      let response_status = [%span
        begin
          Flo.debug_fields "Authenticating user" ~fields:[
            ("user_id", Value.String user_id);
          ];
          Flo.debug_fields "Processing request" ~fields:[
            ("path", Value.String path);
          ];

          (* Simulate some work *)
          if method_ = "POST" then 201 else 200
        end
      ] in

      Flo.success_fields "HTTP request completed" ~fields:[
        ("method", Value.String method_);
        ("path", Value.String path);
        ("status", Value.Int (Int64.of_int response_status));
        ("user_id", Value.String user_id);
      ];

      response_status
    end
  ]

let example_http_service () =
  Eio.traceln "\n=== HTTP Service Example ===\n";

  let status1 = handle_http_request "GET" "/api/users" "alice" in
  Eio.traceln "Request 1 status: %d" status1;

  let status2 = handle_http_request "POST" "/api/orders" "bob" in
  Eio.traceln "Request 2 status: %d" status2

(* ============================================================================
   Feature 8: Performance - Span Transparency
   ============================================================================ *)

let example_span_transparency () =
  Eio.traceln "\n=== Span Transparency ===\n";

  (* Spans don't change return values or behavior *)
  let without_span = 42 in
  let with_span = [%span 42] in

  Eio.traceln "Without span: %d" without_span;
  Eio.traceln "With span: %d" with_span;
  Eio.traceln "Spans are transparent: %b" (without_span = with_span);

  (* Works with any type *)
  let str_without = "hello" in
  let str_with = [%span "hello"] in
  Eio.traceln "Strings equal: %b" (str_without = str_with);

  (* Works with complex expressions *)
  let list_without = [1; 2; 3] in
  let list_with = [%span [1; 2; 3]] in
  Eio.traceln "Lists equal: %b" (list_without = list_with)

(* ============================================================================
   Main - Run All Examples
   ============================================================================ *)

let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                  Flō PPX Usage Examples                        ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_location_capture ();
  example_structured_logging ();
  example_combined ();
  example_span_basic ();
  example_nested_spans ();
  example_span_with_structured_logging ();
  example_span_exception_handling ();
  example_mixed_usage ();
  example_http_service ();
  example_span_transparency ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
