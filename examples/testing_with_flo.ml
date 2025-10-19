(* Testing with Flo Examples
 *
 * This example demonstrates how to test code that uses Flo logging,
 * including creating test sinks, asserting log messages, and verifying
 * structured fields.
 *)

(* Example 1: In-Memory Test Sink *)
let example_test_sink () =
  print_endline "\n=== In-Memory Test Sink ===\n";

  (* Create a simple in-memory sink for testing *)
  let captured_logs = ref [] in

  let module Test_Sink = struct
    let create () = captured_logs

    let write sink record =
      sink := record :: !sink

    let get_logs sink = List.rev !sink
  end in

  let sink = Test_Sink.create () in

  (* Simulate application code that logs *)
  let record1 = Record.make ~severity:Severity.Info ~message:"User logged in" in
  let record1 = Record.with_attributes [("user_id", Value.String "alice")] record1 in
  Test_Sink.write sink record1;

  let record2 = Record.make ~severity:Severity.Success ~message:"Order created" in
  let record2 = Record.with_attributes [
    ("order_id", Value.String "ORD-123");
    ("total", Value.Float 99.99);
  ] record2 in
  Test_Sink.write sink record2;

  (* Retrieve and inspect logs *)
  let logs = Test_Sink.get_logs sink in
  Printf.printf "Captured %d log messages:\n" (List.length logs);
  List.iter (fun r ->
    Printf.printf "  [%s] %s\n"
      (Severity.to_string r.Record.severity)
      r.Record.message
  ) logs;

  print_endline "\nTest sink allows inspection without console/file output"

(* Example 2: Asserting Log Messages in Tests *)
let example_assert_messages () =
  print_endline "\n=== Asserting Log Messages ===\n";

  let logs = ref [] in

  let test_function user_id action =
    let record = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "User %s performed %s" user_id action) in
    let record = Record.with_attributes [
      ("user_id", Value.String user_id);
      ("action", Value.String action);
    ] record in
    logs := record :: !logs
  in

  (* Run the function under test *)
  test_function "alice" "login";
  test_function "bob" "logout";

  (* Assert log messages *)
  let all_logs = List.rev !logs in

  (* Test 1: Check log count *)
  assert (List.length all_logs = 2);
  print_endline "✓ Test 1: Expected 2 log messages";

  (* Test 2: Check first message *)
  let first = List.hd all_logs in
  assert (first.Record.message = "User alice performed login");
  print_endline "✓ Test 2: First message is correct";

  (* Test 3: Check severity *)
  assert (first.Record.severity = Severity.Info);
  print_endline "✓ Test 3: Severity is INFO";

  print_endline "\nAll assertions passed!"

(* Example 3: Checking Structured Field Values *)
let example_check_fields () =
  print_endline "\n=== Checking Structured Field Values ===\n";

  let logs = ref [] in

  let log_order order_id user_id total items =
    let record = Record.make ~severity:Severity.Info ~message:"Order created" in
    let record = Record.with_attributes [
      ("order_id", Value.String order_id);
      ("user_id", Value.String user_id);
      ("total", Value.Float total);
      ("item_count", Value.Int (Int64.of_int items));
    ] record in
    logs := record :: !logs
  in

  (* Test the function *)
  log_order "ORD-123" "alice" 99.99 3;

  let record = List.hd !logs in
  let attrs = record.Record.attributes in

  (* Assert field values *)
  (match List.assoc_opt "order_id" attrs with
   | Some (Value.String oid) ->
       assert (oid = "ORD-123");
       print_endline "✓ order_id = ORD-123"
   | _ -> failwith "order_id not found or wrong type");

  (match List.assoc_opt "total" attrs with
   | Some (Value.Float total) ->
       assert (total = 99.99);
       print_endline "✓ total = 99.99"
   | _ -> failwith "total not found or wrong type");

  (match List.assoc_opt "item_count" attrs with
   | Some (Value.Int count) ->
       assert (count = 3L);
       print_endline "✓ item_count = 3"
   | _ -> failwith "item_count not found or wrong type");

  print_endline "\nAll field assertions passed!"

(* Example 4: Testing Span Relationships *)
let example_test_spans () =
  print_endline "\n=== Testing Span Relationships ===\n";

  let logs = ref [] in

  let test_with_spans () =
    (* Create a parent span *)
    let parent_span = Flo_structured.start_span "parent_operation" () in
    let parent_record = Record.make ~severity:Severity.Info ~message:"Parent span started" in
    logs := parent_record :: !logs;

    (* Create a child span *)
    let child_span = Flo_structured.start_span "child_operation" ~parent:parent_span () in
    let child_record = Record.make ~severity:Severity.Info ~message:"Child span started" in
    logs := child_record :: !logs;

    (parent_span, child_span)
  in

  let (parent, child) = test_with_spans () in

  (* Verify span relationships *)
  assert (Flo_structured.span_trace_id child = Flo_structured.span_trace_id parent);
  print_endline "✓ Child has same trace_id as parent";

  let parent_id = Flo_structured.span_id parent in
  print_endline (Printf.sprintf "✓ Parent span_id: %s" parent_id);
  print_endline (Printf.sprintf "✓ Child span_id: %s" (Flo_structured.span_id child));

  print_endline "\nSpan relationship verification complete!"

(* Example 5: Mocking for Library Testing *)
let example_library_mocking () =
  print_endline "\n=== Library Testing with Mocks ===\n";

  (* Mock sink that tracks calls *)
  let call_count = ref 0 in
  let captured = ref [] in

  let module Mock_Sink = struct
    let write record =
      incr call_count;
      captured := record :: !captured

    let assert_called_times n =
      assert (!call_count = n);
      Printf.printf "✓ Sink called %d times as expected\n" n

    let assert_contains_message msg =
      let found = List.exists (fun r -> r.Record.message = msg) !captured in
      assert found;
      Printf.printf "✓ Found message: %s\n" msg
  end in

  (* Test library function *)
  let library_func name =
    let r = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "Processing %s" name) in
    Mock_Sink.write r
  in

  (* Run tests *)
  library_func "item1";
  library_func "item2";

  Mock_Sink.assert_called_times 2;
  Mock_Sink.assert_contains_message "Processing item1";
  Mock_Sink.assert_contains_message "Processing item2";

  print_endline "\nMock sink verification complete!"

(* Example 6: Integration Testing with Logs *)
let example_integration_testing () =
  print_endline "\n=== Integration Testing ===\n";

  let logs = ref [] in

  (* Simulate a complete user workflow *)
  let user_workflow user_id =
    (* Step 1: Login *)
    let r1 = Record.make ~severity:Severity.Info ~message:"User login" in
    let r1 = Record.with_attributes [("user_id", Value.String user_id)] r1 in
    logs := r1 :: !logs;

    (* Step 2: Create order *)
    let r2 = Record.make ~severity:Severity.Info ~message:"Order created" in
    let r2 = Record.with_attributes [
      ("user_id", Value.String user_id);
      ("order_id", Value.String "ORD-001");
    ] r2 in
    logs := r2 :: !logs;

    (* Step 3: Payment *)
    let r3 = Record.make ~severity:Severity.Success ~message:"Payment processed" in
    let r3 = Record.with_attributes [
      ("user_id", Value.String user_id);
      ("order_id", Value.String "ORD-001");
      ("amount", Value.Float 99.99);
    ] r3 in
    logs := r3 :: !logs
  in

  (* Execute workflow *)
  user_workflow "alice";

  let all_logs = List.rev !logs in

  (* Verify workflow completed *)
  assert (List.length all_logs = 3);
  print_endline "✓ Workflow has 3 steps";

  (* Verify all logs have correct user_id *)
  let all_have_user = List.for_all (fun r ->
    match List.assoc_opt "user_id" r.Record.attributes with
    | Some (Value.String uid) -> uid = "alice"
    | _ -> false
  ) all_logs in
  assert all_have_user;
  print_endline "✓ All logs have user_id=alice";

  (* Verify final step is success *)
  let last = List.hd (List.rev all_logs) in
  assert (last.Record.severity = Severity.Success);
  print_endline "✓ Final step is SUCCESS";

  print_endline "\nIntegration test passed!"

(* Main *)
let () =
  print_endline "╔════════════════════════════════════════════════════════════════╗";
  print_endline "║              Flō Testing Examples                              ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝";

  example_test_sink ();
  example_assert_messages ();
  example_check_fields ();
  example_test_spans ();
  example_library_mocking ();
  example_integration_testing ();

  print_endline "\n╔════════════════════════════════════════════════════════════════╗";
  print_endline "║                   All Examples Complete!                       ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝"
