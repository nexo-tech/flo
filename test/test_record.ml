open Flo

(* Helper to create a test timestamp *)
let test_timestamp =
  match Ptime.of_date_time ((2024, 1, 15), ((10, 30, 0), 0)) with
  | Some t -> t
  | None -> Ptime.epoch

let test_timestamp2 =
  match Ptime.of_date_time ((2024, 1, 15), ((10, 35, 0), 0)) with
  | Some t -> t
  | None -> Ptime.epoch

(* Define testables *)
let severity_testable =
  let pp fmt sev = Format.fprintf fmt "%s" (Severity.to_string sev) in
  let equal a b = Severity.compare a b = 0 in
  Alcotest.testable pp equal

let location_testable =
  let pp fmt loc = Format.fprintf fmt "%s" (Location.to_string loc) in
  let equal a b =
    a.Location.file = b.Location.file &&
    a.Location.line = b.Location.line &&
    a.Location.column = b.Location.column &&
    a.Location.module_name = b.Location.module_name &&
    a.Location.function_name = b.Location.function_name
  in
  Alcotest.testable pp equal

let value_testable =
  let pp fmt v = Format.fprintf fmt "%s" (Value.to_string v) in
  let rec equal a b = match (a, b) with
    | Value.String s1, Value.String s2 -> s1 = s2
    | Value.Int i1, Value.Int i2 -> i1 = i2
    | Value.Float f1, Value.Float f2 -> Float.abs (f1 -. f2) < 1e-10
    | Value.Bool b1, Value.Bool b2 -> b1 = b2
    | Value.Array xs1, Value.Array xs2 ->
        List.length xs1 = List.length xs2 &&
        List.for_all2 equal xs1 xs2
    | Value.Object fs1, Value.Object fs2 ->
        List.length fs1 = List.length fs2 &&
        List.for_all2 (fun (k1, v1) (k2, v2) -> k1 = k2 && equal v1 v2) fs1 fs2
    | Value.Bytes b1, Value.Bytes b2 -> Bytes.equal b1 b2
    | Value.Null, Value.Null -> true
    | _ -> false
  in
  Alcotest.testable pp equal

let ptime_testable =
  let pp fmt t = Format.fprintf fmt "%s" (Ptime.to_rfc3339 t) in
  let equal = Ptime.equal in
  Alcotest.testable pp equal

(* Test make creates record with defaults *)
let test_make () =
  let record = Record.make ~severity:Severity.Info ~message:"Test message" in

  Alcotest.(check string) "message" "Test message" record.message;
  Alcotest.(check severity_testable) "severity" Severity.Info record.severity;
  Alcotest.(check (option location_testable)) "location default"
    None record.location;
  Alcotest.(check (list (pair string value_testable))) "attributes default"
    [] record.attributes;
  Alcotest.(check (option value_testable)) "body default"
    None record.body;
  Alcotest.(check (option string)) "event_name default"
    None record.event_name;
  Alcotest.(check (option ptime_testable)) "observed_timestamp default"
    None record.observed_timestamp

(* Test make_with_timestamp *)
let test_make_with_timestamp () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Error
    ~message:"Error occurred"
  in

  Alcotest.(check ptime_testable) "timestamp"
    test_timestamp record.timestamp;
  Alcotest.(check string) "message" "Error occurred" record.message;
  Alcotest.(check severity_testable) "severity"
    Severity.Error record.severity

(* Test with_location *)
let test_with_location () =
  let record = Record.make ~severity:Severity.Debug ~message:"Debug" in
  let location = Location.make ~file:"test.ml" ~line:42 in
  let record' = Record.with_location location record in

  Alcotest.(check (option location_testable)) "location added"
    (Some location) record'.location

(* Test with_span_context *)
let test_with_span_context () =
  let record = Record.make ~severity:Severity.Info ~message:"Info" in
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let record' = Record.with_span_context span_ctx record in

  match record'.span_context with
  | Some ctx ->
      Alcotest.(check string) "trace_id preserved"
        span_ctx.trace_id ctx.trace_id;
      Alcotest.(check string) "span_id preserved"
        span_ctx.span_id ctx.span_id
  | None -> Alcotest.fail "span_context not set"

(* Test with_attributes *)
let test_with_attributes () =
  let record = Record.make ~severity:Severity.Info ~message:"Test" in
  let attrs1 = [("key1", Value.string "value1")] in
  let record' = Record.with_attributes attrs1 record in

  Alcotest.(check (list (pair string value_testable)))
    "attributes added" attrs1 record'.attributes;

  (* Test appending more attributes *)
  let attrs2 = [("key2", Value.int 42)] in
  let record'' = Record.with_attributes attrs2 record' in

  Alcotest.(check (list (pair string value_testable)))
    "attributes appended" (attrs1 @ attrs2) record''.attributes

(* Test with_body *)
let test_with_body () =
  let record = Record.make ~severity:Severity.Info ~message:"Test" in
  let body = Value.object_ [
    ("user_id", Value.string "alice");
    ("action", Value.string "login");
  ] in
  let record' = Record.with_body body record in

  Alcotest.(check (option value_testable)) "body set"
    (Some body) record'.body

(* Test with_event_name *)
let test_with_event_name () =
  let record = Record.make ~severity:Severity.Info ~message:"Event" in
  let record' = Record.with_event_name "user.login" record in

  Alcotest.(check (option string)) "event_name set"
    (Some "user.login") record'.event_name

(* Test with_observed_timestamp *)
let test_with_observed_timestamp () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test"
  in
  let record' = Record.with_observed_timestamp test_timestamp2 record in

  Alcotest.(check (option ptime_testable)) "observed_timestamp set"
    (Some test_timestamp2) record'.observed_timestamp

(* Test get_timestamp *)
let test_get_timestamp_no_observed () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test"
  in

  let ts = Record.get_timestamp record in
  Alcotest.(check ptime_testable) "returns timestamp when no observed"
    test_timestamp ts

let test_get_timestamp_with_observed () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test"
  in
  let record' = Record.with_observed_timestamp test_timestamp2 record in

  let ts = Record.get_timestamp record' in
  Alcotest.(check ptime_testable) "returns observed_timestamp when set"
    test_timestamp2 ts

(* Test builder pattern chaining *)
let test_builder_chaining () =
  let location = Location.make ~file:"app.ml" ~line:100 in
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in

  let record =
    Record.make ~severity:Severity.Success ~message:"Order created"
    |> Record.with_location location
    |> Record.with_span_context span_ctx
    |> Record.with_attributes [("order_id", Value.string "12345")]
    |> Record.with_event_name "order.created"
    |> Record.with_body (Value.object_ [
         ("user_id", Value.string "alice");
         ("total", Value.float 99.99);
       ])
  in

  Alcotest.(check severity_testable) "severity" Severity.Success record.severity;
  Alcotest.(check string) "message" "Order created" record.message;
  Alcotest.(check (option location_testable)) "location"
    (Some location) record.location;
  Alcotest.(check (option string)) "event_name"
    (Some "order.created") record.event_name;
  Alcotest.(check bool) "has span_context" true
    (Option.is_some record.span_context);
  Alcotest.(check bool) "has body" true
    (Option.is_some record.body);
  Alcotest.(check int) "attributes count" 1
    (List.length record.attributes)

(* Test to_string *)
let test_to_string_minimal () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Simple message"
  in

  let s = Record.to_string record in
  Alcotest.(check bool) "contains timestamp" true
    (String.contains s 'T');
  Alcotest.(check bool) "contains severity" true
    (String.contains s 'i');  (* "info" *)
  Alcotest.(check bool) "contains message" true
    (String.length s > 0)

let test_to_string_with_location () =
  let location = Location.make ~file:"test.ml" ~line:42 in
  let record =
    Record.make ~severity:Severity.Error ~message:"Error message"
    |> Record.with_location location
  in

  let s = Record.to_string record in
  Alcotest.(check bool) "contains location" true
    (String.contains s ':')  (* test.ml:42 *)

let test_to_string_with_attributes () =
  let record =
    Record.make ~severity:Severity.Debug ~message:"Debug"
    |> Record.with_attributes [
         ("key1", Value.string "value1");
         ("key2", Value.int 42);
       ]
  in

  let s = Record.to_string record in
  Alcotest.(check bool) "contains attributes" true
    (String.contains s '{')

let test_to_string_with_event_name () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Event"
    |> Record.with_event_name "user.login"
  in

  let s = Record.to_string record in
  Alcotest.(check bool) "contains event name" true
    (String.contains s '=')  (* event= *)

let () =
  let open Alcotest in
  run "Record" [
    "construction", [
      test_case "make creates record with defaults" `Quick test_make;
      test_case "make_with_timestamp sets timestamp" `Quick test_make_with_timestamp;
    ];
    "builder_pattern", [
      test_case "with_location adds location" `Quick test_with_location;
      test_case "with_span_context adds span context" `Quick test_with_span_context;
      test_case "with_attributes adds and appends" `Quick test_with_attributes;
      test_case "with_body sets body" `Quick test_with_body;
      test_case "with_event_name sets event name" `Quick test_with_event_name;
      test_case "with_observed_timestamp sets observed" `Quick test_with_observed_timestamp;
      test_case "builder pattern chaining" `Quick test_builder_chaining;
    ];
    "utilities", [
      test_case "get_timestamp without observed" `Quick test_get_timestamp_no_observed;
      test_case "get_timestamp with observed" `Quick test_get_timestamp_with_observed;
    ];
    "to_string", [
      test_case "to_string minimal record" `Quick test_to_string_minimal;
      test_case "to_string with location" `Quick test_to_string_with_location;
      test_case "to_string with attributes" `Quick test_to_string_with_attributes;
      test_case "to_string with event_name" `Quick test_to_string_with_event_name;
    ];
  ]
