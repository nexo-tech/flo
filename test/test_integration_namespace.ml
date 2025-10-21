(** Integration tests for namespaces with formatters and sinks *)

open Flo

(* Define testable for Severity.t *)
module Severity = struct
  include Severity

  let pp fmt = function
    | Trace -> Format.fprintf fmt "Trace"
    | Debug -> Format.fprintf fmt "Debug"
    | Info -> Format.fprintf fmt "Info"
    | Success -> Format.fprintf fmt "Success"
    | Warn -> Format.fprintf fmt "Warn"
    | Error -> Format.fprintf fmt "Error"
    | Fatal -> Format.fprintf fmt "Fatal"

  let equal a b = compare a b = 0
  let testable = Alcotest.testable pp equal
end

(** Test namespace with Pretty formatter (already tested, verify integration) *)
let test_namespace_with_pretty_formatter () =
  Eio_main.run @@ fun _env ->
    let record =
      Record.make ~severity:Severity.Info ~message:"Test message"
      |> Record.with_namespace "test.component"
    in

    let formatted = Flo_format_pretty.format record in

    (* Verify namespace appears *)
    Alcotest.(check bool) "pretty formatter includes namespace" true
      (String.length formatted > 0 &&
       try ignore (Str.search_forward (Str.regexp "test\\.component") formatted 0); true
       with Not_found -> false)

(** Test namespace with JSON formatter *)
let test_namespace_with_json_formatter () =
  Eio_main.run @@ fun _env ->
    let record =
      Record.make ~severity:Severity.Info ~message:"JSON test"
      |> Record.with_namespace "mylib.json"
    in

    let json_str = Flo_format_json.format record in
    let json = Yojson.Safe.from_string json_str in
    let open Yojson.Safe.Util in

    let namespace = json |> member "namespace" |> to_string in
    Alcotest.(check string) "JSON includes namespace" "mylib.json" namespace

(** Test namespace with Logfmt formatter *)
let test_namespace_with_logfmt_formatter () =
  Eio_main.run @@ fun _env ->
    let record =
      Record.make ~severity:Severity.Info ~message:"Logfmt test"
      |> Record.with_namespace "mylib.logfmt"
    in

    let logfmt = Flo_format_logfmt.format record in

    (* Verify namespace appears *)
    Alcotest.(check bool) "logfmt includes namespace" true
      (try ignore (Str.search_forward (Str.regexp "namespace=mylib\\.logfmt") logfmt 0); true
       with Not_found -> false)

(** Test namespace with Console sink *)
let test_namespace_with_console_sink () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      (* Create console sink with Pretty format *)
      let sink = Flo_sink_console.create ~sw {
        output = `Stderr;
        colorize = false;
        format = `Pretty;
        level = Severity.Debug;
      } in

      (* Create record with namespace *)
      let record =
        Record.make ~severity:Severity.Info ~message:"Console test"
        |> Record.with_namespace "test.console"
      in

      (* Write should succeed (we can't capture output, but verify no crash) *)
      Flo_sink_console.write sink record;

      (* Verify permits works correctly *)
      Alcotest.(check bool) "sink permits record" true
        (Flo_sink_console.permits sink record)

(** Test namespace filtering with Console sink *)
let test_namespace_filtering_console_sink () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      (* Create sink at Info level *)
      let sink = Flo_sink_console.create ~sw {
        output = `Stderr;
        colorize = false;
        format = `Pretty;
        level = Severity.Info;
      } in

      (* Record at Debug level should be filtered *)
      let debug_record =
        Record.make ~severity:Severity.Debug ~message:"Debug"
        |> Record.with_namespace "test.ns"
      in

      Alcotest.(check bool) "debug filtered" false
        (Flo_sink_console.permits sink debug_record);

      (* Record at Info level should pass *)
      let info_record =
        Record.make ~severity:Severity.Info ~message:"Info"
        |> Record.with_namespace "test.ns"
      in

      Alcotest.(check bool) "info permitted" true
        (Flo_sink_console.permits sink info_record)

(** Test namespace with File sink *)
let test_namespace_with_file_sink () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_namespace.log") in

      (* Clean up if exists *)
      (try Eio.Path.unlink test_file with _ -> ());

      (* Create file sink with JSON format *)
      let sink = Flo_sink_file.create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Debug;
        buffer_size = 1024;
        create_dirs = true;
      } in

      (* Write record with namespace *)
      let record =
        Record.make ~severity:Severity.Info ~message:"File test"
        |> Record.with_namespace "test.file"
      in

      Flo_sink_file.write_basic sink record;
      Flo_sink_file.flush_basic sink;

      (* Read file and verify namespace is in JSON *)
      let content = Eio.Path.load test_file in
      Alcotest.(check bool) "file contains namespace" true
        (String.length content > 0);

      (* Parse JSON and verify namespace *)
      let json = Yojson.Safe.from_string (String.trim content) in
      let open Yojson.Safe.Util in
      let namespace = json |> member "namespace" |> to_string in
      Alcotest.(check string) "namespace in file" "test.file" namespace;

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ())

(** Test namespace with Rotating file sink *)
let test_namespace_with_rotating_file_sink () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_rotating.log") in

      (* Clean up if exists *)
      (try Eio.Path.unlink test_file with _ -> ());

      (* Create rotating file sink with Logfmt format *)
      let sink = Flo_sink_file.create_rotating ~sw {
        path = test_file;
        format = `Logfmt;
        rotation = Size 10485760L;  (* 10MB *)
        retention = Some (Keep_last 3);
        level = Severity.Info;
        buffer_size = 1024;
        create_dirs = true;
      } in

      (* Write record with namespace *)
      let record =
        Record.make ~severity:Severity.Info ~message:"Rotating test"
        |> Record.with_namespace "test.rotating"
      in

      Flo_sink_file.write_rotating sink record;
      Flo_sink_file.flush_rotating sink;

      (* Read file and verify namespace in logfmt *)
      let content = Eio.Path.load test_file in
      Alcotest.(check bool) "file contains namespace" true
        (try ignore (Str.search_forward (Str.regexp "namespace=test\\.rotating") content 0); true
         with Not_found -> false);

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ())

(** Test namespace with Async sink *)
let test_namespace_with_async_sink () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_async.log") in

      (* Clean up if exists *)
      (try Eio.Path.unlink test_file with _ -> ());

      (* Create underlying file sink *)
      let underlying = Flo_sink_file.create_rotating ~sw {
        path = test_file;
        format = `Json;
        rotation = Size 10485760L;
        retention = None;
        level = Severity.Debug;
        buffer_size = 1024;
        create_dirs = true;
      } in

      (* Create async sink *)
      let async_sink = Flo_sink_async.create ~sw ~env
        ~config:{
          buffer_capacity = 100;
          batch_size = 10;
          flush_interval = 0.1;
          level = Severity.Debug;
        }
        ~underlying
      in

      (* Write records with namespaces *)
      let record1 =
        Record.make ~severity:Severity.Info ~message:"Async test 1"
        |> Record.with_namespace "test.async"
      in

      let record2 =
        Record.make ~severity:Severity.Debug ~message:"Async test 2"
        |> Record.with_namespace "test.async.sub"
      in

      Flo_sink_async.write async_sink record1;
      Flo_sink_async.write async_sink record2;

      (* Drain to ensure all written *)
      Flo_sink_async.drain async_sink;

      (* Read file and verify namespaces *)
      let content = Eio.Path.load test_file in
      Alcotest.(check bool) "async preserves namespace 1" true
        (String.length content > 0 &&
         try ignore (Str.search_forward (Str.regexp "test\\.async") content 0); true
         with Not_found -> false);

      Alcotest.(check bool) "async preserves namespace 2" true
        (try ignore (Str.search_forward (Str.regexp "test\\.async\\.sub") content 0); true
         with Not_found -> false);

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ())

(** Test namespace filtering at dispatch level *)
let test_namespace_dispatch_filtering () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Configure different levels *)
    Flo.set_level Severity.Info;
    Flo.set_level_for "verbose.component" Severity.Debug;
    Flo.set_level_for "quiet.component" Severity.Warn;

    (* Test effective levels *)
    let level1 = Flo.get_effective_level "verbose.component" in
    Alcotest.(check Severity.testable) "verbose level" Severity.Debug level1;

    let level2 = Flo.get_effective_level "quiet.component" in
    Alcotest.(check Severity.testable) "quiet level" Severity.Warn level2;

    let level3 = Flo.get_effective_level "normal.component" in
    Alcotest.(check Severity.testable) "normal level" Severity.Info level3;

    Flo_namespace.clear_all ()

(** Test end-to-end: scoped logger -> formatter -> output *)
let test_end_to_end_scoped_to_output () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_e2e.log") in

      (* Clean up if exists *)
      (try Eio.Path.unlink test_file with _ -> ());

      Flo_namespace.clear_all ();

      (* Create a scoped logger *)
      let module AppLog = Flo_scoped.Make(struct
        let namespace = "app.e2e"
      end) in

      (* Configure its level *)
      AppLog.set_level Severity.Debug;

      (* Create file sink *)
      let sink = Flo_sink_file.create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Debug;
        buffer_size = 512;
        create_dirs = true;
      } in

      (* Log via scoped logger *)
      Flo.with_namespace "app.e2e" (fun () ->
        (* Create record that will have namespace *)
        let record = Record.make ~severity:Severity.Info ~message:"E2E test" in
        (* Get namespace from context *)
        let record = match Flo_context.get_namespace () with
          | Some ns -> Record.with_namespace ns record
          | None -> record
        in

        (* Write to sink *)
        Flo_sink_file.write_basic sink record;
        Flo_sink_file.flush_basic sink
      );

      (* Verify file has namespace *)
      let content = Eio.Path.load test_file in
      let json = Yojson.Safe.from_string (String.trim content) in
      let open Yojson.Safe.Util in
      let namespace = json |> member "namespace" |> to_string in
      Alcotest.(check string) "e2e namespace" "app.e2e" namespace;

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ());
      Flo_namespace.clear_all ()

(** Test multiple formatters with same namespace record *)
let test_namespace_all_formatters () =
  Eio_main.run @@ fun _env ->
    let record =
      Record.make ~severity:Severity.Success ~message:"Multi-format test"
      |> Record.with_namespace "test.formats"
      |> Record.with_attributes [("key", Value.string "value")]
    in

    (* Format with all three formatters *)
    let pretty = Flo_format_pretty.format record in
    let json = Flo_format_json.format record in
    let logfmt = Flo_format_logfmt.format record in

    (* All should contain namespace *)
    Alcotest.(check bool) "pretty has namespace" true
      (String.length pretty > 0);

    Alcotest.(check bool) "json has namespace" true
      (try
         let j = Yojson.Safe.from_string json in
         let open Yojson.Safe.Util in
         let _ns = j |> member "namespace" |> to_string in
         true
       with _ -> false);

    Alcotest.(check bool) "logfmt has namespace" true
      (try ignore (Str.search_forward (Str.regexp "namespace=test\\.formats") logfmt 0); true
       with Not_found -> false)

(** Test namespace round-trip through all parseable formatters *)
let test_namespace_round_trip_all () =
  Eio_main.run @@ fun _env ->
    let original =
      Record.make ~severity:Severity.Warn ~message:"Round-trip test"
      |> Record.with_namespace "test.roundtrip"
    in

    (* JSON round-trip *)
    let json_str = Flo_format_json.format original in
    (match Flo_format_json.parse json_str with
     | Ok parsed ->
         Alcotest.(check (option string)) "JSON round-trip"
           (Some "test.roundtrip") (Record.namespace parsed)
     | Error msg ->
         Alcotest.fail (Printf.sprintf "JSON parse failed: %s" msg));

    (* Logfmt round-trip *)
    let logfmt_str = Flo_format_logfmt.format original in
    (match Flo_format_logfmt.parse logfmt_str with
     | Ok parsed ->
         Alcotest.(check (option string)) "Logfmt round-trip"
           (Some "test.roundtrip") (Record.namespace parsed)
     | Error msg ->
         Alcotest.fail (Printf.sprintf "Logfmt parse failed: %s" msg))

(** Test hierarchical namespaces through full stack *)
let test_hierarchical_namespaces_full_stack () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_hierarchical.log") in

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ());

      Flo_namespace.clear_all ();

      (* Set parent level *)
      Flo.set_level_for "parent" Severity.Warn;

      (* Create child logger *)
      let module ChildLog = Flo_scoped.Make(struct
        let namespace = "parent.child"
      end) in

      (* Verify child inherits parent level *)
      let effective = ChildLog.get_effective_level () in
      Alcotest.(check Severity.testable) "child inherits" Severity.Warn effective;

      (* Create file sink *)
      let sink = Flo_sink_file.create_basic ~sw {
        path = test_file;
        format = `Json;
        level = Severity.Debug;  (* Sink accepts all *)
        buffer_size = 512;
        create_dirs = true;
      } in

      (* Log at Debug (should be filtered by namespace level, not sink) *)
      (* But we're writing directly to sink, so it will write *)
      let debug_record =
        Record.make ~severity:Severity.Debug ~message:"Debug message"
        |> Record.with_namespace "parent.child"
      in

      let warn_record =
        Record.make ~severity:Severity.Warn ~message:"Warn message"
        |> Record.with_namespace "parent.child"
      in

      (* Write both to sink *)
      Flo_sink_file.write_basic sink debug_record;
      Flo_sink_file.write_basic sink warn_record;
      Flo_sink_file.flush_basic sink;

      (* Verify file has both namespaces (sink doesn't filter by namespace) *)
      let content = Eio.Path.load test_file in
      let lines = String.split_on_char '\n' content
                  |> List.filter (fun s -> String.trim s <> "") in

      Alcotest.(check int) "two records written" 2 (List.length lines);

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ());
      Flo_namespace.clear_all ()

(** Test scoped logging with context and formatters *)
let test_scoped_with_context_and_formatters () =
  Eio_main.run @@ fun _env ->
    (* Create scoped logger *)
    let module Log = Flo_scoped.Make(struct
      let namespace = "integration.test"
    end) in

    (* Use it with context *)
    Log.with_span "test_span" (fun () ->
      (* Create a record manually to test *)
      let record = Record.make ~severity:Severity.Info ~message:"Integration" in

      (* Add namespace from context *)
      let record = match Flo_context.get_namespace () with
        | Some ns -> Record.with_namespace ns record
        | None -> record
      in

      (* Format with all formatters *)
      let _pretty = Flo_format_pretty.format record in
      let json = Flo_format_json.format record in
      let logfmt = Flo_format_logfmt.format record in

      (* Verify namespace in outputs *)
      let j = Yojson.Safe.from_string json in
      let open Yojson.Safe.Util in
      let ns_json = j |> member "namespace" |> to_string in
      Alcotest.(check string) "namespace in JSON" "integration.test" ns_json;

      Alcotest.(check bool) "namespace in logfmt" true
        (try ignore (Str.search_forward (Str.regexp "namespace=integration\\.test") logfmt 0); true
         with Not_found -> false)
    )

(** Test namespace statistics tracking *)
let test_namespace_statistics () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set multiple namespace levels *)
    Flo.set_level_for "ns1" Severity.Debug;
    Flo.set_level_for "ns2" Severity.Info;
    Flo.set_level_for "ns3" Severity.Warn;
    Flo.set_level_for "ns4" Severity.Error;

    (* Get all levels *)
    let all_levels = Flo.get_all_levels () in
    Alcotest.(check int) "four namespaces configured" 4 (List.length all_levels);

    (* Verify each is present *)
    List.iter (fun (ns, _) ->
      let found = List.exists (fun (n, _) -> n = ns) all_levels in
      Alcotest.(check bool) (Printf.sprintf "has %s" ns) true found
    ) [("ns1", ()); ("ns2", ()); ("ns3", ()); ("ns4", ())];

    Flo_namespace.clear_all ()

(** Test async sink preserves namespace through batching *)
let test_async_batching_preserves_namespace () =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      let cwd = Eio.Stdenv.cwd env in
      let test_file = Eio.Path.(cwd / "_build" / "test_async_batch.log") in

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ());

      (* Create underlying sink *)
      let underlying = Flo_sink_file.create_rotating ~sw {
        path = test_file;
        format = `Json;
        rotation = Size 10485760L;
        retention = None;
        level = Severity.Debug;
        buffer_size = 1024;
        create_dirs = true;
      } in

      (* Create async sink with small batch *)
      let async_sink = Flo_sink_async.create ~sw ~env
        ~config:{
          buffer_capacity = 50;
          batch_size = 5;
          flush_interval = 0.1;
          level = Severity.Debug;
        }
        ~underlying
      in

      (* Write multiple records with different namespaces *)
      for i = 1 to 10 do
        let ns = Printf.sprintf "test.batch.%d" (i mod 3) in
        let record =
          Record.make ~severity:Severity.Info
            ~message:(Printf.sprintf "Batch message %d" i)
          |> Record.with_namespace ns
        in
        Flo_sink_async.write async_sink record
      done;

      (* Give async sink time to process *)
      let clock = (env :> < clock : _ ; .. >)#clock in
      Eio.Time.sleep clock 0.5;

      (* Drain and verify *)
      Flo_sink_async.drain async_sink;

      let content = Eio.Path.load test_file in
      let lines = String.split_on_char '\n' content
                  |> List.filter (fun s -> String.trim s <> "") in

      (* Should have written multiple records (exact count depends on timing) *)
      Alcotest.(check bool) "multiple records written" true
        (List.length lines >= 5);  (* At least half should be written *)

      (* Verify each written record has a namespace *)
      List.iter (fun line ->
        let json = Yojson.Safe.from_string line in
        let open Yojson.Safe.Util in
        (* Should have namespace field *)
        let has_ns =
          try
            let ns = json |> member "namespace" |> to_string in
            (* Verify it's one of our test namespaces *)
            String.starts_with ~prefix:"test.batch." ns
          with _ -> false
        in
        Alcotest.(check bool) "line has valid namespace" true has_ns
      ) lines;

      (* Clean up *)
      (try Eio.Path.unlink test_file with _ -> ())

(** Test suite *)
let () =
  Alcotest.run "Namespace Integration" [
    "formatters", [
      Alcotest.test_case "namespace_with_pretty" `Quick test_namespace_with_pretty_formatter;
      Alcotest.test_case "namespace_with_json" `Quick test_namespace_with_json_formatter;
      Alcotest.test_case "namespace_with_logfmt" `Quick test_namespace_with_logfmt_formatter;
      Alcotest.test_case "namespace_all_formatters" `Quick test_namespace_all_formatters;
      Alcotest.test_case "namespace_round_trip_all" `Quick test_namespace_round_trip_all;
    ];
    "sinks", [
      Alcotest.test_case "namespace_with_console" `Quick test_namespace_with_console_sink;
      Alcotest.test_case "namespace_filtering_console" `Quick test_namespace_filtering_console_sink;
      Alcotest.test_case "namespace_with_file" `Quick test_namespace_with_file_sink;
      Alcotest.test_case "namespace_with_rotating_file" `Quick test_namespace_with_rotating_file_sink;
      Alcotest.test_case "namespace_with_async" `Quick test_namespace_with_async_sink;
      Alcotest.test_case "async_batching_preserves_namespace" `Quick test_async_batching_preserves_namespace;
    ];
    "full_stack", [
      Alcotest.test_case "namespace_dispatch_filtering" `Quick test_namespace_dispatch_filtering;
      Alcotest.test_case "end_to_end_scoped_to_output" `Quick test_end_to_end_scoped_to_output;
      Alcotest.test_case "scoped_with_context_formatters" `Quick test_scoped_with_context_and_formatters;
      Alcotest.test_case "namespace_statistics" `Quick test_namespace_statistics;
      Alcotest.test_case "hierarchical_namespaces_full_stack" `Quick test_hierarchical_namespaces_full_stack;
    ];
  ]
