(* Performance Application Example

   This example demonstrates high-throughput async logging:
   - Non-blocking writes with background processing
   - Batching for efficient I/O
   - Auto-flush intervals
   - Drain on shutdown to ensure no data loss
*)

open Flo

(* Example 1: Basic async logging *)
let example_basic_async ~env =
  Eio.traceln "\n=== Basic Async Logging ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    (* Create underlying file sink *)
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "async_basic.log");
      format = `Json;
      rotation = Size 10240L;  (* 10KB *)
      retention = Some (Keep_last 3);
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Wrap with async sink *)
    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 1000;
        batch_size = 50;
        flush_interval = 1.0;
        level = Severity.Info;
      }
      ~underlying:file_sink
    in

    (* Write logs - these return immediately *)
    for i = 1 to 500 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Async message %d" i)
      in
      let record = Record.with_attributes [
        ("iteration", Value.Int (Int64.of_int i));
      ] record in
      Flo_sink_async.write async_sink record
    done;

    Eio.traceln "Queued 500 messages (non-blocking)";

    (* Drain before shutdown *)
    Flo_sink_async.drain async_sink;

    let (queued, written, dropped) = Flo_sink_async.stats async_sink in
    Eio.traceln "Stats: queued=%d written=%Ld dropped=%Ld" queued written dropped

(* Example 2: High-throughput logging *)
let example_high_throughput ~env =
  Eio.traceln "\n=== High-Throughput Logging ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "throughput.log");
      format = `Logfmt;
      rotation = Size 51200L;  (* 50KB *)
      retention = Some (Keep_last 5);
      level = Severity.Debug;
      buffer_size = 8192;
      create_dirs = true;
    } in

    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 10000;  (* Large buffer *)
        batch_size = 500;         (* Large batches *)
        flush_interval = 0.5;     (* Fast flush *)
        level = Severity.Debug;
      }
      ~underlying:file_sink
    in

    Eio.traceln "Writing 10,000 messages...";
    let start_time = Unix.gettimeofday () in

    (* High-volume logging *)
    for i = 1 to 10_000 do
      let record = Record.make
        ~severity:(if i mod 100 = 0 then Severity.Warn else Severity.Debug)
        ~message:(Printf.sprintf "High-throughput message %d" i)
      in
      Flo_sink_async.write async_sink record;

      (* Occasional info milestone *)
      if i mod 1000 = 0 then begin
        let milestone = Record.make
          ~severity:Severity.Info
          ~message:(Printf.sprintf "Processed %d messages" i)
        in
        Flo_sink_async.write async_sink milestone
      end
    done;

    let elapsed = Unix.gettimeofday () -. start_time in
    Eio.traceln "Queued 10,000 messages in %.3fs (%.0f msgs/sec)" elapsed (10_000.0 /. elapsed);

    (* Drain before exit *)
    Eio.traceln "Draining...";
    Flo_sink_async.drain async_sink;

    let (queued, written, dropped) = Flo_sink_async.stats async_sink in
    Eio.traceln "Final stats: queued=%d written=%Ld dropped=%Ld" queued written dropped

(* Example 3: Async with structured logging *)
let example_async_structured ~env =
  Eio.traceln "\n=== Async with Structured Logging ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "async_structured.log");
      format = `Json;
      rotation = Size 20480L;  (* 20KB *)
      retention = Some (Keep_last 2);
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 5000;
        batch_size = 100;
        flush_interval = 0.5;
        level = Severity.Info;
      }
      ~underlying:file_sink
    in

    (* Simulate web service requests *)
    Eio.traceln "Simulating 1000 HTTP requests...";

    for i = 1 to 1000 do
      let status = if i mod 50 = 0 then 500 else 200 in
      let severity = if status >= 500 then Severity.Error else Severity.Info in

      let record = Record.make
        ~severity
        ~message:"HTTP request"
      in
      let record = Record.with_attributes [
        Flo_semconv.http_method (if i mod 2 = 0 then "GET" else "POST");
        Flo_semconv.http_status_code status;
        Flo_semconv.http_target (Printf.sprintf "/api/resource/%d" i);
        Flo_semconv.duration_ms (Random.float 50.0);
        Flo_semconv.user_id (Printf.sprintf "user_%d" (i mod 10));
      ] record in
      Flo_sink_async.write async_sink record
    done;

    Eio.traceln "All requests queued";

    (* Drain *)
    Flo_sink_async.drain async_sink;

    let (_, written, dropped) = Flo_sink_async.stats async_sink in
    Eio.traceln "Wrote %Ld records, dropped %Ld" written dropped

(* Example 4: Stress test with buffer overflow *)
let example_buffer_overflow ~env =
  Eio.traceln "\n=== Buffer Overflow Test ===";

  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "overflow.log");
      format = `Logfmt;
      rotation = Size 102400L;  (* 100KB *)
      retention = None;
      level = Severity.Info;
      buffer_size = 8192;
      create_dirs = true;
    } in

    (* Small buffer to test overflow *)
    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 100;   (* Very small *)
        batch_size = 10;
        flush_interval = 2.0;    (* Slow flush *)
        level = Severity.Info;
      }
      ~underlying:file_sink
    in

    Eio.traceln "Writing 500 messages to small buffer (100 capacity)...";

    (* Flood the buffer *)
    for i = 1 to 500 do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Overflow test %d" i)
      in
      Flo_sink_async.write async_sink record
    done;

    (* Let background fiber process some *)
    Eio.Time.sleep (Eio.Stdenv.clock env) 0.5;

    (* Drain *)
    Flo_sink_async.drain async_sink;

    let (_, written, dropped) = Flo_sink_async.stats async_sink in
    Eio.traceln "Buffer overflow: wrote=%Ld dropped=%Ld" written dropped;
    Eio.traceln "(Some messages expected to be dropped due to small buffer)"

(* Example 5: Performance comparison *)
let example_performance_comparison ~env =
  Eio.traceln "\n=== Performance Comparison ===";

  let cwd = Eio.Stdenv.cwd env in
  let num_messages = 5000 in

  (* Synchronous file sink *)
  Eio.traceln "Testing synchronous file sink...";
  let sync_time = Eio.Switch.run @@ fun sw ->
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "sync_perf.log");
      format = `Json;
      rotation = Size 1048576L;  (* 1MB *)
      retention = None;
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    let start = Unix.gettimeofday () in
    for i = 1 to num_messages do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Sync message %d" i)
      in
      Flo_sink_file.write_rotating file_sink record
    done;
    Flo_sink_file.flush_rotating file_sink;
    Unix.gettimeofday () -. start
  in

  (* Async file sink *)
  Eio.traceln "Testing async file sink...";
  let async_time = Eio.Switch.run @@ fun sw ->
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "async_perf.log");
      format = `Json;
      rotation = Size 1048576L;
      retention = None;
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 10000;
        batch_size = 500;
        flush_interval = 0.1;
        level = Severity.Info;
      }
      ~underlying:file_sink
    in

    let start = Unix.gettimeofday () in
    for i = 1 to num_messages do
      let record = Record.make
        ~severity:Severity.Info
        ~message:(Printf.sprintf "Async message %d" i)
      in
      Flo_sink_async.write async_sink record
    done;
    let queue_time = Unix.gettimeofday () -. start in

    Flo_sink_async.drain async_sink;
    let total_time = Unix.gettimeofday () -. start in

    Eio.traceln "  Queue time: %.3fs (%.0f msgs/sec)" queue_time (float_of_int num_messages /. queue_time);
    total_time
  in

  Eio.traceln "\nResults for %d messages:" num_messages;
  Eio.traceln "  Synchronous: %.3fs (%.0f msgs/sec)" sync_time (float_of_int num_messages /. sync_time);
  Eio.traceln "  Async:       %.3fs (%.0f msgs/sec)" async_time (float_of_int num_messages /. async_time);
  Eio.traceln "  Speedup:     %.2fx" (sync_time /. async_time)

(* Main *)
let main env =
  Eio.traceln "=== Flo Async Performance Examples ===";

  example_basic_async ~env;
  example_high_throughput ~env;
  example_async_structured ~env;
  example_buffer_overflow ~env;
  example_performance_comparison ~env;

  Eio.traceln "\n=== All examples completed ===";
  Eio.traceln "Check logs/ directory for output files"

let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    main env
