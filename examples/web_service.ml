(* Web Service Example - Distributed Tracing

   This example demonstrates distributed tracing in a web service context:
   - W3C Trace Context extraction from HTTP headers
   - Automatic trace propagation across services
   - Span creation for HTTP requests
   - Context injection for downstream calls
   - Full request correlation
*)

open Flo

(* Simulated HTTP request type *)
type http_request = {
  method_ : string;
  path : string;
  headers : (string * string) list;
  _body : string;
}

type http_response = {
  status : int;
  _headers : (string * string) list;
  _body : string;
}

(* Example 1: Basic HTTP context extraction *)
let example_basic_extraction () =
  Eio.traceln "\n=== Basic HTTP Context Extraction ===";

  (* Simulate incoming request with W3C Trace Context *)
  let headers = [
    ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    ("content-type", "application/json");
  ] in

  match Flo_eio.extract_trace_context headers with
  | Some ctx ->
      Eio.traceln "Extracted trace context:";
      Eio.traceln "  trace_id: %s" ctx.trace_id;
      Eio.traceln "  span_id: %s" ctx.span_id;
      Eio.traceln "  trace_flags: %d" ctx.trace_flags
  | None ->
      Eio.traceln "No trace context found"

(* Example 2: Trace context injection *)
let example_trace_injection () =
  Eio.traceln "\n=== Trace Context Injection ===";

  (* Create a span context *)
  let trace_id = Trace_context.generate_trace_id () in
  let span_id = Trace_context.generate_span_id () in

  let span_ctx = {
    Trace_context.trace_id;
    Trace_context.span_id;
    Trace_context.parent_span_id = None;
    Trace_context.trace_flags = 1;
  } in

  (* Inject into headers for downstream call *)
  let headers = Flo_eio.inject_trace_context span_ctx in

  Eio.traceln "Injected headers for downstream service:";
  List.iter (fun (name, value) ->
    Eio.traceln "  %s: %s" name value
  ) headers

(* Example 3: HTTP request handling with context *)
let handle_order_request (request : http_request) : http_response =
  Flo_eio.with_http_context ~headers:request.headers (fun () ->
    Flo.info_fields "Incoming HTTP request" ~fields:[
      Flo_semconv.http_method request.method_;
      Flo_semconv.http_target request.path;
    ];

    (* Simulate order processing *)
    let order_id = "order_" ^ string_of_int (Random.int 100000) in

    Flo_structured.in_span "process_order" (fun _ ->
      Flo_structured.add Flo_structured.user_id_key "alice";

      Flo.info_fields "Processing order" ~fields:[
        ("order_id", Value.String order_id);
      ];

      (* Simulate database query *)
      Flo_structured.in_span "db_query" (fun _ ->
        Flo.debug "Fetching user data";
        Unix.sleepf 0.01
      );

      (* Simulate payment processing *)
      Flo_structured.in_span "process_payment" (fun _ ->
        Flo.info "Processing payment";
        Unix.sleepf 0.02
      );

      Flo.info_fields "Order completed" ~fields:[
        ("order_id", Value.String order_id);
        ("status", Value.String "success");
      ];
      Flo.success "Order completed"
    );

    {
      status = 201;
      _headers = [];
      _body = Printf.sprintf "{\"order_id\": \"%s\"}" order_id;
    }
  )

let example_http_request_handling () =
  Eio.traceln "\n=== HTTP Request Handling ===";

  (* Request without trace context *)
  Eio.traceln "\n1. Request without trace context:";
  let request1 = {
    method_ = "POST";
    path = "/api/orders";
    headers = [("content-type", "application/json")];
    _body = "{\"items\": [1, 2, 3]}";
  } in
  let response1 = handle_order_request request1 in
  Eio.traceln "Response status: %d" response1.status;

  (* Request with trace context (distributed trace) *)
  Eio.traceln "\n2. Request with trace context (from upstream service):";
  let request2 = {
    method_ = "POST";
    path = "/api/orders";
    headers = [
      ("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01");
      ("content-type", "application/json");
    ];
    _body = "{\"items\": [4, 5, 6]}";
  } in
  let response2 = handle_order_request request2 in
  Eio.traceln "Response status: %d" response2.status

(* Example 4: Multi-service trace propagation *)
let call_downstream_service trace_ctx service_name _request_data =
  (* Inject trace context into outgoing headers *)
  let _headers = Flo_eio.inject_trace_context trace_ctx in
  let _headers = ("content-type", "application/json") :: _headers in

  Flo.info_fields "Calling downstream service" ~fields:[
    ("service", Value.String service_name);
    Flo_semconv.http_method "POST";
  ];

  (* Simulate HTTP call *)
  Unix.sleepf 0.05;

  Flo.info_fields "Downstream call succeeded" ~fields:[
    ("service", Value.String service_name);
    Flo_semconv.http_status_code 200;
    Flo_semconv.duration_ms 50.0;
  ];
  Flo.success "Downstream call succeeded";

  {
    status = 200;
    _headers = [];
    _body = "{\"result\": \"ok\"}";
  }

let handle_orchestration_request (request : http_request) : http_response =
  Flo_eio.with_http_request
    ~headers:request.headers
    ~span_name:"orchestrate_order"
    ~attributes:[
      Flo_semconv.http_method request.method_;
      Flo_semconv.http_target request.path;
    ]
    (fun () ->
      Flo.info "Orchestrating multi-service order";

      (* Get current span context for propagation *)
      let trace_id = Flo.get_trace_id () in
      let span_id = Flo.get_span_id () in

      let span_ctx = {
        Trace_context.trace_id = Option.value trace_id ~default:"unknown";
        Trace_context.span_id = Option.value span_id ~default:"unknown";
        Trace_context.parent_span_id = None;
        Trace_context.trace_flags = 1;
      } in

      (* Call multiple downstream services with trace propagation *)
      Flo_structured.in_span "call_inventory_service" (fun _ ->
        let _resp = call_downstream_service span_ctx "inventory-service" "{}" in
        ()
      );

      Flo_structured.in_span "call_payment_service" (fun _ ->
        let _resp = call_downstream_service span_ctx "payment-service" "{}" in
        ()
      );

      Flo_structured.in_span "call_shipping_service" (fun _ ->
        let _resp = call_downstream_service span_ctx "shipping-service" "{}" in
        ()
      );

      Flo.success "Orchestration complete";

      {
        status = 200;
        _headers = [];
        _body = "{\"status\": \"orchestrated\"}";
      }
    )

let example_multi_service_tracing () =
  Eio.traceln "\n=== Multi-Service Distributed Tracing ===";

  (* Incoming request with trace context *)
  let request = {
    method_ = "POST";
    path = "/api/orchestrate";
    headers = [
      ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
      ("content-type", "application/json");
    ];
    _body = "{\"operation\": \"create_order\"}";
  } in

  let response = handle_orchestration_request request in
  Eio.traceln "Orchestration response status: %d" response.status;
  Eio.traceln "(Check logs to see trace_id propagation across all spans)"

(* Example 5: Context propagation with fiber-local storage *)
let simulate_concurrent_requests () =
  Eio.traceln "\n=== Concurrent Requests with Isolated Contexts ===";

  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      (* Spawn multiple concurrent request handlers *)
      let requests = [
        ("trace-1", "user-alice", "/api/users/1");
        ("trace-2", "user-bob", "/api/users/2");
        ("trace-3", "user-charlie", "/api/users/3");
      ] in

      List.iter (fun (trace_id, user_id, path) ->
        Eio.Fiber.fork ~sw (fun () ->
          (* Each fiber has its own isolated context *)
          Flo_eio.with_context
            ~trace_id
            ~attributes:[
              Flo_semconv.user_id user_id;
              ("path", Value.String path);
            ]
            (fun () ->
              Flo.info_fields "Processing request" ~fields:[
                ("trace_id", Value.String trace_id);
                ("user", Value.String user_id);
              ];

              Unix.sleepf (Random.float 0.05);

              Flo.success "Request completed"
            )
        )
      ) requests

let example_fiber_context_isolation () =
  Eio.traceln "\n=== Fiber Context Isolation ===";
  simulate_concurrent_requests ();
  Eio.traceln "All concurrent requests completed with isolated contexts"

(* Main *)
let main () =
  Eio.traceln "=== Flo Distributed Tracing Examples ===";

  example_basic_extraction ();
  example_trace_injection ();
  example_http_request_handling ();
  example_multi_service_tracing ();
  example_fiber_context_isolation ();

  Eio.traceln "\n=== All examples completed ===";
  Eio.traceln "Distributed tracing demonstrated across services"

let () =
  Random.self_init ();
  Printexc.record_backtrace true;
  main ()
