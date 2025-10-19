(* Core Compositional API Examples
 *
 * This example demonstrates Flo_core's contravariant functor and monoid-based
 * composition for building sophisticated logging pipelines.
 *)

open Flo_core

(* Example 1: Basic Logger Construction *)
let example_basic_construction () =
  print_endline "\n=== Basic Logger Construction ===\n";

  (* Construct a simple logger *)
  let console_logger = Flo_core.make (fun (record : Record.t) ->
    let formatted = Flo_format_pretty.format record in
    print_endline formatted
  ) in

  (* Use the logger *)
  let record = Record.make ~severity:Severity.Info ~message:"Hello from core logger" in
  Flo_core.log console_logger record;

  (* Using the (<&) operator *)
  console_logger <& record;

  print_endline "\nFlo_core.make creates loggers from functions"

(* Example 2: Contramap - Transform Input Messages *)
let example_contramap () =
  print_endline "\n=== Contramap - Transform Messages ===\n";

  (* Base logger that works with Records *)
  let record_logger = Flo_core.make (fun record ->
    Printf.printf "[%s] %s\n"
      (Severity.to_string record.Record.severity)
      record.Record.message
  ) in

  (* Transform string messages to Records using contramap *)
  let string_logger =
    Flo_core.contramap
      (fun msg -> Record.make ~severity:Severity.Info ~message:msg)
      record_logger
  in

  (* Now we can log strings directly *)
  Flo_core.log string_logger "This is a string message";
  string_logger <& "Another string message";

  (* Using the (>$<) operator *)
  let another_string_logger =
    (fun msg -> Record.make ~severity:Severity.Success ~message:msg)
    >$< record_logger
  in

  another_string_logger <& "Success message via operator";

  print_endline "\nContramap transforms input type (string → Record)"

(* Example 3: Logger Combination (Monoid) *)
let example_combination () =
  print_endline "\n=== Logger Combination (Monoid) ===\n";

  (* Create multiple loggers *)
  let console_logger = Flo_core.make (fun record ->
    Printf.printf "[CONSOLE] %s\n" record.Record.message
  ) in

  let file_logger = Flo_core.make (fun record ->
    Printf.printf "[FILE] Would write to file: %s\n" record.Record.message
  ) in

  let metric_logger = Flo_core.make (fun record ->
    Printf.printf "[METRICS] severity=%s\n"
      (Severity.to_string record.Record.severity)
  ) in

  (* Combine them using combine *)
  let multi_logger = Flo_core.combine console_logger file_logger in

  let record = Record.make ~severity:Severity.Info ~message:"Multi-destination log" in
  multi_logger <& record;

  print_endline "";

  (* Combine using (<>) operator *)
  let triple_logger = console_logger <> file_logger <> metric_logger in

  let record2 = Record.make ~severity:Severity.Warn ~message:"Triple destination" in
  triple_logger <& record2;

  print_endline "";

  (* Combine list of loggers *)
  let all_loggers = Flo_core.combine_all [console_logger; file_logger; metric_logger] in

  let record3 = Record.make ~severity:Severity.Success ~message:"All destinations" in
  all_loggers <& record3;

  print_endline "\nCombination sends messages to all loggers (monoid)"

(* Example 4: Filtering Pipelines *)
let example_filtering () =
  print_endline "\n=== Filtering Pipelines ===\n";

  (* Base logger *)
  let base_logger = Flo_core.make (fun record ->
    Printf.printf "[LOG] %s - %s\n"
      (Severity.to_string record.Record.severity)
      record.Record.message
  ) in

  (* Filter 1: Only errors and above *)
  let error_logger = Flo_core.level_filter Severity.Error base_logger in

  print_endline "Error logger (only ERROR+):";
  error_logger <& Record.make ~severity:Severity.Info ~message:"Info (filtered out)";
  error_logger <& Record.make ~severity:Severity.Error ~message:"Error (appears)";
  error_logger <& Record.make ~severity:Severity.Fatal ~message:"Fatal (appears)";

  print_endline "";

  (* Filter 2: Custom predicate - only messages containing "important" *)
  let important_logger = Flo_core.filter (fun record ->
    String.contains record.Record.message 'i'
  ) base_logger in

  print_endline "Important logger (contains 'i'):";
  important_logger <& Record.make ~severity:Severity.Info ~message:"This is important";
  important_logger <& Record.make ~severity:Severity.Info ~message:"Not relevant";
  important_logger <& Record.make ~severity:Severity.Info ~message:"Critical issue";

  print_endline "\nFiltering enables selective logging"

(* Example 5: Complex Pipeline with Contramap, Combine, Filter *)
let example_complex_pipeline () =
  print_endline "\n=== Complex Logging Pipeline ===\n";

  (* Create specialized loggers *)
  let json_logger = Flo_core.make (fun record ->
    Printf.printf "[JSON] %s\n" (Flo_format_json.format record)
  ) in

  let console_logger = Flo_core.make (fun record ->
    Printf.printf "[CONSOLE] %s\n" (Flo_format_pretty.format record)
  ) in

  (* Build pipeline:
     1. Console + JSON (combined)
     2. Only INFO+ (filtered)
     3. Accept strings (contramapped) *)

  let pipeline =
    (console_logger <> json_logger)              (* Combine *)
    |> Flo_core.level_filter Severity.Info      (* Filter *)
    |> Flo_core.contramap (fun msg ->            (* Contramap *)
         Record.make ~severity:Severity.Info ~message:msg)
  in

  (* Use the pipeline - accepts strings, outputs to both, filters by level *)
  print_endline "Pipeline (string → filtered → multi-output):";
  pipeline <& "Application started";
  pipeline <& "Processing complete";

  print_endline "\nPipeline: contramap ∘ filter ∘ combine"

(* Example 6: Custom Log Action with Transformation *)
let example_custom_action () =
  print_endline "\n=== Custom Log Action ===\n";

  (* Custom action: Add timestamp and format *)
  let timestamped_logger = Flo_core.make (fun record ->
    let ts = Ptime.to_rfc3339 ~frac_s:3 (Record.get_timestamp record) in
    Printf.printf "[%s] %-7s %s\n"
      ts
      (String.uppercase_ascii (Severity.to_string record.Record.severity))
      record.Record.message
  ) in

  (* Custom action: Extract and log only specific fields *)
  let field_extractor_logger = Flo_core.make (fun record ->
    let user = List.assoc_opt "user_id" record.Record.attributes in
    match user with
    | Some (Value.String uid) ->
        Printf.printf "[USER=%s] %s\n" uid record.Record.message
    | _ ->
        Printf.printf "[NO_USER] %s\n" record.Record.message
  ) in

  (* Test custom actions *)
  let record1 = Record.make ~severity:Severity.Info ~message:"Custom timestamp format" in
  timestamped_logger <& record1;

  let record2 = Record.make ~severity:Severity.Info ~message:"User action" in
  let record2 = Record.with_attributes [("user_id", Value.String "alice")] record2 in
  field_extractor_logger <& record2;

  print_endline "\nCustom actions enable domain-specific logging logic"

(* Example 7: No-op Logger *)
let example_noop () =
  print_endline "\n=== No-op Logger ===\n";

  (* No-op logger for testing/disabled logging *)
  let noop_logger = Flo_core.noop in

  let record = Record.make ~severity:Severity.Info ~message:"This won't appear" in
  noop_logger <& record;

  print_endline "No output from noop logger ✓";
  print_endline "Use case: Disable logging in tests or specific contexts"

(* Example 8: Composing with Different Message Types *)
let example_multi_type_composition () =
  print_endline "\n=== Multi-Type Composition ===\n";

  (* Logger for raw strings *)
  let string_printer = Flo_core.make (fun s ->
    Printf.printf "[STRING] %s\n" s
  ) in

  (* Logger for integers *)
  let int_printer = Flo_core.make (fun i ->
    Printf.printf "[INT] %d\n" i
  ) in

  (* Logger for Records *)
  let record_printer = Flo_core.make (fun r ->
    Printf.printf "[RECORD] %s\n" r.Record.message
  ) in

  (* Use them *)
  string_printer <& "Hello";
  int_printer <& 42;
  record_printer <& Record.make ~severity:Severity.Info ~message:"Record message";

  (* Transform int logger to accept strings (contramap) *)
  let string_to_int_logger =
    (fun s -> String.length s) >$< int_printer
  in

  print_endline "\nString length logger (string → int → log):";
  string_to_int_logger <& "hello world";
  string_to_int_logger <& "test";

  print_endline "\nContramap enables type transformations in pipelines"

(* Example 9: Real-World Logger Composition *)
let example_real_world () =
  print_endline "\n=== Real-World Logger Composition ===\n";

  (* Production logger: JSON to file + errors to stderr *)
  let json_file = Flo_core.make (fun record ->
    (* In real code, write to file *)
    Printf.printf "[JSON_FILE] %s\n" (Flo_format_json.format record)
  ) in

  let error_console = Flo_core.make (fun record ->
    Printf.printf "[ERROR_CONSOLE] %s\n" (Flo_format_pretty.format record)
  ) in

  (* All logs → JSON file, only ERROR+ → console *)
  let production_logger =
    json_file <>
    (Flo_core.level_filter Severity.Error error_console)
  in

  (* Test with different severities *)
  production_logger <& Record.make ~severity:Severity.Info ~message:"Normal operation";
  production_logger <& Record.make ~severity:Severity.Error ~message:"Error occurred!";
  production_logger <& Record.make ~severity:Severity.Fatal ~message:"Critical failure";

  print_endline "\nProduction pattern: all → file, errors → console"

(* Main *)
let () =
  print_endline "╔════════════════════════════════════════════════════════════════╗";
  print_endline "║          Flō Core Compositional API Examples                   ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝";

  example_basic_construction ();
  example_contramap ();
  example_combination ();
  example_filtering ();
  example_complex_pipeline ();
  example_custom_action ();
  example_noop ();
  example_multi_type_composition ();
  example_real_world ();

  print_endline "\n╔════════════════════════════════════════════════════════════════╗";
  print_endline "║                   All Examples Complete!                       ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝"
