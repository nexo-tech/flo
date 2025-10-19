(* Logfmt Output Examples
 *
 * This example demonstrates the logfmt format - a human-readable structured format
 * that's easier to grep and parse than JSON, commonly used in production systems.
 *
 * Logfmt format: key1=value1 key2=value2 key3="quoted value"
 *)

(* Example 1: Basic Logfmt Logging to Console *)
let example_basic_logfmt () =
  Eio.traceln "\n=== Basic Logfmt Logging ===\n";

  (* Create simple log records and format them *)
  let record1 = Record.make ~severity:Severity.Info ~message:"Application started" in
  let record2 = Record.make ~severity:Severity.Success ~message:"Task completed" in
  let record3 = Record.make ~severity:Severity.Warn ~message:"Memory usage high" in

  Eio.traceln "Logfmt format:";
  Eio.traceln "%s" (Flo_format_logfmt.format record1);
  Eio.traceln "%s" (Flo_format_logfmt.format record2);
  Eio.traceln "%s" (Flo_format_logfmt.format record3);

  Eio.traceln "\nNote: Logfmt is easy to grep: grep 'severity=warn' logs.txt"

(* Example 2: Logfmt with Structured Fields *)
let example_logfmt_structured () =
  Eio.traceln "\n=== Logfmt with Structured Fields ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"HTTP request" in
  let record = Record.with_attributes [
    ("method", Value.String "POST");
    ("path", Value.String "/api/orders");
    ("status", Value.Int 201L);
    ("duration_ms", Value.Float 42.5);
    ("user_id", Value.String "alice");
    ("bytes_sent", Value.Int 1024L);
  ] record in

  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nAdvantages:";
  Eio.traceln "  - Easy to read: key=value pairs";
  Eio.traceln "  - Easy to grep: grep 'user_id=alice' logs.txt";
  Eio.traceln "  - Easy to parse: simple split on space and =";
  Eio.traceln "  - Compact: less overhead than JSON"

(* Example 3: Logfmt with Nested Attributes (Flattening) *)
let example_logfmt_nested () =
  Eio.traceln "\n=== Logfmt with Nested Attributes (Flattening) ===\n";

  (* Logfmt flattens nested structures *)
  let record = Record.make ~severity:Severity.Info ~message:"User action" in
  let record = Record.with_attributes [
    ("user_id", Value.String "bob");
    ("metadata", Value.Object [
      ("source", Value.String "mobile_app");
      ("version", Value.String "2.1.0");
      ("device", Value.String "iPhone");
    ]);
    ("tags", Value.Array [
      Value.String "important";
      Value.String "analytics";
    ]);
  ] record in

  Eio.traceln "Original (nested):";
  Eio.traceln "%s" (Flo_format_json.format record);

  Eio.traceln "\nLogfmt (flattened):";
  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nNote: Nested objects/arrays are represented as [object] or [array] in logfmt"

(* Example 4: Logfmt vs JSON Comparison *)
let example_logfmt_vs_json () =
  Eio.traceln "\n=== Logfmt vs JSON Comparison ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"Performance metrics" in
  let record = Record.with_attributes [
    ("cpu_usage", Value.Float 75.5);
    ("memory_mb", Value.Int 512L);
    ("connections", Value.Int 150L);
    ("throughput_rps", Value.Float 1234.56);
  ] record in

  Eio.traceln "JSON format:";
  Eio.traceln "%s" (Flo_format_json.format record);

  Eio.traceln "\nLogfmt format:";
  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nReadability comparison:";
  Eio.traceln "  JSON: Better for nested data, machine parsing";
  Eio.traceln "  Logfmt: Better for human reading, simple grep";
  Eio.traceln "  Logfmt: ~30%% shorter for flat data"

(* Example 5: Logfmt with Special Characters *)
let example_logfmt_special_chars () =
  Eio.traceln "\n=== Logfmt with Special Characters (Quoting) ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"Log with special chars" in
  let record = Record.with_attributes [
    ("simple", Value.String "value");
    ("with_spaces", Value.String "hello world");
    ("with_quotes", Value.String "say \"hello\"");
    ("with_equals", Value.String "key=value");
    ("with_newlines", Value.String "line1\nline2");
  ] record in

  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nQuoting rules:";
  Eio.traceln "  - Simple values: no quotes";
  Eio.traceln "  - Spaces/special chars: quoted";
  Eio.traceln "  - Escape sequences: \\n \\t \\\" \\\\";
  Eio.traceln "  - Empty strings: quoted"

(* Example 6: Parse Logfmt Back to Records *)
let example_logfmt_parsing () =
  Eio.traceln "\n=== Parsing Logfmt Back to Records ===\n";

  (* Create a record, format it, then parse it back *)
  let original = Record.make ~severity:Severity.Info ~message:"Test message" in
  let original = Record.with_attributes [
    ("user_id", Value.String "charlie");
    ("count", Value.Int 99L);
  ] original in

  let formatted = Flo_format_logfmt.format original in
  Eio.traceln "Formatted logfmt:";
  Eio.traceln "%s" formatted;

  Eio.traceln "\nParsing back:";
  match Flo_format_logfmt.parse formatted with
  | Ok parsed ->
      Eio.traceln "  Severity: %s" (Severity.to_string parsed.severity);
      Eio.traceln "  Message: %s" parsed.message;
      Eio.traceln "  Attributes: %d fields" (List.length parsed.attributes);
      List.iter (fun (k, v) ->
        Eio.traceln "    %s = %s" k (Value.to_string v)
      ) parsed.attributes
  | Error err ->
      Eio.traceln "  Parse error: %s" err

(* Example 7: Logfmt for Production Systems *)
let example_production_logfmt () =
  Eio.traceln "\n=== Logfmt for Production Systems ===\n";

  (* Simulate production logs in logfmt *)
  let logs = [
    ("Application startup", [
      ("service", Value.String "order-service");
      ("version", Value.String "2.1.0");
      ("environment", Value.String "production");
      ("host", Value.String "app-01");
    ]);
    ("HTTP request", [
      ("method", Value.String "POST");
      ("path", Value.String "/api/orders");
      ("status", Value.Int 201L);
      ("duration_ms", Value.Float 45.2);
      ("user_id", Value.String "user-123");
    ]);
    ("Database query", [
      ("query", Value.String "SELECT");
      ("table", Value.String "orders");
      ("duration_ms", Value.Float 12.3);
      ("rows", Value.Int 150L);
    ]);
  ] in

  Eio.traceln "Production logs in logfmt format:\n";
  List.iter (fun (msg, attrs) ->
    let record = Record.make ~severity:Severity.Info ~message:msg in
    let record = Record.with_attributes attrs record in
    Eio.traceln "%s" (Flo_format_logfmt.format record)
  ) logs;

  Eio.traceln "\nCommon production queries:";
  Eio.traceln "  grep 'status=500' app.log            # Find errors";
  Eio.traceln "  grep 'user_id=alice' app.log         # Find user activity";
  Eio.traceln "  awk -F'duration_ms=' '{print $2}' | awk '{print $1}'  # Extract durations"

(* Example 8: Logfmt Readability Test *)
let example_logfmt_readability () =
  Eio.traceln "\n=== Logfmt Readability Test ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"Order created" in
  let record = Record.with_attributes [
    ("order_id", Value.String "ORD-12345");
    ("user_id", Value.String "alice");
    ("total", Value.Float 99.99);
    ("items", Value.Int 3L);
    ("shipping", Value.Float 5.99);
    ("tax", Value.Float 8.50);
    ("currency", Value.String "USD");
  ] record in

  Eio.traceln "Logfmt (one line, scannable):";
  Eio.traceln "%s" (Flo_format_logfmt.format record);

  Eio.traceln "\nJSON (formatted):";
  let json = Flo_format_json.format record in
  Eio.traceln "%s" json;

  Eio.traceln "\nReadability notes:";
  Eio.traceln "  Logfmt: Quick scan, easy grep, ~200 chars";
  Eio.traceln "  JSON: Structured, nested data, ~400 chars"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║              Flō Logfmt Output Examples                        ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_basic_logfmt ();
  example_logfmt_structured ();
  example_logfmt_nested ();
  example_logfmt_vs_json ();
  example_logfmt_special_chars ();
  example_logfmt_parsing ();
  example_production_logfmt ();
  example_logfmt_readability ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
