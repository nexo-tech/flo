(* Semantic Conventions Examples
 *
 * This example demonstrates OpenTelemetry semantic conventions for
 * standardized logging across different operation types.
 *)

(* Example 1: HTTP Server Instrumentation *)
let example_http_server () =
  Eio.traceln "\n=== HTTP Server Instrumentation ===\n";

  let handle_request method_ target status duration_ms =
    let record = Record.make ~severity:Severity.Info ~message:"HTTP request" in
    let record = Record.with_attributes [
      Flo_semconv.http_method method_;
      Flo_semconv.http_target target;
      Flo_semconv.http_status_code status;
      Flo_semconv.http_scheme "https";
      Flo_semconv.http_host "api.example.com";
      Flo_semconv.http_route "/api/orders/:id";
      Flo_semconv.http_user_agent "Mozilla/5.0";
      ("duration_ms", Value.Float duration_ms);
      Flo_semconv.net_protocol_name "http";
      Flo_semconv.net_protocol_version "1.1";
    ] record in

    Eio.traceln "%s" (Flo_format_logfmt.format record)
  in

  Eio.traceln "GET request (success):";
  handle_request "GET" "/api/orders/123" 200 45.2;

  Eio.traceln "\nPOST request (created):";
  handle_request "POST" "/api/orders" 201 123.5;

  Eio.traceln "\nDELETE request (error):";
  handle_request "DELETE" "/api/orders/999" 404 12.3;

  Eio.traceln "\nStandardized HTTP attributes enable cross-service analysis"

(* Example 2: Database Operation Logging *)
let example_database_operations () =
  Eio.traceln "\n=== Database Operation Logging ===\n";

  let log_db_query system operation table statement duration_ms =
    let record = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "Database %s" operation) in
    let record = Record.with_attributes [
      Flo_semconv.db_system system;
      Flo_semconv.db_operation operation;
      Flo_semconv.db_name "production_db";
      Flo_semconv.db_sql_table table;
      Flo_semconv.db_statement statement;
      Flo_semconv.db_user "app_user";
      ("duration_ms", Value.Float duration_ms);
    ] record in

    Eio.traceln "%s" (Flo_format_logfmt.format record)
  in

  Eio.traceln "SELECT query:";
  log_db_query "postgresql" "SELECT" "users"
    "SELECT * FROM users WHERE id = $1" 12.3;

  Eio.traceln "\nINSERT query:";
  log_db_query "postgresql" "INSERT" "orders"
    "INSERT INTO orders (user_id, total) VALUES ($1, $2)" 23.5;

  Eio.traceln "\nUPDATE query:";
  log_db_query "postgresql" "UPDATE" "users"
    "UPDATE users SET last_login = NOW() WHERE id = $1" 8.7;

  Eio.traceln "\nStandardized DB attributes for query performance analysis"

(* Example 3: RPC Call Instrumentation *)
let example_rpc_calls () =
  Eio.traceln "\n=== RPC Call Instrumentation ===\n";

  let log_rpc_call system service method_ status duration_ms =
    let record = Record.make ~severity:Severity.Info ~message:"RPC call" in
    let record = Record.with_attributes [
      Flo_semconv.rpc_system system;
      Flo_semconv.rpc_service service;
      Flo_semconv.rpc_method method_;
      ("rpc.status_code", Value.Int (Int64.of_int status));
      ("duration_ms", Value.Float duration_ms);
      Flo_semconv.net_peer_name "rpc-server.example.com";
      Flo_semconv.net_peer_port 50051;
    ] record in

    Eio.traceln "%s" (Flo_format_logfmt.format record)
  in

  Eio.traceln "gRPC calls:";
  log_rpc_call "grpc" "OrderService" "CreateOrder" 0 45.2;
  log_rpc_call "grpc" "UserService" "GetUser" 0 12.1;
  log_rpc_call "grpc" "PaymentService" "ProcessPayment" 5 234.5;

  Eio.traceln "\nStandardized RPC attributes for distributed systems"

(* Example 4: Cloud Provider Attributes *)
let example_cloud_attributes () =
  Eio.traceln "\n=== Cloud Provider Attributes ===\n";

  (* GCP deployment *)
  Eio.traceln "Google Cloud Platform:";
  let gcp_record = Record.make ~severity:Severity.Info ~message:"Application started" in
  let gcp_record = Record.with_attributes [
    Flo_semconv.cloud_provider "gcp";
    Flo_semconv.cloud_region "us-central1";
    Flo_semconv.cloud_availability_zone "us-central1-a";
    Flo_semconv.cloud_account_id "project-12345";
    Flo_semconv.host_name "instance-1";
    ("host.type", Value.String "n1-standard-4");
  ] gcp_record in
  Eio.traceln "%s" (Flo_format_logfmt.format gcp_record);

  (* AWS deployment *)
  Eio.traceln "\nAmazon Web Services:";
  let aws_record = Record.make ~severity:Severity.Info ~message:"Application started" in
  let aws_record = Record.with_attributes [
    Flo_semconv.cloud_provider "aws";
    Flo_semconv.cloud_region "us-east-1";
    Flo_semconv.cloud_availability_zone "us-east-1a";
    Flo_semconv.cloud_account_id "123456789012";
    Flo_semconv.host_name "i-0abc123def456";
    ("host.type", Value.String "t3.medium");
  ] aws_record in
  Eio.traceln "%s" (Flo_format_logfmt.format aws_record);

  Eio.traceln "\nCloud attributes enable multi-cloud monitoring"

(* Example 5: User and Session Tracking *)
let example_user_session_tracking () =
  Eio.traceln "\n=== User and Session Tracking ===\n";

  let log_user_action action =
    let record = Record.make ~severity:Severity.Info ~message:action in
    let record = Record.with_attributes [
      Flo_semconv.user_id "user-12345";
      Flo_semconv.user_email "alice@example.com";
      Flo_semconv.user_name "Alice Smith";
      Flo_semconv.user_roles ["admin"; "developer"];
      ("session.id", Value.String "sess-abc-123");
      ("session.created_at", Value.Float (Unix.gettimeofday ()));
      ("session.ip", Value.String "192.168.1.100");
    ] record in

    Eio.traceln "%s" (Flo_format_logfmt.format record)
  in

  log_user_action "User logged in";
  log_user_action "User viewed dashboard";
  log_user_action "User created order";

  Eio.traceln "\nUser tracking enables behavior analysis and security auditing"

(* Example 6: Custom Semantic Conventions *)
let example_custom_conventions () =
  Eio.traceln "\n=== Custom Semantic Conventions ===\n";

  (* Define custom conventions for your domain *)
  let order_id id = ("order.id", Value.String id) in
  let order_total total = ("order.total", Value.Float total) in
  let order_items count = ("order.items", Value.Int (Int64.of_int count)) in
  let order_status status = ("order.status", Value.String status) in

  let payment_method method_ = ("payment.method", Value.String method_) in
  let payment_provider provider = ("payment.provider", Value.String provider) in

  let record = Record.make ~severity:Severity.Success ~message:"Order completed" in
  let record = Record.with_attributes [
    order_id "ORD-12345";
    order_total 299.99;
    order_items 5;
    order_status "completed";
    payment_method "credit_card";
    payment_provider "stripe";
    Flo_semconv.user_id "user-789";
    ("processing_time_ms", Value.Float 456.7);
  ] record in

  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nCustom conventions for domain-specific attributes";
  Eio.traceln "Pattern: namespace.attribute (e.g., order.id, payment.method)"

(* Example 7: Complete Instrumentation Example *)
let example_complete_instrumentation () =
  Eio.traceln "\n=== Complete Instrumentation (All Conventions) ===\n";

  (* Comprehensive log with multiple convention types *)
  let record = Record.make ~severity:Severity.Info ~message:"Complete trace example" in
  let record = Record.with_attributes [
    (* Service *)
    Flo_semconv.service_name "order-service";
    Flo_semconv.service_version "2.1.0";
    Flo_semconv.deployment_environment "production";

    (* HTTP *)
    Flo_semconv.http_method "POST";
    Flo_semconv.http_target "/api/orders";
    Flo_semconv.http_status_code 201;

    (* Database *)
    Flo_semconv.db_system "postgresql";
    Flo_semconv.db_operation "INSERT";
    Flo_semconv.db_sql_table "orders";

    (* User *)
    Flo_semconv.user_id "user-456";
    Flo_semconv.user_email "bob@example.com";

    (* Cloud *)
    Flo_semconv.cloud_provider "gcp";
    Flo_semconv.cloud_region "us-central1";

    (* Host *)
    Flo_semconv.host_name "order-service-pod-7";

    (* Custom *)
    ("order.id", Value.String "ORD-98765");
    ("order.total", Value.Float 199.99);
  ] record in

  Eio.traceln "JSON format (for aggregation):";
  Eio.traceln "%s" (Flo_format_json.format record);

  Eio.traceln "\nIncludes conventions for: service, HTTP, DB, user, cloud, host, custom"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Semantic Conventions Examples                     ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_http_server ();
  example_database_operations ();
  example_rpc_calls ();
  example_cloud_attributes ();
  example_user_session_tracking ();
  example_custom_conventions ();
  example_complete_instrumentation ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
