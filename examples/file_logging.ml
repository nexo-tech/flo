(* File Logging Example

   This example demonstrates file-based logging with rotation and retention:
   - Basic file logging
   - Size-based rotation
   - Time-based rotation
   - Retention policies
*)

open Flo

(* Example 1: Basic file logging *)
let example_basic_file_logging ~env =
  Eio.traceln "\n=== Basic File Logging ===";

  let cwd = Eio.Stdenv.cwd env in

  (* Create a basic file sink *)
  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "basic.log");
      format = `Json;
      level = Severity.Info;
      buffer_size = 4096;  (* 4KB buffer *)
      create_dirs = true;
    } in

    (* Write some log messages *)
    for i = 1 to 10 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Log message %d" i)
      in
      let record = Record.with_attributes [
        ("iteration", Value.Int (Int64.of_int i));
        ("example", Value.String "basic_file");
      ] record in
      Flo_sink_file.write_basic sink record
    done;

    (* Flush to ensure all data is written *)
    Flo_sink_file.flush_basic sink;

    Eio.traceln "Wrote 10 messages to logs/basic.log"

(* Example 2: Size-based rotation *)
let example_size_rotation ~env =
  Eio.traceln "\n=== Size-Based Rotation ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "rotating_size.log");
      format = `Logfmt;
      rotation = Size 1024L;  (* Rotate at 1KB *)
      retention = Some (Keep_last 3);  (* Keep last 3 rotated files *)
      level = Severity.Debug;
      buffer_size = 0;  (* Unbuffered for demo *)
      create_dirs = true;
    } in

    (* Write enough messages to trigger rotation *)
    for i = 1 to 50 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Size rotation test message number %d with some extra text to increase size" i)
      in
      let record = Record.with_attributes [
        ("iteration", Value.Int (Int64.of_int i));
        ("padding", Value.String "Extra data to reach rotation threshold faster");
      ] record in
      Flo_sink_file.write_rotating sink record;

      (* Flush periodically to see rotation *)
      if i mod 10 = 0 then
        Flo_sink_file.flush_rotating sink
    done;

    Flo_sink_file.flush_rotating sink;
    Eio.traceln "Wrote 50 messages with size-based rotation (1KB limit)"

(* Example 3: Time-based rotation *)
let example_interval_rotation ~env =
  Eio.traceln "\n=== Time-Based Rotation (Interval) ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs/rotating_interval.log");
      format = `Json;
      rotation = Interval 2.0;  (* Rotate every 2 seconds *)
      retention = Some (Keep_last 2);  (* Keep last 2 files *)
      level = Severity.Info;
      buffer_size = 0;
      create_dirs = true;
    } in

    (* Write messages over time to trigger interval rotation *)
    for i = 1 to 6 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Interval rotation test %d" i)
      in
      Flo_sink_file.write_rotating sink record;
      Flo_sink_file.flush_rotating sink;

      Eio.traceln "Wrote message %d" i;

      (* Wait 1 second between messages *)
      Eio.Time.sleep (Eio.Stdenv.clock env) 1.0
    done;

    Eio.traceln "Completed time-based rotation demo (2 second intervals)"

(* Example 4: Retention policies *)
let example_retention_policies ~env =
  Eio.traceln "\n=== Retention Policies ===";

  let cwd = Eio.Stdenv.cwd env in

  (* Keep last N files *)
  Eio.traceln "\nTesting Keep_last 2 policy...";
  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs/retention_count.log");
      format = `Logfmt;
      rotation = Size 512L;  (* Small size for quick rotation *)
      retention = Some (Keep_last 2);
      level = Severity.Info;
      buffer_size = 0;
      create_dirs = true;
    } in

    (* Generate enough logs to create multiple rotated files *)
    for i = 1 to 30 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Retention test message %d with padding text" i)
      in
      Flo_sink_file.write_rotating sink record;
      if i mod 5 = 0 then Flo_sink_file.flush_rotating sink
    done;

    Flo_sink_file.flush_rotating sink;
    Eio.traceln "Only the 2 most recent rotated files should remain";

  (* Keep files within duration *)
  Eio.traceln "\nTesting Keep_duration policy...";
  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs/retention_duration.log");
      format = `Json;
      rotation = Size 512L;
      retention = Some (Keep_duration 5.0);  (* Keep files from last 5 seconds *)
      level = Severity.Info;
      buffer_size = 0;
      create_dirs = true;
    } in

    for i = 1 to 20 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Duration retention test %d" i)
      in
      Flo_sink_file.write_rotating sink record;
      if i mod 3 = 0 then Flo_sink_file.flush_rotating sink
    done;

    Flo_sink_file.flush_rotating sink;
    Eio.traceln "Files older than 5 seconds should be deleted"

(* Example 5: Combined with semantic conventions *)
let example_production_logging ~env =
  Eio.traceln "\n=== Production Logging Example ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs/production.log");
      format = `Json;
      rotation = Size 10240L;  (* 10KB *)
      retention = Some (Keep_last 5);
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Simulate production application logs *)
    Eio.traceln "Simulating production application...";

    (* Application startup *)
    let record = Record.make
      ~severity:Severity.Info
      ~message:"Application started"
    in
    let record = Record.with_attributes [
      Flo_semconv.service_name "order-service";
      Flo_semconv.service_version "2.1.0";
      Flo_semconv.deployment_environment "production";
      Flo_semconv.host_name "app-server-01";
    ] record in
    Flo_sink_file.write_rotating sink record;

    (* Simulate HTTP requests *)
    for i = 1 to 20 do
      let status = if i mod 10 = 0 then 500 else 200 in
      let severity = if status >= 500 then Severity.Error else Severity.Info in

      let record = Record.make
        ~severity
        ~message:"HTTP request processed"
      in
      let record = Record.with_attributes [
        Flo_semconv.http_method (if i mod 2 = 0 then "GET" else "POST");
        Flo_semconv.http_status_code status;
        Flo_semconv.http_target (Printf.sprintf "/api/orders/%d" i);
        Flo_semconv.duration_ms (Random.float 100.0);
        Flo_semconv.user_id (Printf.sprintf "user_%d" (i mod 5));
      ] record in
      Flo_sink_file.write_rotating sink record
    done;

    Flo_sink_file.flush_rotating sink;
    Eio.traceln "Production logs written to logs/production.log"

(* Main *)
let main env =
  Eio.traceln "=== Flo File Logging Examples ===";

  (* Run all examples *)
  example_basic_file_logging ~env;
  example_size_rotation ~env;
  example_interval_rotation ~env;
  example_retention_policies ~env;
  example_production_logging ~env;

  Eio.traceln "\n=== All examples completed ===";
  Eio.traceln "Check the logs/ directory for output files"

let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    main env
