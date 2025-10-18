(* Tests for Flo_semconv module *)

open Flo_semconv

(* Helper to check attribute key-value pairs *)
let check_attr desc expected_key expected_value actual =
  let (key, value) = actual in
  Alcotest.(check string) (desc ^ " - key") expected_key key;
  Alcotest.(check string) (desc ^ " - value") (Value.to_string expected_value) (Value.to_string value)

(* Test general attributes *)
let test_general_attributes () =
  check_attr "service_name" "service.name"
    (Value.String "my-service")
    (service_name "my-service");

  check_attr "service_version" "service.version"
    (Value.String "1.0.0")
    (service_version "1.0.0");

  check_attr "service_instance_id" "service.instance.id"
    (Value.String "instance-1")
    (service_instance_id "instance-1");

  check_attr "deployment_environment" "deployment.environment"
    (Value.String "production")
    (deployment_environment "production")

(* Test HTTP attributes *)
let test_http_attributes () =
  check_attr "http_method" "http.method"
    (Value.String "GET")
    (http_method "GET");

  check_attr "http_status_code" "http.status_code"
    (Value.Int 200L)
    (http_status_code 200);

  check_attr "http_url" "http.url"
    (Value.String "https://example.com/path")
    (http_url "https://example.com/path");

  check_attr "http_target" "http.target"
    (Value.String "/api/users?id=123")
    (http_target "/api/users?id=123");

  check_attr "http_host" "http.host"
    (Value.String "example.com")
    (http_host "example.com");

  check_attr "http_scheme" "http.scheme"
    (Value.String "https")
    (http_scheme "https");

  check_attr "http_user_agent" "http.user_agent"
    (Value.String "Mozilla/5.0")
    (http_user_agent "Mozilla/5.0");

  check_attr "http_request_body_size" "http.request.body.size"
    (Value.Int 1024L)
    (http_request_body_size 1024);

  check_attr "http_response_body_size" "http.response.body.size"
    (Value.Int 2048L)
    (http_response_body_size 2048);

  check_attr "http_route" "http.route"
    (Value.String "/users/:id")
    (http_route "/users/:id")

(* Test database attributes *)
let test_database_attributes () =
  check_attr "db_system" "db.system"
    (Value.String "postgresql")
    (db_system "postgresql");

  check_attr "db_name" "db.name"
    (Value.String "mydb")
    (db_name "mydb");

  check_attr "db_operation" "db.operation"
    (Value.String "SELECT")
    (db_operation "SELECT");

  check_attr "db_statement" "db.statement"
    (Value.String "SELECT * FROM users")
    (db_statement "SELECT * FROM users");

  check_attr "db_user" "db.user"
    (Value.String "app_user")
    (db_user "app_user");

  check_attr "db_connection_string" "db.connection_string"
    (Value.String "postgresql://localhost:5432/mydb")
    (db_connection_string "postgresql://localhost:5432/mydb");

  check_attr "db_sql_table" "db.sql.table"
    (Value.String "users")
    (db_sql_table "users")

(* Test messaging attributes *)
let test_messaging_attributes () =
  check_attr "messaging_system" "messaging.system"
    (Value.String "kafka")
    (messaging_system "kafka");

  check_attr "messaging_destination" "messaging.destination"
    (Value.String "my-topic")
    (messaging_destination "my-topic");

  check_attr "messaging_destination_kind" "messaging.destination.kind"
    (Value.String "topic")
    (messaging_destination_kind "topic");

  check_attr "messaging_message_id" "messaging.message.id"
    (Value.String "msg-123")
    (messaging_message_id "msg-123");

  check_attr "messaging_protocol" "messaging.protocol"
    (Value.String "AMQP")
    (messaging_protocol "AMQP");

  check_attr "messaging_message_payload_size" "messaging.message.payload_size_bytes"
    (Value.Int 512L)
    (messaging_message_payload_size 512)

(* Test RPC attributes *)
let test_rpc_attributes () =
  check_attr "rpc_system" "rpc.system"
    (Value.String "grpc")
    (rpc_system "grpc");

  check_attr "rpc_service" "rpc.service"
    (Value.String "MyService")
    (rpc_service "MyService");

  check_attr "rpc_method" "rpc.method"
    (Value.String "GetUser")
    (rpc_method "GetUser")

(* Test error attributes *)
let test_error_attributes () =
  check_attr "error_type" "error.type"
    (Value.String "ValueError")
    (error_type "ValueError");

  check_attr "error_message" "error.message"
    (Value.String "Invalid input")
    (error_message "Invalid input");

  check_attr "error_stack_trace" "error.stack_trace"
    (Value.String "stack trace here")
    (error_stack_trace "stack trace here")

(* Test network attributes *)
let test_network_attributes () =
  check_attr "net_protocol_name" "net.protocol.name"
    (Value.String "tcp")
    (net_protocol_name "tcp");

  check_attr "net_protocol_version" "net.protocol.version"
    (Value.String "1.1")
    (net_protocol_version "1.1");

  check_attr "net_peer_name" "net.peer.name"
    (Value.String "192.168.1.1")
    (net_peer_name "192.168.1.1");

  check_attr "net_peer_port" "net.peer.port"
    (Value.Int 8080L)
    (net_peer_port 8080)

(* Test user attributes *)
let test_user_attributes () =
  check_attr "user_id" "user.id"
    (Value.String "user-123")
    (user_id "user-123");

  check_attr "user_email" "user.email"
    (Value.String "user@example.com")
    (user_email "user@example.com");

  check_attr "user_name" "user.name"
    (Value.String "Alice")
    (user_name "Alice");

  let (key, value) = user_roles ["admin"; "user"] in
  Alcotest.(check string) "user_roles - key" "user.roles" key;
  match value with
  | Value.Array roles ->
      Alcotest.(check int) "user_roles - length" 2 (List.length roles);
      (match List.nth roles 0 with
       | Value.String s -> Alcotest.(check string) "user_roles - first" "admin" s
       | _ -> Alcotest.fail "Expected string");
      (match List.nth roles 1 with
       | Value.String s -> Alcotest.(check string) "user_roles - second" "user" s
       | _ -> Alcotest.fail "Expected string")
  | _ -> Alcotest.fail "Expected array"

(* Test cloud attributes *)
let test_cloud_attributes () =
  check_attr "cloud_provider" "cloud.provider"
    (Value.String "aws")
    (cloud_provider "aws");

  check_attr "cloud_account_id" "cloud.account.id"
    (Value.String "123456789")
    (cloud_account_id "123456789");

  check_attr "cloud_region" "cloud.region"
    (Value.String "us-east-1")
    (cloud_region "us-east-1");

  check_attr "cloud_availability_zone" "cloud.availability_zone"
    (Value.String "us-east-1a")
    (cloud_availability_zone "us-east-1a")

(* Test host attributes *)
let test_host_attributes () =
  check_attr "host_name" "host.name"
    (Value.String "server-01")
    (host_name "server-01");

  check_attr "host_type" "host.type"
    (Value.String "t2.micro")
    (host_type "t2.micro");

  check_attr "host_arch" "host.arch"
    (Value.String "x86_64")
    (host_arch "x86_64")

(* Test process attributes *)
let test_process_attributes () =
  check_attr "process_pid" "process.pid"
    (Value.Int 12345L)
    (process_pid 12345);

  check_attr "process_executable_name" "process.executable.name"
    (Value.String "my_app")
    (process_executable_name "my_app");

  check_attr "process_command_line" "process.command_line"
    (Value.String "./my_app --config config.yaml")
    (process_command_line "./my_app --config config.yaml")

(* Test performance attributes *)
let test_performance_attributes () =
  check_attr "duration_ms" "duration_ms"
    (Value.Float 123.45)
    (duration_ms 123.45);

  check_attr "duration" "duration"
    (Value.Float 1.5)
    (duration 1.5)

(* Test session attributes *)
let test_session_attributes () =
  check_attr "session_id" "session.id"
    (Value.String "session-abc")
    (session_id "session-abc");

  check_attr "request_id" "request.id"
    (Value.String "req-123")
    (request_id "req-123");

  check_attr "correlation_id" "correlation.id"
    (Value.String "corr-xyz")
    (correlation_id "corr-xyz")

(* Test usage with Flo *)
let test_usage_with_flo () =
  (* Just verify these work without errors *)
  let _attrs = [
    service_name "test-service";
    http_method "GET";
    db_system "postgresql";
    user_id "user-1";
  ] in
  Alcotest.(check bool) "usage with Flo" true true

(* Test suite *)
let () =
  Alcotest.run "Flo_semconv" [
    "general_attributes", [
      Alcotest.test_case "general attributes" `Quick test_general_attributes;
    ];
    "http_attributes", [
      Alcotest.test_case "http attributes" `Quick test_http_attributes;
    ];
    "database_attributes", [
      Alcotest.test_case "database attributes" `Quick test_database_attributes;
    ];
    "messaging_attributes", [
      Alcotest.test_case "messaging attributes" `Quick test_messaging_attributes;
    ];
    "rpc_attributes", [
      Alcotest.test_case "rpc attributes" `Quick test_rpc_attributes;
    ];
    "error_attributes", [
      Alcotest.test_case "error attributes" `Quick test_error_attributes;
    ];
    "network_attributes", [
      Alcotest.test_case "network attributes" `Quick test_network_attributes;
    ];
    "user_attributes", [
      Alcotest.test_case "user attributes" `Quick test_user_attributes;
    ];
    "cloud_attributes", [
      Alcotest.test_case "cloud attributes" `Quick test_cloud_attributes;
    ];
    "host_attributes", [
      Alcotest.test_case "host attributes" `Quick test_host_attributes;
    ];
    "process_attributes", [
      Alcotest.test_case "process attributes" `Quick test_process_attributes;
    ];
    "performance_attributes", [
      Alcotest.test_case "performance attributes" `Quick test_performance_attributes;
    ];
    "session_attributes", [
      Alcotest.test_case "session attributes" `Quick test_session_attributes;
    ];
    "usage", [
      Alcotest.test_case "usage with Flo" `Quick test_usage_with_flo;
    ];
  ]
