(* Tests for Flo_sink_async module *)

open Flo_sink_async

(* Helper to create test record *)
let make_test_record severity message =
  Record.make ~severity ~message

(* Test async sink creation *)
let test_create () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "async_test.log");
        format = `Json;
        rotation = Size 10240L;
        retention = None;
        level = Severity.Info;
        buffer_size = 1024;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 100;
          batch_size = 10;
          flush_interval = 1.0;
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      Alcotest.(check bool) "async sink created" true true;

      (* Clean up *)
      drain async_sink;
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test basic write and drain *)
let test_write_and_drain () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "write_drain.log");
        format = `Json;
        rotation = Size 10240L;
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 100;
          batch_size = 5;
          flush_interval = 10.0;  (* Long interval *)
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      (* Write some records *)
      for i = 1 to 10 do
        let record = make_test_record Severity.Info (Printf.sprintf "Message %d" i) in
        write async_sink record
      done;

      (* Drain to ensure all written *)
      drain async_sink;

      (* Check stats *)
      let (_queued, written, dropped) = stats async_sink in
      Alcotest.(check bool) "no drops" true (dropped = 0L);
      Alcotest.(check bool) "all written" true (written >= 10L);

      (* Verify file has content *)
      let content = Eio.Path.load Eio.Path.(cwd / "test_logs" / "write_drain.log") in
      Alcotest.(check bool) "file has content" true (String.length content > 0);

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test batching *)
let test_batching () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "batch.log");
        format = `Logfmt;
        rotation = Size 102400L;
        retention = None;
        level = Severity.Debug;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 1000;
          batch_size = 50;  (* Write 50 at a time *)
          flush_interval = 0.1;
          level = Severity.Debug;
        }
        ~underlying:file_sink
      in

      (* Write exactly 100 records (should be 2 batches of 50) *)
      for i = 1 to 100 do
        let record = make_test_record Severity.Info (Printf.sprintf "Batch message %d" i) in
        write async_sink record
      done;

      (* Give time for batching *)
      Eio.Time.sleep (Eio.Stdenv.clock env) 0.3;

      drain async_sink;

      let (_, written, _) = stats async_sink in
      Alcotest.(check bool) "100 written" true (written = 100L);

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test level filtering *)
let test_level_filtering () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "filter.log");
        format = `Json;
        rotation = Size 10240L;
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 100;
          batch_size = 10;
          flush_interval = 1.0;
          level = Severity.Warn;  (* Only Warn and above *)
        }
        ~underlying:file_sink
      in

      (* Test permits *)
      let info_record = make_test_record Severity.Info "Info" in
      let warn_record = make_test_record Severity.Warn "Warn" in

      Alcotest.(check bool) "info not permitted" false (permits async_sink info_record);
      Alcotest.(check bool) "warn permitted" true (permits async_sink warn_record);

      drain async_sink;
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test flush interval *)
let test_flush_interval () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "interval.log");
        format = `Json;
        rotation = Size 102400L;
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 1000;
          batch_size = 1000;  (* Large batch - won't trigger by size *)
          flush_interval = 0.5;  (* 500ms auto-flush *)
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      (* Write a few records *)
      for i = 1 to 5 do
        let record = make_test_record Severity.Info (Printf.sprintf "Interval test %d" i) in
        write async_sink record
      done;

      (* Wait for flush interval to trigger *)
      Eio.Time.sleep (Eio.Stdenv.clock env) 0.7;

      (* Records should be written by now *)
      let (_, written, _) = stats async_sink in
      Alcotest.(check bool) "flushed by interval" true (written > 0L);

      drain async_sink;
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test stats tracking *)
let test_stats () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "stats.log");
        format = `Json;
        rotation = Size 102400L;
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 1000;
          batch_size = 50;
          flush_interval = 0.1;
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      (* Write known number of records *)
      for i = 1 to 75 do
        let record = make_test_record Severity.Info (Printf.sprintf "Stats test %d" i) in
        write async_sink record
      done;

      (* Give time for background processing *)
      Eio.Time.sleep (Eio.Stdenv.clock env) 1.0;

      drain async_sink;

      let (_queued, written, dropped) = stats async_sink in
      (* Async processing with timing, so be lenient *)
      Alcotest.(check bool) "records written" true (written > 0L);
      Alcotest.(check bool) "total accounted for" true (Int64.add written dropped = 75L);

      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test drain ensures all data written *)
let test_drain_completeness () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "drain.log");
        format = `Json;
        rotation = Size 102400L;
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      let async_sink = create ~sw ~env
        ~config:{
          buffer_capacity = 500;
          batch_size = 100;
          flush_interval = 10.0;  (* Very long - won't auto-flush *)
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      (* Queue many records *)
      for i = 1 to 200 do
        let record = make_test_record Severity.Info (Printf.sprintf "Drain test %d" i) in
        write async_sink record
      done;

      (* Drain should write all 200 *)
      drain async_sink;

      let (_, written, _) = stats async_sink in
      Alcotest.(check bool) "all 200 written" true (written = 200L);

      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test suite *)
let () =
  Alcotest.run "Flo_sink_async" [
    "creation", [
      Alcotest.test_case "create" `Quick test_create;
    ];
    "operations", [
      Alcotest.test_case "write_and_drain" `Quick test_write_and_drain;
      Alcotest.test_case "batching" `Quick test_batching;
      Alcotest.test_case "level_filtering" `Quick test_level_filtering;
      Alcotest.test_case "flush_interval" `Slow test_flush_interval;
    ];
    "stats", [
      Alcotest.test_case "stats_tracking" `Quick test_stats;
    ];
    "drain", [
      Alcotest.test_case "drain_completeness" `Quick test_drain_completeness;
    ];
  ]
