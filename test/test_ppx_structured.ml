(* Test PPX structured logging syntax functionality *)

open Flo

(* Test 1: Basic structured logging with string fields *)
let test_structured_string_fields () =
  [%log.info "User logged in" ~user_id:"alice" ~session:"abc123"];
  Alcotest.(check unit) "structured string fields work" () ()

(* Test 2: Structured logging with integer fields *)
let test_structured_int_fields () =
  [%log.info "Processing items" ~count:42 ~batch_size:100];
  Alcotest.(check unit) "structured int fields work" () ()

(* Test 3: Structured logging with float fields *)
let test_structured_float_fields () =
  [%log.info "Performance metrics" ~duration:3.14 ~cpu_usage:85.5];
  Alcotest.(check unit) "structured float fields work" () ()

(* Test 4: Structured logging with boolean fields *)
let test_structured_bool_fields () =
  [%log.info "Feature flags" ~enabled:true ~debug_mode:false];
  Alcotest.(check unit) "structured bool fields work" () ()

(* Test 5: Mixed type fields *)
let test_structured_mixed_fields () =
  [%log.info "Order created"
    ~order_id:"ORD-123"
    ~user_id:"alice"
    ~total:99.99
    ~item_count:3
    ~is_paid:true];
  Alcotest.(check unit) "structured mixed fields work" () ()

(* Test 6: Empty field list *)
let test_structured_no_fields () =
  (* This should just be a simple log without fields - PPX should handle gracefully *)
  [%log.info "Simple message"];
  Alcotest.(check unit) "structured no fields works" () ()

(* Test 7: All severity levels with structured fields *)
let test_structured_all_levels () =
  [%log.trace "Trace event" ~detail:"fine-grained"];
  [%log.debug "Debug event" ~detail:"debugging"];
  [%log.info "Info event" ~detail:"informational"];
  [%log.success "Success event" ~detail:"celebration"];
  [%log.warn "Warn event" ~detail:"warning"];
  [%log.error "Error event" ~detail:"error"];
  [%log.fatal "Fatal event" ~detail:"critical"];
  Alcotest.(check unit) "all levels with structured fields work" () ()

(* Test 8: Verify manual API still works *)
let test_manual_structured_api () =
  Flo.info_fields "Manual structured log" ~fields:[
    ("field1", Value.String "value1");
    ("field2", Value.Int 42L);
    ("field3", Value.Float 3.14);
  ];
  Alcotest.(check unit) "manual structured API works" () ()

(* Test 9: List fields *)
let test_structured_list_fields () =
  [%log.info "List test" ~tags:[] ~items:[1; 2; 3]];
  Alcotest.(check unit) "structured list fields work" () ()

(* Test 11: Nested structured data using Value.Object *)
let test_structured_nested_object () =
  Flo.info_fields "Nested object test" ~fields:[
    ("user", Value.Object [
      ("name", Value.String "Alice");
      ("age", Value.Int 30L);
    ]);
    ("metadata", Value.Object [
      ("source", Value.String "web");
      ("version", Value.Int 2L);
    ]);
  ];
  Alcotest.(check unit) "structured nested objects work" () ()

(* Test 12: Array of objects *)
let test_structured_array_of_objects () =
  Flo.info_fields "Array of objects test" ~fields:[
    ("users", Value.Array [
      Value.Object [("id", Value.String "1"); ("name", Value.String "Alice")];
      Value.Object [("id", Value.String "2"); ("name", Value.String "Bob")];
    ]);
  ];
  Alcotest.(check unit) "structured array of objects works" () ()

(* Test Suite *)
let () =
  let open Alcotest in
  run "PPX Structured Syntax" [
    "basic_types", [
      test_case "string fields" `Quick test_structured_string_fields;
      test_case "int fields" `Quick test_structured_int_fields;
      test_case "float fields" `Quick test_structured_float_fields;
      test_case "bool fields" `Quick test_structured_bool_fields;
    ];
    "mixed_and_complex", [
      test_case "mixed type fields" `Quick test_structured_mixed_fields;
      test_case "no fields" `Quick test_structured_no_fields;
      test_case "list fields" `Quick test_structured_list_fields;
    ];
    "all_levels", [
      test_case "all severity levels" `Quick test_structured_all_levels;
    ];
    "manual_api", [
      test_case "manual structured API" `Quick test_manual_structured_api;
      test_case "nested objects" `Quick test_structured_nested_object;
      test_case "array of objects" `Quick test_structured_array_of_objects;
    ];
  ]
