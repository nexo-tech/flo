(* Test PPX with variables (not just literals) *)

open Flo

(* Test 1: String variables *)
let test_string_variables () =
  let user_id = "alice" in
  let session = "session-123" in

  [%log.info "User logged in"
    ~user_id
    ~session];

  Alcotest.(check unit) "string variables work" () ()

(* Test 2: Integer variables *)
let test_int_variables () =
  let count = 42 in
  let batch_size = 100 in
  let remaining = 58 in

  [%log.info "Processing batch"
    ~count
    ~batch_size
    ~remaining];

  Alcotest.(check unit) "int variables work" () ()

(* Test 3: Float variables *)
let test_float_variables () =
  let duration = 123.45 in
  let cpu_usage = 85.5 in

  [%log.info "Performance metrics"
    ~duration
    ~cpu_usage];

  Alcotest.(check unit) "float variables work" () ()

(* Test 4: Boolean variables *)
let test_bool_variables () =
  let enabled = true in
  let debug_mode = false in

  [%log.info "Feature flags"
    ~enabled
    ~debug_mode];

  Alcotest.(check unit) "bool variables work" () ()

(* Test 5: Mixed variable types *)
let test_mixed_variables () =
  let user_id = "bob" in
  let order_count = 5 in
  let total_amount = 499.99 in
  let is_premium = true in

  [%log.info "Order summary"
    ~user_id
    ~order_count
    ~total_amount
    ~is_premium];

  Alcotest.(check unit) "mixed variable types work" () ()

(* Test 6: Computed values *)
let test_computed_values () =
  let items = ["a"; "b"; "c"] in
  let item_count = List.length items in

  [%log.info "Items processed"
    ~item_count];

  Alcotest.(check unit) "computed values work" () ()

(* Test 7: Function call results *)
let test_function_results () =
  let get_user_id () = "alice" in
  let get_count () = 42 in

  let user = get_user_id () in
  let count = get_count () in

  [%log.info "Function results"
    ~user
    ~count];

  Alcotest.(check unit) "function results work" () ()

(* Test 8: Mix of literals and variables *)
let test_mixed_literals_and_variables () =
  let user_id = "charlie" in
  let count = 10 in

  [%log.info "Mixed data"
    ~user_id             (* variable *)
    ~status:"active"     (* literal *)
    ~count               (* variable *)
    ~priority:1];        (* literal *)

  Alcotest.(check unit) "mixed literals and variables work" () ()

(* Test 9: Variables in all severity levels *)
let test_variables_all_levels () =
  let detail = "test-detail" in

  [%log.trace "Trace with var" ~detail];
  [%log.debug "Debug with var" ~detail];
  [%log.info "Info with var" ~detail];
  [%log.success "Success with var" ~detail];
  [%log.warn "Warn with var" ~detail];
  [%log.error "Error with var" ~detail];
  [%log.fatal "Fatal with var" ~detail];

  Alcotest.(check unit) "variables work in all levels" () ()

(* Test 10: Complex expressions *)
let test_complex_expressions () =
  let base = 20 in

  [%log.info "Complex computation"
    ~result:(base * 2 + 2)];

  Alcotest.(check unit) "complex expressions work" () ()

(* Test 11: Value.t variables (identity conversion) *)
let test_value_t_variables () =
  let custom_value = Value.Object [
    ("nested", Value.String "data");
    ("count", Value.Int 42L);
  ] in

  Flo.info_fields "Custom value" ~fields:[
    ("data", custom_value);
  ];

  Alcotest.(check unit) "Value.t variables work" () ()

(* Test Suite *)
let () =
  let open Alcotest in
  run "PPX Variable Support" [
    "basic_types", [
      test_case "string variables" `Quick test_string_variables;
      test_case "int variables" `Quick test_int_variables;
      test_case "float variables" `Quick test_float_variables;
      test_case "bool variables" `Quick test_bool_variables;
    ];
    "complex", [
      test_case "mixed variables" `Quick test_mixed_variables;
      test_case "computed values" `Quick test_computed_values;
      test_case "function results" `Quick test_function_results;
      test_case "mixed literals and variables" `Quick test_mixed_literals_and_variables;
    ];
    "all_levels", [
      test_case "variables in all levels" `Quick test_variables_all_levels;
    ];
    "advanced", [
      test_case "complex expressions" `Quick test_complex_expressions;
      test_case "Value.t variables" `Quick test_value_t_variables;
    ];
  ]
