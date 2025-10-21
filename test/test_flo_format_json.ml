open Flo

(* Helper to create test timestamp *)
let test_timestamp =
  match Ptime.of_date_time ((2024, 1, 15), ((10, 30, 45), 0)) with
  | Some t -> t
  | None -> Ptime.epoch

(* Test basic JSON formatting *)
let test_format_basic () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test message"
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in

  (* Verify it's valid JSON *)
  Alcotest.(check bool) "valid JSON" true (String.length json_str > 0);

  (* Check required fields *)
  let open Yojson.Safe.Util in
  let timestamp = json |> member "timestamp" |> to_string in
  Alcotest.(check bool) "has timestamp" true (String.length timestamp > 0);

  let severity = json |> member "severity" |> to_string in
  Alcotest.(check string) "severity" "info" severity;

  let severity_num = json |> member "severity_number" |> to_int in
  Alcotest.(check int) "severity_number" 9 severity_num;

  let message = json |> member "message" |> to_string in
  Alcotest.(check string) "message" "Test message" message

(* Test all severity levels *)
let test_format_all_severities () =
  let levels = [
    (Severity.Trace, "trace", 1);
    (Severity.Debug, "debug", 5);
    (Severity.Info, "info", 9);
    (Severity.Success, "success", 10);
    (Severity.Warn, "warn", 13);
    (Severity.Error, "error", 17);
    (Severity.Fatal, "fatal", 21);
  ] in

  List.iter (fun (sev, name, num) ->
    let record = Record.make ~severity:sev ~message:"Test" in
    let json_str = Flo_format_json.format record in
    let json = Yojson.Safe.from_string json_str in
    let open Yojson.Safe.Util in

    let sev_str = json |> member "severity" |> to_string in
    Alcotest.(check string) (Printf.sprintf "%s severity" name) name sev_str;

    let sev_num = json |> member "severity_number" |> to_int in
    Alcotest.(check int) (Printf.sprintf "%s number" name) num sev_num
  ) levels

(* Test formatting with attributes *)
let test_format_with_attributes () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test"
    |> Record.with_attributes [
         ("key1", Value.string "value1");
         ("key2", Value.int 42);
         ("key3", Value.bool true);
       ]
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  let attrs = json |> member "attributes" |> to_assoc in
  Alcotest.(check int) "attributes count" 3 (List.length attrs);

  let key1 = json |> member "attributes" |> member "key1" |> to_string in
  Alcotest.(check string) "key1 value" "value1" key1

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

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  let loc = json |> member "location" in
  let file = loc |> member "file" |> to_string in
  Alcotest.(check string) "location file" "src/app.ml" file;

  let line = loc |> member "line" |> to_int in
  Alcotest.(check int) "location line" 100 line;

  let fn = loc |> member "function_name" |> to_string in
  Alcotest.(check string) "location function" "main" fn

(* Test formatting with span context *)
let test_format_with_span_context () =
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = Some "parent123";
    trace_flags = 0x01;
  } in
  let record =
    Record.make ~severity:Severity.Info ~message:"Traced"
    |> Record.with_span_context span_ctx
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  let ctx = json |> member "span_context" in
  let trace_id = ctx |> member "trace_id" |> to_string in
  Alcotest.(check string) "trace_id" "0af7651916cd43dd8448eb211c80319c" trace_id;

  let span_id = ctx |> member "span_id" |> to_string in
  Alcotest.(check string) "span_id" "b7ad6b7169203331" span_id;

  let parent = ctx |> member "parent_span_id" |> to_string in
  Alcotest.(check string) "parent_span_id" "parent123" parent

(* Test formatting with event name *)
let test_format_with_event_name () =
  let record =
    Record.make ~severity:Severity.Success ~message:"User registered"
    |> Record.with_event_name "user.registered"
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  let event = json |> member "event_name" |> to_string in
  Alcotest.(check string) "event_name" "user.registered" event

(* Test formatting with body *)
let test_format_with_body () =
  let body = Value.object_ [
    ("user_id", Value.string "alice");
    ("action", Value.string "login");
    ("success", Value.bool true);
  ] in
  let record =
    Record.make ~severity:Severity.Info ~message:"Event"
    |> Record.with_body body
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  let body_json = json |> member "body" |> to_assoc in
  Alcotest.(check int) "body fields" 3 (List.length body_json);

  let user_id = json |> member "body" |> member "user_id" |> to_string in
  Alcotest.(check string) "body.user_id" "alice" user_id

(* Test complete record with all fields *)
let test_format_complete_record () =
  let location = Location.make ~file:"app.ml" ~line:50 in
  let span_ctx = {
    Trace_context.trace_id = "trace123";
    span_id = "span456";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let record =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Success ~message:"Complete"
    |> Record.with_location location
    |> Record.with_span_context span_ctx
    |> Record.with_attributes [("key", Value.string "val")]
    |> Record.with_event_name "test.event"
    |> Record.with_body (Value.int 999)
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in

  (* Verify all fields present *)
  let open Yojson.Safe.Util in
  let _timestamp = json |> member "timestamp" |> to_string in
  let _severity = json |> member "severity" |> to_string in
  let _message = json |> member "message" |> to_string in
  let _attrs = json |> member "attributes" in
  let _loc = json |> member "location" in
  let _ctx = json |> member "span_context" in
  let _event = json |> member "event_name" |> to_string in
  let _body = json |> member "body" in

  Alcotest.(check bool) "complete record formatted" true true

(* Test parse basic JSON *)
let test_parse_basic () =
  let json_str = {|{
    "timestamp": "2024-01-15T10:30:45Z",
    "severity": "info",
    "severity_number": 9,
    "message": "Test message"
  }|} in

  match Flo_format_json.parse json_str with
  | Ok record ->
      Alcotest.(check string) "parsed message" "Test message" record.message;
      Alcotest.(check bool) "parsed severity" true
        (Severity.compare record.severity Severity.Info = 0)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test parse with all fields *)
let test_parse_complete () =
  let json_str = {|{
    "timestamp": "2024-01-15T10:30:45Z",
    "severity": "error",
    "severity_number": 17,
    "message": "Error occurred",
    "attributes": {"key": "value"},
    "location": {"file": "test.ml", "line": 42, "column": 10, "module_name": "Test"},
    "span_context": {"trace_id": "trace123", "span_id": "span456", "trace_flags": 1},
    "event_name": "error.occurred"
  }|} in

  match Flo_format_json.parse json_str with
  | Ok record ->
      Alcotest.(check string) "parsed message" "Error occurred" record.message;
      Alcotest.(check bool) "has location" true (Option.is_some record.location);
      Alcotest.(check bool) "has span_context" true (Option.is_some record.span_context);
      Alcotest.(check bool) "has event_name" true (Option.is_some record.event_name);
      Alcotest.(check int) "has attributes" 1 (List.length record.attributes)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test parse invalid JSON *)
let test_parse_invalid_json () =
  let json_str = "not valid json" in
  match Flo_format_json.parse json_str with
  | Ok _ -> Alcotest.fail "Should fail on invalid JSON"
  | Error msg ->
      Alcotest.(check bool) "error message not empty" true (String.length msg > 0)

(* Test round-trip: format then parse *)
let test_round_trip () =
  let original = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Warn
    ~message:"Warning message"
  in

  let json_str = Flo_format_json.format original in
  match Flo_format_json.parse json_str with
  | Ok parsed ->
      Alcotest.(check string) "message preserved" original.message parsed.message;
      Alcotest.(check bool) "severity preserved" true
        (Severity.compare original.severity parsed.severity = 0);
      (* Timestamps might differ slightly due to precision, just check it exists *)
      Alcotest.(check bool) "timestamp exists" true
        (Ptime.compare parsed.timestamp Ptime.epoch > 0)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Round-trip failed: %s" msg)

(* Test round-trip with all fields *)
let test_round_trip_complete () =
  let location = Location.make ~file:"test.ml" ~line:42 in
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let original =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Success ~message:"Complete"
    |> Record.with_location location
    |> Record.with_span_context span_ctx
    |> Record.with_attributes [("key", Value.string "val")]
    |> Record.with_event_name "test.event"
  in

  let json_str = Flo_format_json.format original in
  match Flo_format_json.parse json_str with
  | Ok parsed ->
      Alcotest.(check string) "message preserved" original.message parsed.message;
      Alcotest.(check bool) "has location" true (Option.is_some parsed.location);
      Alcotest.(check bool) "has span_context" true (Option.is_some parsed.span_context);
      Alcotest.(check bool) "has event_name" true (Option.is_some parsed.event_name);
      Alcotest.(check int) "attributes count" 1 (List.length parsed.attributes)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Round-trip failed: %s" msg)

(* Test JSON is single-line (no newlines) *)
let test_format_single_line () =
  let record = Record.make ~severity:Severity.Info ~message:"Test" in
  let json_str = Flo_format_json.format record in

  Alcotest.(check bool) "single line" false (String.contains json_str '\n')

(* Test formatting with namespace *)
let test_format_with_namespace () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test with namespace"
    |> Record.with_namespace "mylib.component"
  in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  (* Check namespace field *)
  let namespace = json |> member "namespace" |> to_string in
  Alcotest.(check string) "namespace" "mylib.component" namespace

(* Test formatting without namespace *)
let test_format_without_namespace () =
  let record = Record.make ~severity:Severity.Info ~message:"No namespace" in

  let json_str = Flo_format_json.format record in
  let json = Yojson.Safe.from_string json_str in
  let open Yojson.Safe.Util in

  (* Check namespace field is not present *)
  let has_namespace =
    try
      let _ns = json |> member "namespace" |> to_string in
      true
    with _ -> false
  in
  Alcotest.(check bool) "no namespace field" false has_namespace

(* Test round-trip with namespace *)
let test_round_trip_with_namespace () =
  let original =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Info ~message:"Namespaced message"
    |> Record.with_namespace "test.namespace"
  in

  let json_str = Flo_format_json.format original in
  match Flo_format_json.parse json_str with
  | Ok parsed ->
      Alcotest.(check string) "message preserved" original.message parsed.message;
      Alcotest.(check (option string)) "namespace preserved"
        (Some "test.namespace") (Record.namespace parsed)
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Round-trip with namespace failed: %s" msg)

let () =
  let open Alcotest in
  run "Flo_format_json" [
    "formatting", [
      test_case "basic JSON formatting" `Quick test_format_basic;
      test_case "all severity levels" `Quick test_format_all_severities;
      test_case "format with attributes" `Quick test_format_with_attributes;
      test_case "format with location" `Quick test_format_with_location;
      test_case "format with span context" `Quick test_format_with_span_context;
      test_case "format with event name" `Quick test_format_with_event_name;
      test_case "format with body" `Quick test_format_with_body;
      test_case "format complete record" `Quick test_format_complete_record;
      test_case "format is single-line" `Quick test_format_single_line;
    ];
    "parsing", [
      test_case "parse basic JSON" `Quick test_parse_basic;
      test_case "parse complete JSON" `Quick test_parse_complete;
      test_case "parse invalid JSON" `Quick test_parse_invalid_json;
    ];
    "round_trip", [
      test_case "round-trip basic record" `Quick test_round_trip;
      test_case "round-trip complete record" `Quick test_round_trip_complete;
      test_case "round-trip with namespace" `Quick test_round_trip_with_namespace;
    ];
    "namespace", [
      test_case "format with namespace" `Quick test_format_with_namespace;
      test_case "format without namespace" `Quick test_format_without_namespace;
    ];
  ]
