(* Test PPX span annotation functionality *)

(* Test 1: Basic span annotation with expression *)
let test_span_expression () =
  let result = [%span
    begin
      Flo.info "Inside span";
      42
    end
  ] in
  Alcotest.(check int) "span expression works" 42 result

(* Test 2: Span with function call *)
let test_span_with_function () =
  let compute x = x * 2 in
  let result = [%span compute 21] in
  Alcotest.(check int) "span with function works" 42 result

(* Test 3: Span with logging inside *)
let test_span_with_logging () =
  let result = [%span
    begin
      [%log.info "Processing in span"];
      [%log.debug "Debug in span"];
      "success"
    end
  ] in
  Alcotest.(check string) "span with logging works" "success" result

(* Test 4: Nested spans *)
let test_nested_spans () =
  let result = [%span
    begin
      [%log.info "Outer span"];
      let inner = [%span
        begin
          [%log.info "Inner span"];
          21
        end
      ] in
      inner * 2
    end
  ] in
  Alcotest.(check int) "nested spans work" 42 result

(* Test 5: Span with exception handling *)
let test_span_with_exception () =
  let result = try
    [%span
      begin
        [%log.info "About to fail"];
        failwith "test error"
      end
    ]
  with Failure msg -> msg
  in
  Alcotest.(check string) "span with exception works" "test error" result

(* Test 6: Span with complex computation *)
let test_span_complex_computation () =
  let result = [%span
    begin
      let x = 10 in
      let y = 20 in
      [%log.info "Computing" ~x:10 ~y:20];
      x + y + 12
    end
  ] in
  Alcotest.(check int) "span with complex computation works" 42 result

(* Test 7: Span annotation is transparent (doesn't change return value) *)
let test_span_transparency () =
  let without_span = 42 in
  let with_span = [%span 42] in
  Alcotest.(check int) "span is transparent" without_span with_span

(* Test 8: Multiple sequential spans *)
let test_multiple_sequential_spans () =
  let result1 = [%span
    begin
      [%log.info "First span"];
      21
    end
  ] in

  let result2 = [%span
    begin
      [%log.info "Second span"];
      21
    end
  ] in

  Alcotest.(check int) "multiple sequential spans work" 42 (result1 + result2)

(* Test Suite *)
let () =
  let open Alcotest in
  run "PPX Span Annotation" [
    "basic", [
      test_case "span expression" `Quick test_span_expression;
      test_case "span with function" `Quick test_span_with_function;
      test_case "span transparency" `Quick test_span_transparency;
    ];
    "with_logging", [
      test_case "span with logging" `Quick test_span_with_logging;
      test_case "nested spans" `Quick test_nested_spans;
      test_case "complex computation" `Quick test_span_complex_computation;
    ];
    "edge_cases", [
      test_case "span with exception" `Quick test_span_with_exception;
      test_case "multiple sequential spans" `Quick test_multiple_sequential_spans;
    ];
  ]
