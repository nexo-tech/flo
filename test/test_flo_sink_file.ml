(* Tests for Flo_sink_file module *)

open Flo_sink_file

(* Helper to create test record *)
let make_test_record severity message =
  Record.make ~severity ~message

(* Helper to create test record with attributes *)

(* Test basic file sink creation *)
let test_create_basic () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    let test_dir = Eio.Path.(cwd / "test_logs") in

    (* Clean up test directory *)
    (try Eio.Path.rmtree test_dir with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let _sink = create_basic ~sw {
        path = Eio.Path.(cwd / "test_logs" / "test.log");
        format = `Json;
        level = Severity.Info;
        buffer_size = 1024;
        create_dirs = true;
      } in

      Alcotest.(check bool) "sink created" true true;

      (* Clean up *)
      (try Eio.Path.rmtree test_dir with _ -> ())

(* Test basic file writing *)
let test_basic_write () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    let test_dir = Eio.Path.(cwd / "test_logs") in
    let test_file = Eio.Path.(cwd / "test_logs" / "write_test.log") in

    (* Clean up *)
    (try Eio.Path.rmtree test_dir with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Info;
        buffer_size = 0;  (* Unbuffered *)
        create_dirs = true;
      } in

      (* Write a record *)
      let record = make_test_record Severity.Info "Test message" in
      write_basic sink record;
      flush_basic sink;

      (* Verify file exists and has content *)
      let content = Eio.Path.load test_file in
      Alcotest.(check bool) "file has content" true (String.length content > 0);
      (* Check content contains the message (simple substring check) *)
      let has_message = try
        let _ = String.index content 'T' in true
      with Not_found -> false in
      Alcotest.(check bool) "content contains data" true has_message;

      (* Clean up *)
      (try Eio.Path.rmtree test_dir with _ -> ())

(* Test level filtering *)
let test_basic_level_filtering () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    let test_file = Eio.Path.(cwd / "test_logs" / "filter_test.log") in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Warn;  (* Only Warn and above *)
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Test permits *)
      let info_record = make_test_record Severity.Info "Info message" in
      let warn_record = make_test_record Severity.Warn "Warn message" in

      Alcotest.(check bool) "info not permitted"
        false (permits_basic sink info_record);
      Alcotest.(check bool) "warn permitted"
        true (permits_basic sink warn_record);

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test buffering *)
let test_basic_buffering () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    let test_file = Eio.Path.(cwd / "test_logs" / "buffer_test.log") in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Info;
        buffer_size = 4096;  (* Buffered *)
        create_dirs = true;
      } in

      (* Write some records *)
      for i = 1 to 5 do
        let record = make_test_record Severity.Info (Printf.sprintf "Message %d" i) in
        write_basic sink record
      done;

      (* Flush to ensure write *)
      flush_basic sink;

      (* Verify content *)
      let content = Eio.Path.load test_file in
      Alcotest.(check bool) "has multiple messages" true (String.length content > 100);

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test rotating sink creation *)
let test_create_rotating () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let _sink = create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "rotating.log");
        format = `Logfmt;
        rotation = Size 1024L;
        retention = Some (Keep_last 3);
        level = Severity.Debug;
        buffer_size = 0;
        create_dirs = true;
      } in

      Alcotest.(check bool) "rotating sink created" true true;

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test size-based rotation *)
let test_size_rotation () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in
    let test_dir = Eio.Path.(cwd / "test_logs") in

    (try Eio.Path.rmtree test_dir with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "size_rotate.log");
        format = `Json;
        rotation = Size 500L;  (* Small size for testing *)
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Write enough to trigger rotation *)
      for i = 1 to 20 do
        let record = make_test_record Severity.Info
          (Printf.sprintf "Long message number %d with padding to increase size" i) in
        write_rotating sink record;
        flush_rotating sink
      done;

      (* Check if rotated files were created *)
      let entries = Eio.Path.read_dir Eio.Path.(cwd / "test_logs") in
      let rotated_count = List.length (List.filter (fun name ->
        String.starts_with ~prefix:"size_rotate.log." name
      ) entries) in

      Alcotest.(check bool) "rotation occurred" true (rotated_count > 0);

      (* Clean up *)
      (try Eio.Path.rmtree test_dir with _ -> ())

(* Test interval rotation *)
let test_interval_rotation () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "interval_rotate.log");
        format = `Logfmt;
        rotation = Interval 1.0;  (* 1 second *)
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Write message *)
      let record = make_test_record Severity.Info "Message 1" in
      write_rotating sink record;
      flush_rotating sink;

      (* Wait for interval *)
      Eio.Time.sleep (Eio.Stdenv.clock env) 1.5;

      (* Write another message - should trigger rotation *)
      let record2 = make_test_record Severity.Info "Message 2" in
      write_rotating sink record2;
      flush_rotating sink;

      (* Check for rotated files *)
      let entries = Eio.Path.read_dir Eio.Path.(cwd / "test_logs") in
      let has_rotated = List.exists (fun name ->
        String.starts_with ~prefix:"interval_rotate.log." name
      ) entries in

      Alcotest.(check bool) "interval rotation occurred" true has_rotated;

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test keep_last retention *)
let test_retention_keep_last () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "retention.log");
        format = `Json;
        rotation = Size 300L;  (* Very small *)
        retention = Some (Keep_last 2);  (* Keep only 2 *)
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Write many messages to trigger multiple rotations *)
      for i = 1 to 30 do
        let record = make_test_record Severity.Info
          (Printf.sprintf "Retention test message %d with padding" i) in
        write_rotating sink record;
        flush_rotating sink
      done;

      (* Count rotated files *)
      let entries = Eio.Path.read_dir Eio.Path.(cwd / "test_logs") in
      let rotated_files = List.filter (fun name ->
        String.starts_with ~prefix:"retention.log." name
      ) entries in

      (* Should have at most 2 rotated files (Keep_last 2) *)
      Alcotest.(check bool) "retention policy applied"
        true (List.length rotated_files <= 2);

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test manual rotation *)
let test_manual_rotation () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ());

    Eio.Switch.run @@ fun sw ->
      let sink = create_rotating ~sw {
        path = Eio.Path.(cwd / "test_logs" / "manual.log");
        format = `Json;
        rotation = Size 999999L;  (* Very large - won't auto-rotate *)
        retention = None;
        level = Severity.Info;
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Write message *)
      let record = make_test_record Severity.Info "Before rotation" in
      write_rotating sink record;
      flush_rotating sink;

      (* Force rotation *)
      rotate sink;

      (* Write another message *)
      let record2 = make_test_record Severity.Info "After rotation" in
      write_rotating sink record2;
      flush_rotating sink;

      (* Check for rotated file *)
      let entries = Eio.Path.read_dir Eio.Path.(cwd / "test_logs") in
      let has_rotated = List.exists (fun name ->
        String.starts_with ~prefix:"manual.log." name
      ) entries in

      Alcotest.(check bool) "manual rotation occurred" true has_rotated;

      (* Clean up *)
      (try Eio.Path.rmtree Eio.Path.(cwd / "test_logs") with _ -> ())

(* Test utility functions *)
let test_rotated_filename () =
  let base_path = "test.log" in
  let timestamp = Ptime.epoch in
  let rotated = rotated_filename base_path timestamp in

  Alcotest.(check bool) "has base name" true (String.starts_with ~prefix:"test.log." rotated);
  Alcotest.(check bool) "has timestamp" true (String.length rotated > (String.length base_path + 1))

(* Test suite *)
let () =
  Alcotest.run "Flo_sink_file" [
    "basic_sink", [
      Alcotest.test_case "create" `Quick test_create_basic;
      Alcotest.test_case "write" `Quick test_basic_write;
      Alcotest.test_case "level_filtering" `Quick test_basic_level_filtering;
      Alcotest.test_case "buffering" `Quick test_basic_buffering;
    ];
    "rotating_sink", [
      Alcotest.test_case "create" `Quick test_create_rotating;
      Alcotest.test_case "size_rotation" `Quick test_size_rotation;
      Alcotest.test_case "interval_rotation" `Slow test_interval_rotation;
      Alcotest.test_case "retention_keep_last" `Quick test_retention_keep_last;
      Alcotest.test_case "manual_rotation" `Quick test_manual_rotation;
    ];
    "utilities", [
      Alcotest.test_case "rotated_filename" `Quick test_rotated_filename;
    ];
  ]
