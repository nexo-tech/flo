(* Tests for Flo_structured module *)

open Flo_structured

(* Test type-safe context keys *)
let test_create_key () =
  let key = create_key "test_key" in
  Alcotest.(check string) "key name" "test_key" (key_name key)

let test_common_keys () =
  Alcotest.(check string) "user_id_key" "user_id" (key_name user_id_key);
  Alcotest.(check string) "request_id_key" "request_id" (key_name request_id_key);
  Alcotest.(check string) "trace_id_key" "trace_id" (key_name trace_id_key);
  Alcotest.(check string) "session_id_key" "session_id" (key_name session_id_key)

let test_add_get () =
  Eio_main.run @@ fun _env ->
  (* Create a context to work in *)
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* Initially no value *)
    Alcotest.(check (option string)) "no value initially"
      None (get user_id_key);

    (* Add a value *)
    add user_id_key "alice";

    (* Get returns the value *)
    Alcotest.(check (option string)) "value added"
      (Some "alice") (get user_id_key);

    (* Add another value with different key *)
    add request_id_key "req-123";

    (* Both values present *)
    Alcotest.(check (option string)) "first value still present"
      (Some "alice") (get user_id_key);
    Alcotest.(check (option string)) "second value present"
      (Some "req-123") (get request_id_key)
  )

let test_with_binding () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* No value initially *)
    Alcotest.(check (option string)) "no value before binding"
      None (get session_id_key);

    (* Inside with_binding, value is present *)
    let result = with_binding session_id_key "session-999" (fun () ->
      Alcotest.(check (option string)) "value in scope"
        (Some "session-999") (get session_id_key);
      42
    ) in

    (* Function result is returned *)
    Alcotest.(check int) "function result" 42 result;

    (* After with_binding, value is no longer in context *)
    Alcotest.(check (option string)) "no value after binding"
      None (get session_id_key)
  )

let test_nested_bindings () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    with_binding user_id_key "alice" (fun () ->
      (* Outer binding *)
      Alcotest.(check (option string)) "outer binding"
        (Some "alice") (get user_id_key);

      (* Nested binding with different key *)
      with_binding request_id_key "req-123" (fun () ->
        (* Both bindings present *)
        Alcotest.(check (option string)) "outer still present"
          (Some "alice") (get user_id_key);
        Alcotest.(check (option string)) "inner present"
          (Some "req-123") (get request_id_key)
      );

      (* After inner scope, only outer binding present *)
      Alcotest.(check (option string)) "outer still present after inner"
        (Some "alice") (get user_id_key);
      Alcotest.(check (option string)) "inner no longer present"
        None (get request_id_key)
    )
  )

(* Test span management *)
let test_start_span () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    let span = start_span "test_span" () in

    (* Span has required fields *)
    Alcotest.(check string) "span name" "test_span" (span_name span);
    Alcotest.(check bool) "trace_id not empty"
      true (String.length (span_trace_id span) > 0);
    Alcotest.(check bool) "span_id not empty"
      true (String.length (span_id span) > 0)
  )

let test_start_span_with_attributes () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    let attrs = [("key1", Value.String "value1"); ("key2", Value.Int 42L)] in
    let span = start_span "test_span" ~attributes:attrs () in

    Alcotest.(check string) "span name" "test_span" (span_name span)
  )

let test_span_parent_child () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    let parent_span = start_span "parent" () in
    let child_span = start_span "child" ~parent:parent_span () in

    (* Child has same trace_id as parent *)
    Alcotest.(check string) "same trace_id"
      (span_trace_id parent_span) (span_trace_id child_span);

    (* Child has different span_id *)
    Alcotest.(check bool) "different span_id"
      true (span_id parent_span <> span_id child_span)
  )

let test_in_span () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* No active span initially *)
    Alcotest.(check (option bool)) "no active span"
      None (Option.map (fun _ -> true) (current_span ()));

    (* Inside in_span, span is active *)
    let result = in_span "test_operation" (fun span ->
      (* Span is provided as argument *)
      Alcotest.(check string) "span name" "test_operation" (span_name span);

      (* Span is also in context *)
      Alcotest.(check (option bool)) "span in context"
        (Some true) (Option.map (fun _ -> true) (current_span ()));

      (* Return a value *)
      99
    ) in

    (* Function result is returned *)
    Alcotest.(check int) "function result" 99 result;

    (* After in_span, no active span *)
    Alcotest.(check (option bool)) "no active span after"
      None (Option.map (fun _ -> true) (current_span ()))
  )

let test_nested_spans () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    in_span "outer" (fun outer_span ->
      let outer_trace = span_trace_id outer_span in

      (* Nested span *)
      in_span "inner" (fun inner_span ->
        let inner_trace = span_trace_id inner_span in

        (* Same trace_id *)
        Alcotest.(check string) "same trace in nested"
          outer_trace inner_trace;

        (* Different span_id *)
        Alcotest.(check bool) "different span_id in nested"
          true (span_id outer_span <> span_id inner_span)
      )
    )
  )

(* Test structured event logging *)
module Test_Event = struct
  type t = {
    message : string;
    count : int;
  }

  let to_value t =
    Value.Object [
      ("message", Value.String t.message);
      ("count", Value.Int (Int64.of_int t.count));
    ]

  let event_name = "test.event"
  let severity = Severity.Info
end

let test_log_event () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* This should not crash *)
    log_event (module Test_Event) {
      message = "test message";
      count = 42;
    };

    (* Test passes if no exception *)
    Alcotest.(check bool) "log_event succeeds" true true
  )

let test_log_event_with_context () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* Add context *)
    add user_id_key "alice";
    add request_id_key "req-456";

    (* Log event with context *)
    log_event (module Test_Event) {
      message = "with context";
      count = 99;
    };

    Alcotest.(check bool) "log_event with context succeeds" true true
  )

let test_log_event_with_span () =
  Eio_main.run @@ fun _env ->
  let ctx = Flo_context.empty in
  Flo_context.with_context ctx (fun () ->
    (* Log event inside a span *)
    in_span "test_span" (fun _span ->
      log_event (module Test_Event) {
        message = "with span";
        count = 123;
      }
    );

    Alcotest.(check bool) "log_event with span succeeds" true true
  )

(* Test suite *)
let () =
  Alcotest.run "Flo_structured" [
    "type_safe_keys", [
      Alcotest.test_case "create_key" `Quick test_create_key;
      Alcotest.test_case "common_keys" `Quick test_common_keys;
      Alcotest.test_case "add_get" `Quick test_add_get;
      Alcotest.test_case "with_binding" `Quick test_with_binding;
      Alcotest.test_case "nested_bindings" `Quick test_nested_bindings;
    ];
    "span_management", [
      Alcotest.test_case "start_span" `Quick test_start_span;
      Alcotest.test_case "start_span_with_attributes" `Quick test_start_span_with_attributes;
      Alcotest.test_case "span_parent_child" `Quick test_span_parent_child;
      Alcotest.test_case "in_span" `Quick test_in_span;
      Alcotest.test_case "nested_spans" `Quick test_nested_spans;
    ];
    "structured_events", [
      Alcotest.test_case "log_event" `Quick test_log_event;
      Alcotest.test_case "log_event_with_context" `Quick test_log_event_with_context;
      Alcotest.test_case "log_event_with_span" `Quick test_log_event_with_span;
    ];
  ]
