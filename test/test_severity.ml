open Flo

(* Define testable for Severity.t *)
let severity_testable =
  let pp fmt = function
    | Severity.Trace -> Format.fprintf fmt "Trace"
    | Severity.Debug -> Format.fprintf fmt "Debug"
    | Severity.Info -> Format.fprintf fmt "Info"
    | Severity.Success -> Format.fprintf fmt "Success"
    | Severity.Warn -> Format.fprintf fmt "Warn"
    | Severity.Error -> Format.fprintf fmt "Error"
    | Severity.Fatal -> Format.fprintf fmt "Fatal"
  in
  let equal a b = Severity.compare a b = 0 in
  Alcotest.testable pp equal

let test_to_string () =
  let open Severity in
  Alcotest.(check string) "Trace to_string" "trace" (to_string Trace);
  Alcotest.(check string) "Debug to_string" "debug" (to_string Debug);
  Alcotest.(check string) "Info to_string" "info" (to_string Info);
  Alcotest.(check string) "Success to_string" "success" (to_string Success);
  Alcotest.(check string) "Warn to_string" "warn" (to_string Warn);
  Alcotest.(check string) "Error to_string" "error" (to_string Error);
  Alcotest.(check string) "Fatal to_string" "fatal" (to_string Fatal)

let test_to_number () =
  let open Severity in
  (* Test OpenTelemetry severity number compliance *)
  Alcotest.(check int) "Trace = 1 (TRACE)" 1 (to_number Trace);
  Alcotest.(check int) "Debug = 5 (DEBUG)" 5 (to_number Debug);
  Alcotest.(check int) "Info = 9 (INFO)" 9 (to_number Info);
  Alcotest.(check int) "Success = 10 (INFO2)" 10 (to_number Success);
  Alcotest.(check int) "Warn = 13 (WARN)" 13 (to_number Warn);
  Alcotest.(check int) "Error = 17 (ERROR)" 17 (to_number Error);
  Alcotest.(check int) "Fatal = 21 (FATAL)" 21 (to_number Fatal)

let test_of_string () =
  let open Severity in
  let result_testable = Alcotest.result severity_testable Alcotest.string in

  (* Test valid lowercase *)
  Alcotest.(check result_testable)
    "of_string trace" (Ok Trace) (of_string "trace");
  Alcotest.(check result_testable)
    "of_string debug" (Ok Debug) (of_string "debug");
  Alcotest.(check result_testable)
    "of_string info" (Ok Info) (of_string "info");
  Alcotest.(check result_testable)
    "of_string success" (Ok Success) (of_string "success");
  Alcotest.(check result_testable)
    "of_string warn" (Ok Warn) (of_string "warn");
  Alcotest.(check result_testable)
    "of_string error" (Ok Error) (of_string "error");
  Alcotest.(check result_testable)
    "of_string fatal" (Ok Fatal) (of_string "fatal");

  (* Test case insensitivity *)
  Alcotest.(check result_testable)
    "of_string TRACE" (Ok Trace) (of_string "TRACE");
  Alcotest.(check result_testable)
    "of_string Debug" (Ok Debug) (of_string "Debug");
  Alcotest.(check result_testable)
    "of_string INFO" (Ok Info) (of_string "INFO");

  (* Test aliases *)
  Alcotest.(check result_testable)
    "of_string warning" (Ok Warn) (of_string "warning");
  Alcotest.(check result_testable)
    "of_string critical" (Ok Fatal) (of_string "critical")

let test_of_string_invalid () =
  match Severity.of_string "invalid" with
  | Ok _ -> Alcotest.fail "Expected Error for invalid string"
  | Error msg ->
      Alcotest.(check string) "Error message contains 'invalid'"
        "Invalid severity level: invalid" msg

let test_round_trip () =
  let open Severity in
  let levels = [Trace; Debug; Info; Success; Warn; Error; Fatal] in
  List.iter (fun level ->
    let s = to_string level in
    match of_string s with
    | Ok level' ->
        Alcotest.(check severity_testable)
          (Printf.sprintf "round-trip %s" s) level level'
    | Error e ->
        Alcotest.fail (Printf.sprintf "Round-trip failed for %s: %s" s e)
  ) levels

let test_ordering () =
  let open Severity in
  (* Test that severity levels are ordered correctly *)
  Alcotest.(check bool) "Trace < Debug" true
    (compare Trace Debug < 0);
  Alcotest.(check bool) "Debug < Info" true
    (compare Debug Info < 0);
  Alcotest.(check bool) "Info < Success" true
    (compare Info Success < 0);
  Alcotest.(check bool) "Success < Warn" true
    (compare Success Warn < 0);
  Alcotest.(check bool) "Warn < Error" true
    (compare Warn Error < 0);
  Alcotest.(check bool) "Error < Fatal" true
    (compare Error Fatal < 0);

  (* Test equality *)
  Alcotest.(check bool) "Info = Info" true
    (compare Info Info = 0);

  (* Test reverse ordering *)
  Alcotest.(check bool) "Fatal > Error" true
    (compare Fatal Error > 0);
  Alcotest.(check bool) "Warn > Debug" true
    (compare Warn Debug > 0)

let () =
  let open Alcotest in
  run "Severity" [
    "to_string", [
      test_case "Convert severity to string" `Quick test_to_string;
    ];
    "to_number", [
      test_case "Convert to OpenTelemetry severity number" `Quick test_to_number;
    ];
    "of_string", [
      test_case "Parse valid severity strings" `Quick test_of_string;
      test_case "Parse invalid severity string" `Quick test_of_string_invalid;
    ];
    "round_trip", [
      test_case "Round-trip to_string/of_string" `Quick test_round_trip;
    ];
    "ordering", [
      test_case "Severity ordering and comparison" `Quick test_ordering;
    ];
  ]
