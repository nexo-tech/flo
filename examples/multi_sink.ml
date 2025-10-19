(* Multi-Sink Configuration Examples
 *
 * This example demonstrates using multiple sinks simultaneously with
 * different configurations, levels, and formats.
 *)

(* Example 1: Console (Pretty) + File (JSON) Simultaneously *)
let example_console_and_file ~env =
  Eio.traceln "\n=== Console (Pretty) + File (JSON) ===\n";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    (* Sink 1: Console with pretty format *)
    let console_sink = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = true;
      format = `Pretty;
      level = Severity.Info;
    } in

    (* Sink 2: File with JSON format *)
    let file_sink = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "multi_sink.json");
      format = `Json;
      level = Severity.Debug;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Write to both sinks *)
    let records = [
      Record.make ~severity:Severity.Debug ~message:"Debug info (file only)";
      Record.make ~severity:Severity.Info ~message:"Info (both console and file)";
      Record.make ~severity:Severity.Success ~message:"Success (both)";
    ] in

    List.iter (fun r ->
      (* Console sink *)
      if Severity.compare r.Record.severity Severity.Info >= 0 then
        Flo_sink_console.write console_sink r;

      (* File sink *)
      if Severity.compare r.Record.severity Severity.Debug >= 0 then
        Flo_sink_file.write_basic file_sink r
    ) records;

    Flo_sink_console.flush console_sink;
    Flo_sink_file.flush_basic file_sink;

    Eio.traceln "\nLogs written to:";
    Eio.traceln "  - Console (pretty, Info+): 2 logs";
    Eio.traceln "  - File JSON (debug+): 3 logs"

(* Example 2: Different Log Levels Per Sink *)
let example_different_levels ~env =
  Eio.traceln "\n=== Different Log Levels Per Sink ===\n";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    (* Development: Console shows DEBUG+ *)
    let console_dev = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = true;
      format = `Pretty;
      level = Severity.Debug;
    } in

    (* Production file: Only INFO+ *)
    let file_prod = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "production.log");
      format = `Json;
      level = Severity.Info;
      buffer_size = 8192;
      create_dirs = true;
    } in

    (* Audit file: Only WARN+ *)
    let file_audit = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "audit.log");
      format = `Logfmt;
      level = Severity.Warn;
      buffer_size = 4096;
      create_dirs = true;
    } in

    let test_logs = [
      (Severity.Debug, "Debug message");
      (Severity.Info, "Info message");
      (Severity.Warn, "Warning message");
      (Severity.Error, "Error message");
    ] in

    List.iter (fun (severity, msg) ->
      let r = Record.make ~severity ~message:msg in

      if Severity.compare severity Severity.Debug >= 0 then
        Flo_sink_console.write console_dev r;

      if Severity.compare severity Severity.Info >= 0 then
        Flo_sink_file.write_basic file_prod r;

      if Severity.compare severity Severity.Warn >= 0 then
        Flo_sink_file.write_basic file_audit r
    ) test_logs;

    Flo_sink_console.flush console_dev;
    Flo_sink_file.flush_basic file_prod;
    Flo_sink_file.flush_basic file_audit;

    Eio.traceln "\nLog distribution:";
    Eio.traceln "  Console (DEBUG+): 4 logs";
    Eio.traceln "  Production (INFO+): 3 logs";
    Eio.traceln "  Audit (WARN+): 2 logs"

(* Example 3: Filtered Sinks (Errors-Only File) *)
let example_filtered_sinks ~env =
  Eio.traceln "\n=== Filtered Sinks (Errors Only) ===\n";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    (* All logs to console *)
    let console = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = true;
      format = `Pretty;
      level = Severity.Info;
    } in

    (* Only errors to file *)
    let errors_only = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "errors_only.log");
      format = `Json;
      level = Severity.Error;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Simulate mixed severity logs *)
    let mixed_logs = [
      (Severity.Info, "Processing request", [("request_id", Value.String "req-1")]);
      (Severity.Success, "Request completed", [("duration_ms", Value.Float 23.5)]);
      (Severity.Error, "Database timeout", [("timeout_ms", Value.Int 5000L)]);
      (Severity.Info, "Cache hit", [("key", Value.String "user:123")]);
      (Severity.Error, "API rate limit", [("limit", Value.Int 100L)]);
    ] in

    List.iter (fun (severity, msg, attrs) ->
      let r = Record.make ~severity ~message:msg in
      let r = Record.with_attributes attrs r in

      Flo_sink_console.write console r;

      if Severity.compare severity Severity.Error >= 0 then
        Flo_sink_file.write_basic errors_only r
    ) mixed_logs;

    Flo_sink_console.flush console;
    Flo_sink_file.flush_basic errors_only;

    Eio.traceln "\nFiltered output:";
    Eio.traceln "  Console: 5 logs (all severities)";
    Eio.traceln "  errors_only.log: 2 logs (errors only)";
    Eio.traceln "  Use case: Error alerting, monitoring"

(* Example 4: Development vs Production Configuration *)
let example_dev_vs_prod ~env =
  Eio.traceln "\n=== Development vs Production Config ===\n";

  let cwd = Eio.Stdenv.cwd env in

  (* Development configuration *)
  Eio.traceln "Development mode:";
  Eio.Switch.run @@ fun sw ->
    let dev_console = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = true;
      format = `Pretty;
      level = Severity.Debug;
    } in

    let r = Record.make ~severity:Severity.Debug ~message:"Dev: verbose debugging" in
    Flo_sink_console.write dev_console r;
    Flo_sink_console.flush dev_console;

  Eio.traceln "";

  (* Production configuration *)
  Eio.traceln "Production mode:";
  Eio.Switch.run @@ fun sw ->
    let prod_json = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "app.json");
      format = `Json;
      level = Severity.Info;
      buffer_size = 65536;
      create_dirs = true;
    } in

    let prod_errors = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "errors.log");
      format = `Logfmt;
      level = Severity.Error;
      buffer_size = 8192;
      create_dirs = true;
    } in

    let r1 = Record.make ~severity:Severity.Info ~message:"Prod: normal operation" in
    let r2 = Record.make ~severity:Severity.Error ~message:"Prod: error condition" in

    Flo_sink_file.write_basic prod_json r1;
    Flo_sink_file.write_basic prod_json r2;
    Flo_sink_file.write_basic prod_errors r2;

    Flo_sink_file.flush_basic prod_json;
    Flo_sink_file.flush_basic prod_errors;

    Eio.traceln "  app.json: All INFO+ logs";
    Eio.traceln "  errors.log: Only ERROR+ logs"

(* Example 5: Performance Comparison - Single vs Multi Sink *)
let example_performance_comparison ~env =
  Eio.traceln "\n=== Performance Comparison ===\n";

  let cwd = Eio.Stdenv.cwd env in
  let iterations = 1000 in

  (* Test 1: Single sink *)
  Eio.traceln "Single sink (console only):";
  let start1 = Unix.gettimeofday () in
  Eio.Switch.run @@ fun sw ->
    let console = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = false;
      format = `Pretty;
      level = Severity.Info;
    } in

    for i = 1 to iterations do
      let r = Record.make ~severity:Severity.Info
        ~message:(Printf.sprintf "Log %d" i) in
      Flo_sink_console.write console r
    done;
    Flo_sink_console.flush console;

  let duration1 = (Unix.gettimeofday () -. start1) *. 1000.0 in
  Eio.traceln "  Time: %.2f ms for %d logs" duration1 iterations;

  (* Test 2: Multi sink *)
  Eio.traceln "\nMulti-sink (console + file):";
  let start2 = Unix.gettimeofday () in
  Eio.Switch.run @@ fun sw ->
    let console = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = false;
      format = `Pretty;
      level = Severity.Info;
    } in

    let file = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "perf_test.json");
      format = `Json;
      level = Severity.Info;
      buffer_size = 65536;
      create_dirs = true;
    } in

    for i = 1 to iterations do
      let r = Record.make ~severity:Severity.Info
        ~message:(Printf.sprintf "Log %d" i) in
      Flo_sink_console.write console r;
      Flo_sink_file.write_basic file r
    done;

    Flo_sink_console.flush console;
    Flo_sink_file.flush_basic file;

  let duration2 = (Unix.gettimeofday () -. start2) *. 1000.0 in
  Eio.traceln "  Time: %.2f ms for %d logs" duration2 iterations;

  Eio.traceln "\nOverhead: %.2f%%" ((duration2 -. duration1) /. duration1 *. 100.0)

(* Main *)
let main env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Multi-Sink Configuration Examples                 ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_console_and_file ~env;
  example_different_levels ~env;
  example_filtered_sinks ~env;
  example_dev_vs_prod ~env;
  example_performance_comparison ~env;

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
