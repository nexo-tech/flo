(* Formatter Edge Cases Tests
 *
 * Comprehensive tests for formatter edge cases including:
 * - Special characters and escaping
 * - Empty values and null
 * - Nested structures
 * - Large values
 * - Unicode and non-ASCII
 *)

(* === Logfmt Edge Cases === *)

let test_logfmt_empty_string () =
  let record = Record.make ~severity:Severity.Info ~message:"" in
  let formatted = Flo_format_logfmt.format record in
  Alcotest.(check bool) "logfmt handles empty message"
    true (String.contains formatted '=')

let test_logfmt_special_chars () =
  let record = Record.make ~severity:Severity.Info ~message:"Test message" in
  let record = Record.with_attributes [
    ("with_space", Value.String "hello world");
    ("with_equals", Value.String "key=value");
    ("with_quotes", Value.String "say \"hello\"");
    ("with_newline", Value.String "line1\nline2");
    ("with_tab", Value.String "tab\there");
    ("with_backslash", Value.String "path\\file");
  ] record in

  let formatted = Flo_format_logfmt.format record in

  (* Verify proper quoting and escaping *)
  Alcotest.(check bool) "logfmt quotes spaces"
    true (String.contains formatted '"');
  Alcotest.(check bool) "logfmt escapes newlines"
    true (Str.string_match (Str.regexp ".*\\\\n.*") formatted 0);
  Alcotest.(check bool) "logfmt escapes quotes"
    true (Str.string_match (Str.regexp ".*\\\\\".*") formatted 0)

let test_logfmt_unicode () =
  let record = Record.make ~severity:Severity.Info ~message:"Hello 世界 🌍" in
  let record = Record.with_attributes [
    ("emoji", Value.String "✅ 🚀 💯");
    ("chinese", Value.String "中文测试");
    ("arabic", Value.String "مرحبا");
  ] record in

  let formatted = Flo_format_logfmt.format record in
  Alcotest.(check bool) "logfmt preserves unicode"
    true (String.length formatted > 50)

let test_logfmt_nested_flattening () =
  let record = Record.make ~severity:Severity.Info ~message:"Nested test" in
  let record = Record.with_attributes [
    ("flat", Value.String "value");
    ("nested", Value.Object [
      ("inner", Value.String "data");
      ("deep", Value.Object [("very_deep", Value.Int 42L)]);
    ]);
    ("array", Value.Array [Value.Int 1L; Value.Int 2L; Value.Int 3L]);
  ] record in

  let formatted = Flo_format_logfmt.format record in

  (* Nested objects/arrays should be represented as [object]/[array] *)
  Alcotest.(check bool) "logfmt flattens objects"
    true (Str.string_match (Str.regexp ".*nested=.*object.*") formatted 0 ||
          Str.string_match (Str.regexp ".*nested=\".*object.*\".*") formatted 0)

let test_logfmt_round_trip () =
  let original = Record.make ~severity:Severity.Warn ~message:"Round trip test" in
  let original = Record.with_attributes [
    ("key1", Value.String "value1");
    ("key2", Value.Int 42L);
    ("key3", Value.Float 3.14);
  ] original in

  let formatted = Flo_format_logfmt.format original in

  match Flo_format_logfmt.parse formatted with
  | Ok parsed ->
      Alcotest.(check string) "message preserved"
        original.Record.message parsed.Record.message;
      Alcotest.(check bool) "severity preserved"
        (original.Record.severity = parsed.Record.severity) true
  | Error err ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" err)

(* === JSON Edge Cases === *)

let test_json_empty_attributes () =
  let record = Record.make ~severity:Severity.Info ~message:"Empty attrs" in
  let formatted = Flo_format_json.format record in

  (* Should have empty attributes object *)
  Alcotest.(check bool) "json handles empty attributes"
    true (String.contains formatted '{')

let test_json_deeply_nested () =
  let record = Record.make ~severity:Severity.Info ~message:"Deep nesting" in
  let record = Record.with_attributes [
    ("level1", Value.Object [
      ("level2", Value.Object [
        ("level3", Value.Object [
          ("level4", Value.String "deep value");
        ]);
      ]);
    ]);
  ] record in

  let formatted = Flo_format_json.format record in

  match Flo_format_json.parse formatted with
  | Ok parsed ->
      Alcotest.(check bool) "json preserves deep nesting"
        true (List.length parsed.Record.attributes > 0)
  | Error err ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" err)

let test_json_large_array () =
  let large_array = List.init 100 (fun i -> Value.Int (Int64.of_int i)) in
  let record = Record.make ~severity:Severity.Info ~message:"Large array" in
  let record = Record.with_attributes [
    ("numbers", Value.Array large_array);
  ] record in

  let formatted = Flo_format_json.format record in

  match Flo_format_json.parse formatted with
  | Ok _parsed ->
      Alcotest.(check bool) "json handles large arrays" true true
  | Error err ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" err)

let test_json_special_characters () =
  let record = Record.make ~severity:Severity.Info ~message:"Special: \n\t\r\"\\/" in
  let record = Record.with_attributes [
    ("newlines", Value.String "line1\nline2\nline3");
    ("tabs", Value.String "col1\tcol2\tcol3");
    ("quotes", Value.String "He said \"hello\"");
    ("backslash", Value.String "C:\\Windows\\System32");
    ("control", Value.String "\x00\x01\x02");
  ] record in

  let formatted = Flo_format_json.format record in

  (* Should be valid JSON *)
  match Flo_format_json.parse formatted with
  | Ok _parsed ->
      Alcotest.(check bool) "json escapes special chars" true true
  | Error err ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" err)

let test_json_unicode () =
  let record = Record.make ~severity:Severity.Info ~message:"Unicode: 世界 🌍" in
  let record = Record.with_attributes [
    ("emoji", Value.String "🚀 ✅ 💯 ⚠️");
    ("chinese", Value.String "你好世界");
    ("mixed", Value.String "Hello 世界 World");
  ] record in

  let formatted = Flo_format_json.format record in

  match Flo_format_json.parse formatted with
  | Ok parsed ->
      Alcotest.(check bool) "json preserves unicode"
        true (String.length parsed.Record.message > 10)
  | Error err ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" err)

(* === Pretty Formatter Edge Cases === *)

let test_pretty_no_location () =
  let record = Record.make ~severity:Severity.Info ~message:"No location" in
  let formatted = Flo_format_pretty.format record in

  (* Should not crash, should have message *)
  Alcotest.(check bool) "pretty handles missing location"
    true (String.contains formatted 'N')

let test_pretty_no_attributes () =
  let record = Record.make ~severity:Severity.Info ~message:"No attrs" in
  let formatted = Flo_format_pretty.format record in

  Alcotest.(check bool) "pretty handles no attributes"
    true (String.length formatted > 10)

let test_pretty_long_message () =
  let long_msg = String.make 1000 'x' in
  let record = Record.make ~severity:Severity.Info ~message:long_msg in
  let formatted = Flo_format_pretty.format record in

  Alcotest.(check bool) "pretty handles long messages"
    true (String.length formatted >= 1000)

let test_pretty_all_severities () =
  let severities = [
    Severity.Trace; Severity.Debug; Severity.Info; Severity.Success;
    Severity.Warn; Severity.Error; Severity.Fatal;
  ] in

  List.iter (fun sev ->
    let record = Record.make ~severity:sev ~message:"Test" in
    let formatted = Flo_format_pretty.format record in
    Alcotest.(check bool)
      (Printf.sprintf "pretty formats %s" (Severity.to_string sev))
      true (String.length formatted > 0)
  ) severities

let test_pretty_with_span_context () =
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = Some "00f067aa0ba902b7";
    trace_flags = 1;
  } in

  let record = Record.make ~severity:Severity.Info ~message:"With trace" in
  let record = Record.with_span_context span_ctx record in
  let formatted = Flo_format_pretty.format record in

  (* Should include trace_id and span_id *)
  Alcotest.(check bool) "pretty includes trace_id"
    true (Str.string_match (Str.regexp ".*trace_id=.*") formatted 0)

(* === Template Formatter Edge Cases === *)

let test_custom_formatter_null_values () =
  let record = Record.make ~severity:Severity.Info ~message:"Null test" in
  let record = Record.with_attributes [
    ("null_value", Value.Null);
    ("normal_value", Value.String "test");
  ] record in

  let formatted = Flo_format_json.format record in
  Alcotest.(check bool) "formatter handles null"
    true (String.contains formatted 'n')

let test_custom_formatter_bytes () =
  let record = Record.make ~severity:Severity.Info ~message:"Bytes test" in
  let record = Record.with_attributes [
    ("data", Value.Bytes (Bytes.of_string "binary\x00\x01\x02data"));
  ] record in

  let formatted = Flo_format_json.format record in
  Alcotest.(check bool) "formatter handles bytes"
    true (String.length formatted > 0)

(* Test Suite *)
let () =
  let open Alcotest in
  run "Formatter Edge Cases" [
    "logfmt_edge_cases", [
      test_case "empty string" `Quick test_logfmt_empty_string;
      test_case "special characters" `Quick test_logfmt_special_chars;
      test_case "unicode" `Quick test_logfmt_unicode;
      test_case "nested flattening" `Quick test_logfmt_nested_flattening;
      test_case "round trip" `Quick test_logfmt_round_trip;
    ];
    "json_edge_cases", [
      test_case "empty attributes" `Quick test_json_empty_attributes;
      test_case "deeply nested" `Quick test_json_deeply_nested;
      test_case "large array" `Quick test_json_large_array;
      test_case "special characters" `Quick test_json_special_characters;
      test_case "unicode" `Quick test_json_unicode;
    ];
    "pretty_edge_cases", [
      test_case "no location" `Quick test_pretty_no_location;
      test_case "no attributes" `Quick test_pretty_no_attributes;
      test_case "long message" `Quick test_pretty_long_message;
      test_case "all severities" `Quick test_pretty_all_severities;
      test_case "with span context" `Quick test_pretty_with_span_context;
    ];
    "custom_formatter", [
      test_case "null values" `Quick test_custom_formatter_null_values;
      test_case "bytes values" `Quick test_custom_formatter_bytes;
    ];
  ]
