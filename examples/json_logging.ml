(* JSON Logging Examples
 *
 * This example demonstrates JSON-formatted logging for production systems,
 * log aggregators (ELK, Splunk, Datadog), and OpenTelemetry integration.
 *)

(* Example 1: JSON to stdout for Log Aggregators *)
let example_json_to_stdout () =
  Eio.traceln "\n=== JSON to stdout (for log aggregators) ===\n";

  (* Create records and output as JSON - ready for ELK/Splunk/Datadog *)
  let record1 = Record.make ~severity:Severity.Info ~message:"Application started" in
  let record1 = Record.with_attributes [
    ("service", Value.String "order-service");
    ("version", Value.String "2.1.0");
    ("environment", Value.String "production");
  ] record1 in

  let record2 = Record.make ~severity:Severity.Info ~message:"HTTP request processed" in
  let record2 = Record.with_attributes [
    ("method", Value.String "POST");
    ("path", Value.String "/api/orders");
    ("status", Value.Int 201L);
    ("duration_ms", Value.Float 45.2);
  ] record2 in

  (* Output to stdout - log aggregators parse this *)
  print_endline (Flo_format_json.format record1);
  print_endline (Flo_format_json.format record2);

  Eio.traceln "\nNote: Redirect to log aggregator: ./app | fluentd -c fluent.conf"

(* Example 2: JSON with Full OpenTelemetry Structure *)
let example_json_otel () =
  Eio.traceln "\n=== JSON with OpenTelemetry Structure ===\n";

  (* Create a log with full OTel compliance *)
  let span_ctx = {
    Trace_context.trace_id = "9a6e06a1a475973dabea325fd8ea2654";
    Trace_context.span_id = "7c2a202a2e61021c";
    Trace_context.parent_span_id = Some "1234567890abcdef";
    Trace_context.trace_flags = 1;  (* Sampled *)
  } in

  let loc = Location.make_full
    ~file:"order_handler.ml"
    ~line:142
    ~column:8
    ~module_name:"Order_handler"
    ~function_name:"process_order"
    ()
  in

  let record = Record.make ~severity:Severity.Info ~message:"Order processed" in
  let record = Record.with_span_context span_ctx record in
  let record = Record.with_location loc record in
  let record = Record.with_attributes [
    ("service.name", Value.String "order-service");
    ("service.version", Value.String "2.1.0");
    ("deployment.environment", Value.String "production");
    ("http.method", Value.String "POST");
    ("http.status_code", Value.Int 201L);
    ("http.target", Value.String "/api/orders");
    ("user.id", Value.String "alice");
    ("order.id", Value.String "ORD-12345");
    ("order.total", Value.Float 99.99);
  ] record in

  let json = Flo_format_json.format record in
  Eio.traceln "OpenTelemetry-compliant JSON:";
  Eio.traceln "%s" json;

  Eio.traceln "\nIncludes: trace_id, span_id, location, semantic conventions"

(* Example 3: JSON Parsing and Querying *)
let example_json_parsing () =
  Eio.traceln "\n=== JSON Parsing and Querying ===\n";

  (* Create and format a record *)
  let original = Record.make ~severity:Severity.Warn ~message:"High memory usage" in
  let original = Record.with_attributes [
    ("host", Value.String "app-server-01");
    ("memory_mb", Value.Int 1536L);
    ("threshold_mb", Value.Int 1024L);
    ("percent", Value.Float 75.5);
  ] original in

  let json_str = Flo_format_json.format original in
  Eio.traceln "Formatted JSON:";
  Eio.traceln "%s" json_str;

  (* Parse it back *)
  Eio.traceln "\nParsing back to record:";
  match Flo_format_json.parse json_str with
  | Ok parsed ->
      Eio.traceln "  Severity: %s" (Severity.to_string parsed.Record.severity);
      Eio.traceln "  Message: %s" parsed.Record.message;
      Eio.traceln "  Attributes:";
      List.iter (fun (k, v) ->
        Eio.traceln "    %s = %s" k (Value.to_string v)
      ) parsed.Record.attributes;

      (* Query specific fields *)
      Eio.traceln "\nQuerying fields:";
      (match List.assoc_opt "memory_mb" parsed.Record.attributes with
       | Some (Value.Int mb) -> Eio.traceln "  Memory: %Ld MB" mb
       | _ -> Eio.traceln "  Memory: not found")
  | Error err ->
      Eio.traceln "  Parse error: %s" err

(* Example 4: JSON for Different Use Cases *)
let example_json_use_cases () =
  Eio.traceln "\n=== JSON for Different Use Cases ===\n";

  (* Use case 1: Application logs for ELK stack *)
  Eio.traceln "1. ELK Stack (Elasticsearch/Logstash/Kibana):";
  let elk_record = Record.make ~severity:Severity.Info ~message:"User action" in
  let elk_record = Record.with_attributes [
    ("@timestamp", Value.String (Ptime.to_rfc3339 (Ptime_clock.now ())));
    ("service", Value.String "web-app");
    ("user_id", Value.String "alice");
    ("action", Value.String "login");
  ] elk_record in
  Eio.traceln "%s" (Flo_format_json.format elk_record);

  (* Use case 2: Cloud logging (GCP/AWS) *)
  Eio.traceln "\n2. Cloud Logging (GCP CloudWatch/AWS CloudWatch):";
  let cloud_record = Record.make ~severity:Severity.Error ~message:"API error" in
  let cloud_record = Record.with_attributes [
    ("cloud.provider", Value.String "gcp");
    ("cloud.region", Value.String "us-central1");
    ("error.type", Value.String "TimeoutError");
    ("error.message", Value.String "Request timeout after 30s");
  ] cloud_record in
  Eio.traceln "%s" (Flo_format_json.format cloud_record);

  (* Use case 3: Metrics extraction *)
  Eio.traceln "\n3. Metrics Extraction (Prometheus/Grafana):";
  let metrics_record = Record.make ~severity:Severity.Info ~message:"Request metrics" in
  let metrics_record = Record.with_attributes [
    ("metric.name", Value.String "http_request_duration_seconds");
    ("metric.value", Value.Float 0.045);
    ("metric.type", Value.String "histogram");
    ("labels.method", Value.String "POST");
    ("labels.status", Value.String "200");
  ] metrics_record in
  Eio.traceln "%s" (Flo_format_json.format metrics_record)

(* Example 5: Structured JSON for Analysis *)
let example_json_for_analysis () =
  Eio.traceln "\n=== Structured JSON for Log Analysis ===\n";

  (* Create logs with rich structure for analysis *)
  let records = [
    ("User registration", [
      ("event.type", Value.String "user.registered");
      ("user.id", Value.String "user-001");
      ("user.email", Value.String "alice@example.com");
      ("source", Value.String "web");
      ("referrer", Value.String "google");
    ]);
    ("Payment processed", [
      ("event.type", Value.String "payment.processed");
      ("payment.id", Value.String "pay-123");
      ("user.id", Value.String "user-001");
      ("amount", Value.Float 99.99);
      ("currency", Value.String "USD");
      ("payment.method", Value.String "card");
    ]);
    ("Order shipped", [
      ("event.type", Value.String "order.shipped");
      ("order.id", Value.String "ord-456");
      ("user.id", Value.String "user-001");
      ("tracking", Value.String "1Z999AA10123456784");
      ("carrier", Value.String "ups");
    ]);
  ] in

  Eio.traceln "Event stream (JSON Lines format):";
  List.iter (fun (msg, attrs) ->
    let r = Record.make ~severity:Severity.Info ~message:msg in
    let r = Record.with_attributes attrs r in
    print_endline (Flo_format_json.format r)
  ) records;

  Eio.traceln "\nAnalysis queries:";
  Eio.traceln "  jq '.attributes.\"user.id\"' logs.jsonl | sort | uniq -c";
  Eio.traceln "  jq 'select(.attributes.\"event.type\" == \"payment.processed\")' logs.jsonl"

(* Example 6: JSON with Nested Structures *)
let example_json_nested () =
  Eio.traceln "\n=== JSON with Nested Structures ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"Complex event" in
  let record = Record.with_attributes [
    ("event", Value.String "order.created");
    ("user", Value.Object [
      ("id", Value.String "user-123");
      ("email", Value.String "bob@example.com");
      ("tier", Value.String "premium");
    ]);
    ("order", Value.Object [
      ("id", Value.String "ord-789");
      ("total", Value.Float 299.99);
      ("items", Value.Array [
        Value.Object [("sku", Value.String "ITEM-1"); ("qty", Value.Int 2L)];
        Value.Object [("sku", Value.String "ITEM-2"); ("qty", Value.Int 1L)];
      ]);
    ]);
    ("metadata", Value.Object [
      ("ip", Value.String "192.168.1.1");
      ("user_agent", Value.String "Mozilla/5.0");
    ]);
  ] record in

  Eio.traceln "%s" (Flo_format_json.format record);
  Eio.traceln "\nJSON preserves nested structure perfectly (unlike logfmt)"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║              Flō JSON Logging Examples                         ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_json_to_stdout ();
  example_json_otel ();
  example_json_parsing ();
  example_json_use_cases ();
  example_json_for_analysis ();
  example_json_nested ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
