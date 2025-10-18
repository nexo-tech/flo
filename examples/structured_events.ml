(* Structured Events Example

   This example demonstrates type-safe structured logging using the
   Flo_structured module with GADT-based context keys and first-class
   module types for structured events.
*)

open Flo

(* Define structured event types as first-class modules *)

module User_Registered = struct
  type t = {
    user_id : string;
    email : string;
    source : string;
    timestamp : float;
  }

  let to_value t =
    Value.Object [
      ("user_id", Value.String t.user_id);
      ("email", Value.String t.email);
      ("source", Value.String t.source);
      ("timestamp", Value.Float t.timestamp);
    ]

  let event_name = "user.registered"
  let severity = Severity.Info
end

module Payment_Failed = struct
  type t = {
    payment_id : string;
    user_id : string;
    amount : float;
    currency : string;
    error_code : string;
    error_message : string;
  }

  let to_value t =
    Value.Object [
      ("payment_id", Value.String t.payment_id);
      ("user_id", Value.String t.user_id);
      ("amount", Value.Float t.amount);
      ("currency", Value.String t.currency);
      ("error_code", Value.String t.error_code);
      ("error_message", Value.String t.error_message);
    ]

  let event_name = "payment.failed"
  let severity = Severity.Error
end

module Order_Created = struct
  type t = {
    order_id : string;
    user_id : string;
    items : int;
    total : float;
  }

  let to_value t =
    Value.Object [
      ("order_id", Value.String t.order_id);
      ("user_id", Value.String t.user_id);
      ("items", Value.Int (Int64.of_int t.items));
      ("total", Value.Float t.total);
    ]

  let event_name = "order.created"
  let severity = Severity.Info
end

(* Business logic functions using structured logging *)

let register_user email source =
  let user_id = "user_" ^ string_of_int (Random.int 100000) in

  (* Log structured event with full type safety *)
  Flo_structured.log_event (module User_Registered) {
    user_id;
    email;
    source;
    timestamp = Unix.gettimeofday ();
  };

  user_id

let process_payment payment_id user_id amount =
  (* Simulate payment processing *)
  if Random.bool () then begin
    Flo.success "Payment processed successfully";
    Ok ()
  end else begin
    (* Log structured failure event *)
    Flo_structured.log_event (module Payment_Failed) {
      payment_id;
      user_id;
      amount;
      currency = "USD";
      error_code = "INSUFFICIENT_FUNDS";
      error_message = "Card has insufficient funds";
    };
    Error "Payment failed"
  end

let create_order user_id items total =
  let order_id = "order_" ^ string_of_int (Random.int 100000) in

  (* Log structured event *)
  Flo_structured.log_event (module Order_Created) {
    order_id;
    user_id;
    items;
    total;
  };

  order_id

(* Demonstrate type-safe context keys *)

let demonstrate_typed_keys () =
  Flo.info "=== Type-Safe Context Keys ===";

  (* Add typed values to context *)
  Flo_structured.add Flo_structured.user_id_key "alice";
  Flo_structured.add Flo_structured.session_id_key "session_12345";

  (* Retrieve with compile-time type safety *)
  (match Flo_structured.get Flo_structured.user_id_key with
   | Some user_id -> Flo.infof "Current user: %s" user_id
   | None -> Flo.warn "No user in context");

  (* Scoped binding *)
  Flo_structured.with_binding Flo_structured.request_id_key "req-999" (fun () ->
    Flo.info "Processing request with typed context";

    (* request_id is available here *)
    match Flo_structured.get Flo_structured.request_id_key with
    | Some req_id -> Flo.infof "Request ID: %s" req_id
    | None -> ()
  );

  (* After scope, request_id is no longer in context *)
  match Flo_structured.get Flo_structured.request_id_key with
  | Some _ -> Flo.info "Still has request_id"
  | None -> Flo.info "request_id no longer in context"

(* Demonstrate span management *)

let fetch_user_data user_id : User_Registered.t =
  (* Simulate database query with span tracking *)
  Unix.sleepf 0.05;  (* 50ms *)
  { user_id; email = user_id ^ "@example.com"; source = "web"; timestamp = Unix.gettimeofday () }

let process_user_order user_id =
  Flo_structured.in_span "process_user_order" (fun _span ->
    Flo.infof "Processing order for user: %s" user_id;

    (* Nested span for database operation *)
    let user_data = Flo_structured.in_span "fetch_user_data" (fun _span ->
      Flo.debug "Fetching user data from database";
      fetch_user_data user_id
    ) in

    (* Another nested span for payment *)
    Flo_structured.in_span "process_payment" (fun _span ->
      Flo.debug "Processing payment";
      Unix.sleepf 0.1;  (* 100ms *)
      let payment_id = "pay_" ^ string_of_int (Random.int 100000) in
      process_payment payment_id user_data.user_id 99.99
    )
  )

let demonstrate_spans () =
  Flo.info "=== Span Management ===";

  (* Execute with automatic span tracking *)
  match process_user_order "alice" with
  | Ok () -> Flo.success "Order processing completed"
  | Error msg -> Flo.errorf "Order processing failed: %s" msg

(* Demonstrate semantic conventions *)

let simulate_http_request () =
  (* Log HTTP request with OpenTelemetry semantic conventions *)
  Flo.info_fields "Incoming HTTP request" ~fields:[
    Flo_semconv.http_method "POST";
    Flo_semconv.http_target "/api/orders";
    Flo_semconv.http_scheme "https";
    Flo_semconv.http_host "api.example.com";
    Flo_semconv.http_user_agent "Mozilla/5.0";
    Flo_semconv.request_id "req-abc-123";
  ];

  (* Simulate processing *)
  Unix.sleepf 0.02;

  (* Log response *)
  Flo.info_fields "HTTP response" ~fields:[
    Flo_semconv.http_status_code 201;
    Flo_semconv.http_response_body_size 156;
    Flo_semconv.duration_ms 20.5;
  ]

let simulate_database_query () =
  (* Log database operation with semantic conventions *)
  Flo.info_fields "Database query" ~fields:[
    Flo_semconv.db_system "postgresql";
    Flo_semconv.db_name "orders_db";
    Flo_semconv.db_operation "SELECT";
    Flo_semconv.db_statement "SELECT * FROM orders WHERE user_id = $1";
    Flo_semconv.db_user "app_user";
    Flo_semconv.db_sql_table "orders";
  ];

  Unix.sleepf 0.015;

  Flo.info_fields "Query completed" ~fields:[
    Flo_semconv.duration_ms 15.2;
  ]

let simulate_messaging () =
  (* Log message queue operation *)
  Flo.info_fields "Publishing message" ~fields:[
    Flo_semconv.messaging_system "kafka";
    Flo_semconv.messaging_destination "order-events";
    Flo_semconv.messaging_destination_kind "topic";
    Flo_semconv.messaging_message_id "msg-12345";
    Flo_semconv.messaging_protocol "kafka";
    Flo_semconv.messaging_message_payload_size 512;
  ]

let simulate_error () =
  (* Log error with semantic conventions *)
  try
    raise (Invalid_argument "Validation failed: amount must be positive")
  with exn ->
    Flo.info_fields "Error occurred" ~fields:[
      Flo_semconv.error_type (Printexc.to_string exn);
      Flo_semconv.error_message (Printexc.to_string exn);
      Flo_semconv.error_stack_trace (Printexc.get_backtrace ());
    ]

let demonstrate_semantic_conventions () =
  Flo.info "=== OpenTelemetry Semantic Conventions ===";

  (* Service metadata *)
  Flo.info_fields "Service info" ~fields:[
    Flo_semconv.service_name "order-service";
    Flo_semconv.service_version "1.2.3";
    Flo_semconv.deployment_environment "production";
  ];

  Flo.info "";

  (* HTTP operations *)
  Flo.info "Simulating HTTP request...";
  simulate_http_request ();

  Flo.info "";

  (* Database operations *)
  Flo.info "Simulating database query...";
  simulate_database_query ();

  Flo.info "";

  (* Messaging *)
  Flo.info "Simulating message queue...";
  simulate_messaging ();

  Flo.info "";

  (* Error handling *)
  Flo.info "Simulating error...";
  simulate_error ();

  Flo.info "";

  (* Cloud and host attributes *)
  Flo.info_fields "Deployment context" ~fields:[
    Flo_semconv.cloud_provider "aws";
    Flo_semconv.cloud_region "us-east-1";
    Flo_semconv.host_name "web-server-01";
    Flo_semconv.host_type "t3.medium";
    Flo_semconv.process_pid (Unix.getpid ());
  ]

(* Main example *)

let main () =
  Flo.info "=== Flo Structured Logging Example ===";
  Flo.info "";

  (* Demonstrate structured events *)
  Flo.info "=== Structured Events ===";
  let user_id = register_user "alice@example.com" "web" in
  Flo.infof "Registered user: %s" user_id;

  let order_id = create_order user_id 3 99.99 in
  Flo.infof "Created order: %s" order_id;

  Flo.info "";

  (* Demonstrate typed context keys *)
  demonstrate_typed_keys ();

  Flo.info "";

  (* Demonstrate span management *)
  demonstrate_spans ();

  Flo.info "";

  (* Demonstrate semantic conventions *)
  demonstrate_semantic_conventions ();

  Flo.info "";
  Flo.success "Example completed!"

let () =
  Random.self_init ();
  main ()
