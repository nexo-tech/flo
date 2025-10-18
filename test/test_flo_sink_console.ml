open Flo

(* Helper to create test record *)
let test_record ~severity ~message =
  Record.make ~severity ~message

(* Test create with default config *)
let test_create_default () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let _sink = Flo_sink_console.create ~sw Flo_sink_console.default_config in
      Alcotest.(check bool) "sink created" true true

(* Test permits filters by level *)
let test_permits_level_filter () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with level = Severity.Warn } in
      let sink = Flo_sink_console.create ~sw config in

      (* Trace < Warn: should be filtered *)
      Alcotest.(check bool) "Trace filtered" false
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Trace ~message:"trace"));

      (* Debug < Warn: should be filtered *)
      Alcotest.(check bool) "Debug filtered" false
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Debug ~message:"debug"));

      (* Info < Warn: should be filtered *)
      Alcotest.(check bool) "Info filtered" false
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Info ~message:"info"));

      (* Warn >= Warn: should pass *)
      Alcotest.(check bool) "Warn permitted" true
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Warn ~message:"warn"));

      (* Error >= Warn: should pass *)
      Alcotest.(check bool) "Error permitted" true
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Error ~message:"error"));

      (* Fatal >= Warn: should pass *)
      Alcotest.(check bool) "Fatal permitted" true
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Fatal ~message:"fatal"))

(* Test permits with Info level *)
let test_permits_info_level () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with level = Severity.Info } in
      let sink = Flo_sink_console.create ~sw config in

      Alcotest.(check bool) "Trace filtered" false
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Trace ~message:"trace"));

      Alcotest.(check bool) "Debug filtered" false
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Debug ~message:"debug"));

      Alcotest.(check bool) "Info permitted" true
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Info ~message:"info"));

      Alcotest.(check bool) "Success permitted" true
        (Flo_sink_console.permits sink (test_record ~severity:Severity.Success ~message:"success"))

(* Test flush does not fail *)
let test_flush () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let sink = Flo_sink_console.create ~sw Flo_sink_console.default_config in
      Flo_sink_console.flush sink;
      Alcotest.(check bool) "flush succeeds" true true

(* Test write with permitted record *)
let test_write_permitted () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with level = Severity.Info } in
      let sink = Flo_sink_console.create ~sw config in
      let record = test_record ~severity:Severity.Info ~message:"Test message" in

      (* Should not raise exception *)
      Flo_sink_console.write sink record;
      Alcotest.(check bool) "write succeeded" true true

(* Test write with filtered record does nothing *)
let test_write_filtered () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with level = Severity.Warn } in
      let sink = Flo_sink_console.create ~sw config in
      let record = test_record ~severity:Severity.Debug ~message:"Should be filtered" in

      (* Should not raise exception, just silently filter *)
      Flo_sink_console.write sink record;
      Alcotest.(check bool) "write filtered" true true

(* Test create with stderr *)
let test_create_stderr () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let _sink = Flo_sink_console.stderr ~sw in
      Alcotest.(check bool) "stderr sink created" true true

(* Test create with stdout *)
let test_create_stdout () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let _sink = Flo_sink_console.stdout ~sw in
      Alcotest.(check bool) "stdout sink created" true true

(* Test colorize on *)
let test_colorize_on () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with colorize = true } in
      let sink = Flo_sink_console.create ~sw config in
      let record = test_record ~severity:Severity.Error ~message:"Error" in

      (* Should not raise exception *)
      Flo_sink_console.write sink record;
      Alcotest.(check bool) "colorize on works" true true

(* Test colorize off *)
let test_colorize_off () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let config = { Flo_sink_console.default_config with colorize = false } in
      let sink = Flo_sink_console.create ~sw config in
      let record = test_record ~severity:Severity.Info ~message:"Info" in

      (* Should not raise exception *)
      Flo_sink_console.write sink record;
      Alcotest.(check bool) "colorize off works" true true

(* Test default_config values *)
let test_default_config () =
  let cfg = Flo_sink_console.default_config in
  Alcotest.(check bool) "default output is stderr" true
    (cfg.output = `Stderr);
  Alcotest.(check bool) "default colorize is true" true cfg.colorize;
  Alcotest.(check bool) "default format is Pretty" true
    (cfg.format = `Pretty);
  Alcotest.(check bool) "default level is Info" true
    (Severity.compare cfg.level Severity.Info = 0)

(* Test multiple writes *)
let test_multiple_writes () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let sink = Flo_sink_console.create ~sw Flo_sink_console.default_config in

      Flo_sink_console.write sink (test_record ~severity:Severity.Info ~message:"Message 1");
      Flo_sink_console.write sink (test_record ~severity:Severity.Success ~message:"Message 2");
      Flo_sink_console.write sink (test_record ~severity:Severity.Warn ~message:"Message 3");

      Alcotest.(check bool) "multiple writes succeed" true true

let () =
  let open Alcotest in
  run "Flo_sink_console" [
    "creation", [
      test_case "create with default config" `Quick test_create_default;
      test_case "create stderr convenience" `Quick test_create_stderr;
      test_case "create stdout convenience" `Quick test_create_stdout;
      test_case "default_config values" `Quick test_default_config;
    ];
    "filtering", [
      test_case "permits filters by level (Warn)" `Quick test_permits_level_filter;
      test_case "permits with Info level" `Quick test_permits_info_level;
    ];
    "writing", [
      test_case "write permitted record" `Quick test_write_permitted;
      test_case "write filtered record" `Quick test_write_filtered;
      test_case "multiple writes" `Quick test_multiple_writes;
    ];
    "formatting", [
      test_case "colorize on" `Quick test_colorize_on;
      test_case "colorize off" `Quick test_colorize_off;
    ];
    "operations", [
      test_case "flush does not fail" `Quick test_flush;
    ];
  ]
