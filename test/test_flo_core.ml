open Flo

(* Test helpers *)
let test_record msg severity =
  Record.make ~severity ~message:msg

(* Test make creates logger *)
let test_make () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun msg ->
    log_calls := msg :: !log_calls
  ) in

  logger "test1";
  logger "test2";

  Alcotest.(check (list string)) "make logs messages"
    ["test2"; "test1"] !log_calls

(* Test noop discards messages *)
let test_noop () =
  let result = Flo_core.noop "any message" in
  Alcotest.(check unit) "noop returns unit" () result

(* Test contramap transforms message type *)
let test_contramap () =
  let log_calls = ref [] in
  let int_logger = Flo_core.make (fun n ->
    log_calls := n :: !log_calls
  ) in

  let string_to_int s = String.length s in
  let string_logger = Flo_core.contramap string_to_int int_logger in

  string_logger "hello";
  string_logger "hi";

  Alcotest.(check (list int)) "contramap transforms input"
    [2; 5] !log_calls

(* Test >$< operator *)
let test_contramap_operator () =
  let log_calls = ref [] in
  let int_logger = Flo_core.make (fun n ->
    log_calls := n :: !log_calls
  ) in

  let open Flo_core in
  let string_logger = (fun s -> String.length s) >$< int_logger in

  string_logger "test";

  Alcotest.(check (list int)) ">$< operator works"
    [4] !log_calls

(* Test contramap chaining *)
let test_contramap_chain () =
  let log_calls = ref [] in
  let string_logger = Flo_core.make (fun s ->
    log_calls := s :: !log_calls
  ) in

  (* Transform int -> string -> logger *)
  let int_to_string n = string_of_int n in
  let int_logger = Flo_core.contramap int_to_string string_logger in

  (* Transform bool -> int -> string -> logger *)
  let bool_to_int b = if b then 1 else 0 in
  let bool_logger = Flo_core.contramap bool_to_int int_logger in

  bool_logger true;
  bool_logger false;

  Alcotest.(check (list string)) "contramap chains correctly"
    ["0"; "1"] !log_calls

(* Test combine merges two loggers *)
let test_combine () =
  let log_calls1 = ref [] in
  let log_calls2 = ref [] in

  let logger1 = Flo_core.make (fun msg ->
    log_calls1 := msg :: !log_calls1
  ) in

  let logger2 = Flo_core.make (fun msg ->
    log_calls2 := msg :: !log_calls2
  ) in

  let combined = Flo_core.combine logger1 logger2 in
  combined "test";

  Alcotest.(check (list string)) "combine logs to first"
    ["test"] !log_calls1;
  Alcotest.(check (list string)) "combine logs to second"
    ["test"] !log_calls2

(* Test <> operator *)
let test_combine_operator () =
  let log_calls1 = ref [] in
  let log_calls2 = ref [] in

  let logger1 = Flo_core.make (fun msg ->
    log_calls1 := msg :: !log_calls1
  ) in

  let logger2 = Flo_core.make (fun msg ->
    log_calls2 := msg :: !log_calls2
  ) in

  let combined = Flo_core.((logger1) <> (logger2)) in
  combined "test";

  Alcotest.(check (list string)) "<> operator combines"
    ["test"] !log_calls1;
  Alcotest.(check (list string)) "<> operator combines"
    ["test"] !log_calls2

(* Test combine_all with multiple loggers *)
let test_combine_all () =
  let calls1 = ref [] in
  let calls2 = ref [] in
  let calls3 = ref [] in

  let logger1 = Flo_core.make (fun msg -> calls1 := msg :: !calls1) in
  let logger2 = Flo_core.make (fun msg -> calls2 := msg :: !calls2) in
  let logger3 = Flo_core.make (fun msg -> calls3 := msg :: !calls3) in

  let combined = Flo_core.combine_all [logger1; logger2; logger3] in
  combined "test";

  Alcotest.(check (list string)) "combine_all logger1" ["test"] !calls1;
  Alcotest.(check (list string)) "combine_all logger2" ["test"] !calls2;
  Alcotest.(check (list string)) "combine_all logger3" ["test"] !calls3

(* Test combine_all with empty list *)
let test_combine_all_empty () =
  let combined = Flo_core.combine_all [] in
  let result = combined "test" in
  Alcotest.(check unit) "combine_all [] is noop" () result

(* Test filter with predicate *)
let test_filter () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun n ->
    log_calls := n :: !log_calls
  ) in

  let filtered = Flo_core.filter (fun n -> n > 0) logger in

  filtered 5;
  filtered (-3);
  filtered 10;
  filtered 0;

  Alcotest.(check (list int)) "filter only passes positive"
    [10; 5] !log_calls

(* Test level_filter *)
let test_level_filter () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun record ->
    log_calls := record.Record.severity :: !log_calls
  ) in

  let filtered = Flo_core.level_filter Severity.Warn logger in

  filtered (test_record "trace" Severity.Trace);
  filtered (test_record "debug" Severity.Debug);
  filtered (test_record "info" Severity.Info);
  filtered (test_record "warn" Severity.Warn);
  filtered (test_record "error" Severity.Error);
  filtered (test_record "fatal" Severity.Fatal);

  Alcotest.(check int) "level_filter count" 3 (List.length !log_calls);
  (* Should have Warn, Error, Fatal *)
  Alcotest.(check bool) "has Fatal" true
    (List.mem Severity.Fatal !log_calls);
  Alcotest.(check bool) "has Error" true
    (List.mem Severity.Error !log_calls);
  Alcotest.(check bool) "has Warn" true
    (List.mem Severity.Warn !log_calls);
  Alcotest.(check bool) "no Info" false
    (List.mem Severity.Info !log_calls)

(* Test log application *)
let test_log () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun msg ->
    log_calls := msg :: !log_calls
  ) in

  let _ = Flo_core.log logger "test" in

  Alcotest.(check (list string)) "log applies logger"
    ["test"] !log_calls

(* Test <& operator *)
let test_log_operator () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun msg ->
    log_calls := msg :: !log_calls
  ) in

  let _ = Flo_core.(logger <& "test") in

  Alcotest.(check (list string)) "<& operator applies logger"
    ["test"] !log_calls

(* Test monoid left identity: noop <> logger = logger *)
let test_monoid_left_identity () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun msg ->
    log_calls := msg :: !log_calls
  ) in

  let combined = Flo_core.combine Flo_core.noop logger in
  combined "test";

  Alcotest.(check (list string)) "left identity"
    ["test"] !log_calls

(* Test monoid right identity: logger <> noop = logger *)
let test_monoid_right_identity () =
  let log_calls = ref [] in
  let logger = Flo_core.make (fun msg ->
    log_calls := msg :: !log_calls
  ) in

  let combined = Flo_core.combine logger Flo_core.noop in
  combined "test";

  Alcotest.(check (list string)) "right identity"
    ["test"] !log_calls

(* Test monoid associativity: (a <> b) <> c = a <> (b <> c) *)
let test_monoid_associativity () =
  let calls1a = ref [] in
  let calls2a = ref [] in
  let calls3a = ref [] in

  let calls1b = ref [] in
  let calls2b = ref [] in
  let calls3b = ref [] in

  let logger1a = Flo_core.make (fun msg -> calls1a := msg :: !calls1a) in
  let logger2a = Flo_core.make (fun msg -> calls2a := msg :: !calls2a) in
  let logger3a = Flo_core.make (fun msg -> calls3a := msg :: !calls3a) in

  let logger1b = Flo_core.make (fun msg -> calls1b := msg :: !calls1b) in
  let logger2b = Flo_core.make (fun msg -> calls2b := msg :: !calls2b) in
  let logger3b = Flo_core.make (fun msg -> calls3b := msg :: !calls3b) in

  (* (a <> b) <> c *)
  let left_assoc = Flo_core.combine (Flo_core.combine logger1a logger2a) logger3a in
  left_assoc "test";

  (* a <> (b <> c) *)
  let right_assoc = Flo_core.combine logger1b (Flo_core.combine logger2b logger3b) in
  right_assoc "test";

  (* All should receive the message *)
  Alcotest.(check (list string)) "associativity logger1" ["test"] !calls1a;
  Alcotest.(check (list string)) "associativity logger2" ["test"] !calls2a;
  Alcotest.(check (list string)) "associativity logger3" ["test"] !calls3a;
  Alcotest.(check (list string)) "associativity logger1" ["test"] !calls1b;
  Alcotest.(check (list string)) "associativity logger2" ["test"] !calls2b;
  Alcotest.(check (list string)) "associativity logger3" ["test"] !calls3b

(* Test complex composition pipeline *)
let test_complex_pipeline () =
  let log_calls = ref [] in

  (* Base logger that logs strings *)
  let string_logger = Flo_core.make (fun s ->
    log_calls := s :: !log_calls
  ) in

  (* Transform Record.t -> string *)
  let record_to_string r =
    Printf.sprintf "[%s] %s"
      (Severity.to_string r.Record.severity)
      r.Record.message
  in

  (* Create record logger *)
  let record_logger = Flo_core.contramap record_to_string string_logger in

  (* Filter only Warn and above *)
  let filtered_logger = Flo_core.level_filter Severity.Warn record_logger in

  (* Test *)
  filtered_logger (test_record "info msg" Severity.Info);
  filtered_logger (test_record "warn msg" Severity.Warn);
  filtered_logger (test_record "error msg" Severity.Error);

  Alcotest.(check int) "filtered count" 2 (List.length !log_calls);
  Alcotest.(check bool) "has warn" true
    (List.exists (fun s -> String.contains s 'w') !log_calls);
  Alcotest.(check bool) "has error" true
    (List.exists (fun s -> String.contains s 'e') !log_calls)

let () =
  let open Alcotest in
  run "Flo_core" [
    "construction", [
      test_case "make creates logger" `Quick test_make;
      test_case "noop discards messages" `Quick test_noop;
    ];
    "contramap", [
      test_case "contramap transforms message type" `Quick test_contramap;
      test_case ">$< operator works" `Quick test_contramap_operator;
      test_case "contramap chains correctly" `Quick test_contramap_chain;
    ];
    "combine", [
      test_case "combine merges two loggers" `Quick test_combine;
      test_case "<> operator combines" `Quick test_combine_operator;
      test_case "combine_all with multiple loggers" `Quick test_combine_all;
      test_case "combine_all with empty list" `Quick test_combine_all_empty;
    ];
    "filter", [
      test_case "filter with predicate" `Quick test_filter;
      test_case "level_filter filters by severity" `Quick test_level_filter;
    ];
    "application", [
      test_case "log applies logger" `Quick test_log;
      test_case "<& operator applies logger" `Quick test_log_operator;
    ];
    "monoid_laws", [
      test_case "left identity" `Quick test_monoid_left_identity;
      test_case "right identity" `Quick test_monoid_right_identity;
      test_case "associativity" `Quick test_monoid_associativity;
    ];
    "integration", [
      test_case "complex composition pipeline" `Quick test_complex_pipeline;
    ];
  ]
