open Flo

(* Test trace ID generation *)
let test_generate_trace_id () =
  let id1 = Trace_context.generate_trace_id () in
  let id2 = Trace_context.generate_trace_id () in

  (* Check format: 32 hex characters *)
  Alcotest.(check int) "trace_id length" 32 (String.length id1);
  Alcotest.(check bool) "trace_id is hex" true
    (Trace_context.is_valid_trace_id id1);

  (* Check not all zeros *)
  Alcotest.(check bool) "trace_id not all zeros" false
    (String.for_all (fun c -> c = '0') id1);

  (* Check uniqueness (highly probable) *)
  Alcotest.(check bool) "trace_id unique" false (id1 = id2)

let test_generate_span_id () =
  let id1 = Trace_context.generate_span_id () in
  let id2 = Trace_context.generate_span_id () in

  (* Check format: 16 hex characters *)
  Alcotest.(check int) "span_id length" 16 (String.length id1);
  Alcotest.(check bool) "span_id is hex" true
    (Trace_context.is_valid_span_id id1);

  (* Check not all zeros *)
  Alcotest.(check bool) "span_id not all zeros" false
    (String.for_all (fun c -> c = '0') id1);

  (* Check uniqueness (highly probable) *)
  Alcotest.(check bool) "span_id unique" false (id1 = id2)

(* Test create_child *)
let test_create_child () =
  let parent = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in

  let child = Trace_context.create_child parent in

  (* Child should preserve trace_id *)
  Alcotest.(check string) "child preserves trace_id"
    parent.trace_id child.trace_id;

  (* Child should have new span_id *)
  Alcotest.(check bool) "child has new span_id" false
    (child.span_id = parent.span_id);
  Alcotest.(check bool) "child span_id valid" true
    (Trace_context.is_valid_span_id child.span_id);

  (* Child should have parent's span_id as parent_span_id *)
  Alcotest.(check (option string)) "child has parent_span_id"
    (Some parent.span_id) child.parent_span_id;

  (* Child should preserve trace_flags *)
  Alcotest.(check int) "child preserves trace_flags"
    parent.trace_flags child.trace_flags

(* Test parse_traceparent valid *)
let test_parse_traceparent_valid () =
  let header = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" in
  match Trace_context.parse_traceparent header with
  | Ok ctx ->
      Alcotest.(check string) "parsed trace_id"
        "0af7651916cd43dd8448eb211c80319c" ctx.trace_id;
      Alcotest.(check string) "parsed span_id"
        "b7ad6b7169203331" ctx.span_id;
      Alcotest.(check (option string)) "parsed parent_span_id"
        None ctx.parent_span_id;
      Alcotest.(check int) "parsed trace_flags" 0x01 ctx.trace_flags
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

let test_parse_traceparent_uppercase () =
  (* W3C spec allows uppercase but we normalize to lowercase *)
  let header = "00-0AF7651916CD43DD8448EB211C80319C-B7AD6B7169203331-01" in
  match Trace_context.parse_traceparent header with
  | Ok ctx ->
      Alcotest.(check string) "normalized to lowercase"
        "0af7651916cd43dd8448eb211c80319c" ctx.trace_id
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

let test_parse_traceparent_invalid_version () =
  let header = "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" in
  match Trace_context.parse_traceparent header with
  | Ok _ -> Alcotest.fail "Should reject invalid version"
  | Error msg ->
      Alcotest.(check bool) "error mentions version" true
        (String.contains msg 'v' || String.contains msg 'V')

let test_parse_traceparent_invalid_trace_id () =
  (* All zeros trace_id *)
  let header = "00-00000000000000000000000000000000-b7ad6b7169203331-01" in
  match Trace_context.parse_traceparent header with
  | Ok _ -> Alcotest.fail "Should reject all-zeros trace_id"
  | Error msg ->
      Alcotest.(check bool) "error mentions trace_id" true
        (String.contains msg 't' || String.contains msg 'T')

let test_parse_traceparent_invalid_span_id () =
  (* All zeros span_id *)
  let header = "00-0af7651916cd43dd8448eb211c80319c-0000000000000000-01" in
  match Trace_context.parse_traceparent header with
  | Ok _ -> Alcotest.fail "Should reject all-zeros span_id"
  | Error msg ->
      Alcotest.(check bool) "error mentions span" true
        (String.contains msg 's' || String.contains msg 'S')

let test_parse_traceparent_invalid_format () =
  let header = "invalid-format" in
  match Trace_context.parse_traceparent header with
  | Ok _ -> Alcotest.fail "Should reject invalid format"
  | Error msg ->
      Alcotest.(check bool) "error mentions format" true
        (String.length msg > 0)

let test_parse_traceparent_wrong_length () =
  (* trace_id too short *)
  let header = "00-0af7651916cd43dd-b7ad6b7169203331-01" in
  match Trace_context.parse_traceparent header with
  | Ok _ -> Alcotest.fail "Should reject wrong trace_id length"
  | Error _ -> ()

(* Test format_traceparent *)
let test_format_traceparent () =
  let ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = Some "parent123";
    trace_flags = 0x01;
  } in

  let formatted = Trace_context.format_traceparent ctx in
  Alcotest.(check string) "formatted traceparent"
    "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    formatted

let test_format_traceparent_uppercase () =
  (* Should normalize to lowercase *)
  let ctx = {
    Trace_context.trace_id = "0AF7651916CD43DD8448EB211C80319C";
    span_id = "B7AD6B7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in

  let formatted = Trace_context.format_traceparent ctx in
  Alcotest.(check string) "normalized to lowercase"
    "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    formatted

let test_format_traceparent_flags () =
  let ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0xff;
  } in

  let formatted = Trace_context.format_traceparent ctx in
  Alcotest.(check bool) "flags formatted correctly" true
    (String.ends_with ~suffix:"-ff" formatted)

(* Test round-trip *)
let test_round_trip () =
  let original = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" in
  match Trace_context.parse_traceparent original with
  | Ok ctx ->
      let formatted = Trace_context.format_traceparent ctx in
      Alcotest.(check string) "round-trip" original formatted
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Parse failed: %s" msg)

(* Test trace flags *)
let test_is_sampled () =
  Alcotest.(check bool) "0x01 is sampled" true
    (Trace_context.is_sampled 0x01);
  Alcotest.(check bool) "0x00 not sampled" false
    (Trace_context.is_sampled 0x00);
  Alcotest.(check bool) "0x03 is sampled (bit 0 set)" true
    (Trace_context.is_sampled 0x03);
  Alcotest.(check bool) "0x02 not sampled (bit 0 clear)" false
    (Trace_context.is_sampled 0x02)

let test_set_sampled () =
  let flags = 0x00 in
  let flags' = Trace_context.set_sampled flags in
  Alcotest.(check int) "set_sampled sets bit 0" 0x01 flags';

  let flags = 0x02 in
  let flags' = Trace_context.set_sampled flags in
  Alcotest.(check int) "set_sampled preserves other bits" 0x03 flags'

let test_clear_sampled () =
  let flags = 0x01 in
  let flags' = Trace_context.clear_sampled flags in
  Alcotest.(check int) "clear_sampled clears bit 0" 0x00 flags';

  let flags = 0x03 in
  let flags' = Trace_context.clear_sampled flags in
  Alcotest.(check int) "clear_sampled preserves other bits" 0x02 flags'

(* Test validation *)
let test_is_valid_trace_id () =
  Alcotest.(check bool) "valid trace_id" true
    (Trace_context.is_valid_trace_id "0af7651916cd43dd8448eb211c80319c");
  Alcotest.(check bool) "all zeros invalid" false
    (Trace_context.is_valid_trace_id "00000000000000000000000000000000");
  Alcotest.(check bool) "too short invalid" false
    (Trace_context.is_valid_trace_id "0af765");
  Alcotest.(check bool) "too long invalid" false
    (Trace_context.is_valid_trace_id "0af7651916cd43dd8448eb211c80319c00");
  Alcotest.(check bool) "non-hex invalid" false
    (Trace_context.is_valid_trace_id "0af7651916cd43dd8448eb211c80319g")

let test_is_valid_span_id () =
  Alcotest.(check bool) "valid span_id" true
    (Trace_context.is_valid_span_id "b7ad6b7169203331");
  Alcotest.(check bool) "all zeros invalid" false
    (Trace_context.is_valid_span_id "0000000000000000");
  Alcotest.(check bool) "too short invalid" false
    (Trace_context.is_valid_span_id "b7ad6b");
  Alcotest.(check bool) "too long invalid" false
    (Trace_context.is_valid_span_id "b7ad6b716920333100");
  Alcotest.(check bool) "non-hex invalid" false
    (Trace_context.is_valid_span_id "b7ad6b7169203zzz")

let () =
  let open Alcotest in
  run "Trace_context" [
    "generation", [
      test_case "generate_trace_id format and uniqueness" `Quick test_generate_trace_id;
      test_case "generate_span_id format and uniqueness" `Quick test_generate_span_id;
    ];
    "create_child", [
      test_case "create_child preserves trace_id and creates new span" `Quick test_create_child;
    ];
    "parse_traceparent", [
      test_case "parse valid traceparent" `Quick test_parse_traceparent_valid;
      test_case "parse uppercase traceparent" `Quick test_parse_traceparent_uppercase;
      test_case "parse invalid version" `Quick test_parse_traceparent_invalid_version;
      test_case "parse invalid trace_id (all zeros)" `Quick test_parse_traceparent_invalid_trace_id;
      test_case "parse invalid span_id (all zeros)" `Quick test_parse_traceparent_invalid_span_id;
      test_case "parse invalid format" `Quick test_parse_traceparent_invalid_format;
      test_case "parse wrong length" `Quick test_parse_traceparent_wrong_length;
    ];
    "format_traceparent", [
      test_case "format traceparent" `Quick test_format_traceparent;
      test_case "format normalizes to lowercase" `Quick test_format_traceparent_uppercase;
      test_case "format trace_flags correctly" `Quick test_format_traceparent_flags;
    ];
    "round_trip", [
      test_case "parse and format round-trip" `Quick test_round_trip;
    ];
    "trace_flags", [
      test_case "is_sampled checks bit 0" `Quick test_is_sampled;
      test_case "set_sampled sets bit 0" `Quick test_set_sampled;
      test_case "clear_sampled clears bit 0" `Quick test_clear_sampled;
    ];
    "validation", [
      test_case "is_valid_trace_id validates format" `Quick test_is_valid_trace_id;
      test_case "is_valid_span_id validates format" `Quick test_is_valid_span_id;
    ];
  ]
