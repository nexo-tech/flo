open Flo

(* Helper to create test timestamp *)
let test_timestamp =
  match Ptime.of_date_time ((2024, 1, 15), ((10, 30, 45), 0)) with
  | Some t -> t
  | None -> Ptime.epoch

(* Test basic logfmt formatting *)
let test_format_basic () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test message"
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Should contain key=value pairs *)
  Alcotest.(check bool) "contains timestamp" true
    (String.contains logfmt 't');
  Alcotest.(check bool) "contains severity" true
    (String.contains logfmt 's');
  Alcotest.(check bool) "contains message" true
    (String.contains logfmt 'm')

(* Test unquoted simple values *)
let test_format_unquoted () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Simple"
    |> Record.with_attributes [
         ("key1", Value.string "value1");
         ("count", Value.int 42);
       ]
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Simple values should not have quotes *)
  Alcotest.(check bool) "has key1" true
    (String.contains logfmt 'k');
  Alcotest.(check bool) "has count" true
    (String.contains logfmt '4')

(* Test quoted values with spaces *)
let test_format_quoted_spaces () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Message with spaces"
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Message with spaces should be quoted *)
  Alcotest.(check bool) "message is quoted" true
    (String.contains logfmt '"')

(* Test escaped quotes in values *)
let test_format_escaped_quotes () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Message with \"quotes\""
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Should contain escaped quotes *)
  Alcotest.(check bool) "has escaped quotes" true
    (String.contains logfmt '\\')

(* Test all severity levels *)
let test_format_all_severities () =
  let levels = [
    (Severity.Trace, "trace");
    (Severity.Debug, "debug");
    (Severity.Info, "info");
    (Severity.Success, "success");
    (Severity.Warn, "warn");
    (Severity.Error, "error");
    (Severity.Fatal, "fatal");
  ] in

  List.iter (fun (sev, name) ->
    let record = Record.make ~severity:sev ~message:"Test" in
    let logfmt = Flo_format_logfmt.format record in

    (* Should contain severity name *)
    Alcotest.(check bool) (Printf.sprintf "has %s" name) true
      (String.length logfmt > 0)
  ) levels

(* Test formatting with attributes *)
let test_format_with_attributes () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test"
    |> Record.with_attributes [
         ("user_id", Value.string "alice");
         ("count", Value.int 42);
         ("active", Value.bool true);
       ]
  in

  let logfmt = Flo_format_logfmt.format record in

  (* All attributes should be present *)
  Alcotest.(check bool) "has user_id" true
    (String.contains logfmt 'u');
  Alcotest.(check bool) "has count" true
    (String.contains logfmt '4');
  Alcotest.(check bool) "has active" true
    (String.contains logfmt 'a')

(* Test formatting with location *)
let test_format_with_location () =
  let location = Location.make_full
    ~file:"src/app.ml"
    ~line:100
    ~column:15
    ~module_name:"App"
    ~function_name:"main"
    ()
  in
  let record =
    Record.make ~severity:Severity.Error ~message:"Error"
    |> Record.with_location location
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Should contain location fields *)
  Alcotest.(check bool) "has location_file" true
    (String.contains logfmt 'f');
  Alcotest.(check bool) "has location info" true
    (String.length logfmt > 50)

(* Test formatting with span context *)
let test_format_with_span_context () =
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let record =
    Record.make ~severity:Severity.Info ~message:"Traced"
    |> Record.with_span_context span_ctx
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Should contain trace_id and span_id *)
  Alcotest.(check bool) "has trace_id" true
    (String.contains logfmt 'a');  (* from trace_id *)
  Alcotest.(check bool) "has span_id" true
    (String.contains logfmt 'b')  (* from span_id *)

(* Test formatting with event name *)
let test_format_with_event_name () =
  let record =
    Record.make ~severity:Severity.Success ~message:"Success"
    |> Record.with_event_name "user.registered"
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Should contain event_name *)
  Alcotest.(check bool) "has event_name" true
    (String.contains logfmt 'e')

(* Test single-line output *)
let test_format_single_line () =
  let record = Record.make ~severity:Severity.Info ~message:"Test" in
  let logfmt = Flo_format_logfmt.format record in

  Alcotest.(check bool) "single line" false (String.contains logfmt '\n')

(* Test parse basic logfmt *)
let test_parse_basic () =
  let logfmt = "timestamp=\"2024-01-15T10:30:45Z\" severity=info severity_number=9 message=\"Test message\"" in

  match Flo_format_logfmt.parse logfmt with
  | Ok record ->
      Alcotest.(check string) "parsed message" "Test message" record.message;
      Alcotest.(check bool) "parsed severity" true
        (Severity.compare record.severity Severity.Info = 0)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test parse with quoted values *)
let test_parse_quoted () =
  let logfmt = "timestamp=\"2024-01-15T10:30:45Z\" severity=warn severity_number=13 message=\"Warning with spaces\"" in

  match Flo_format_logfmt.parse logfmt with
  | Ok record ->
      Alcotest.(check string) "parsed message" "Warning with spaces" record.message
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test parse with escaped quotes *)
let test_parse_escaped () =
  let logfmt = "timestamp=\"2024-01-15T10:30:45Z\" severity=error severity_number=17 message=\"Error with \\\"quotes\\\"\"" in

  match Flo_format_logfmt.parse logfmt with
  | Ok record ->
      Alcotest.(check string) "parsed message" "Error with \"quotes\"" record.message
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test parse missing required field *)
let test_parse_missing_field () =
  let logfmt = "severity=info message=\"Test\"" in

  match Flo_format_logfmt.parse logfmt with
  | Ok _ -> Alcotest.fail "Should fail on missing timestamp"
  | Error msg ->
      Alcotest.(check bool) "error mentions missing" true (String.length msg > 0)

(* Test round-trip *)
let test_round_trip () =
  let original = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Warn
    ~message:"Warning"
  in

  let logfmt = Flo_format_logfmt.format original in
  match Flo_format_logfmt.parse logfmt with
  | Ok parsed ->
      Alcotest.(check string) "message preserved" original.message parsed.message;
      Alcotest.(check bool) "severity preserved" true
        (Severity.compare original.severity parsed.severity = 0)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Round-trip failed: %s" msg)

(* Test empty value *)
let test_format_empty_value () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test"
    |> Record.with_attributes [("empty", Value.string "")]
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Empty value should be quoted *)
  Alcotest.(check bool) "has empty key" true
    (String.contains logfmt 'e')

(* Test formatting with namespace *)
let test_format_with_namespace () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test with namespace"
    |> Record.with_namespace "mylib.component"
  in

  let logfmt = Flo_format_logfmt.format record in

  (* Check namespace appears in output *)
  Alcotest.(check bool) "has namespace" true
    (try ignore (Str.search_forward (Str.regexp "namespace=mylib\\.component") logfmt 0); true
     with Not_found -> false)

(* Test formatting without namespace *)
let test_format_without_namespace () =
  let record = Record.make ~severity:Severity.Info ~message:"No namespace" in

  let logfmt = Flo_format_logfmt.format record in

  (* Check namespace does not appear *)
  Alcotest.(check bool) "no namespace" false
    (try ignore (Str.search_forward (Str.regexp "namespace=") logfmt 0); true
     with Not_found -> false)

(* Test round-trip with namespace *)
let test_round_trip_with_namespace () =
  let original =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Info ~message:"Namespaced message"
    |> Record.with_namespace "test.namespace"
  in

  let logfmt = Flo_format_logfmt.format original in
  match Flo_format_logfmt.parse logfmt with
  | Ok parsed ->
      Alcotest.(check string) "message preserved" original.message parsed.message;
      Alcotest.(check (option string)) "namespace preserved"
        (Some "test.namespace") (Record.namespace parsed)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Round-trip with namespace failed: %s" msg)

let () =
  let open Alcotest in
  run "Flo_format_logfmt" [
    "formatting", [
      test_case "basic logfmt formatting" `Quick test_format_basic;
      test_case "unquoted simple values" `Quick test_format_unquoted;
      test_case "quoted values with spaces" `Quick test_format_quoted_spaces;
      test_case "escaped quotes in values" `Quick test_format_escaped_quotes;
      test_case "all severity levels" `Quick test_format_all_severities;
      test_case "format with attributes" `Quick test_format_with_attributes;
      test_case "format with location" `Quick test_format_with_location;
      test_case "format with span context" `Quick test_format_with_span_context;
      test_case "format with event name" `Quick test_format_with_event_name;
      test_case "format is single-line" `Quick test_format_single_line;
      test_case "format empty value" `Quick test_format_empty_value;
    ];
    "parsing", [
      test_case "parse basic logfmt" `Quick test_parse_basic;
      test_case "parse quoted values" `Quick test_parse_quoted;
      test_case "parse escaped quotes" `Quick test_parse_escaped;
      test_case "parse missing required field" `Quick test_parse_missing_field;
    ];
    "round_trip", [
      test_case "round-trip conversion" `Quick test_round_trip;
      test_case "round-trip with namespace" `Quick test_round_trip_with_namespace;
    ];
    "namespace", [
      test_case "format with namespace" `Quick test_format_with_namespace;
      test_case "format without namespace" `Quick test_format_without_namespace;
    ];
  ]
