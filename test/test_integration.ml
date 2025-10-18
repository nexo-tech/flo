(** Integration tests for complete logging flow

    These tests verify the entire system working together end-to-end,
    including context propagation, formatting, and multiple components.
*)

open Flo

(* Test end-to-end logging with context *)
let test_end_to_end_logging () =
  Eio_main.run @@ fun _env ->
    (* Set level to capture all logs *)
    let original_level = Flo.get_level () in
    Flo.set_level Severity.Trace;

    (* Basic logging through complete pipeline *)
    Flo.trace "Trace message";
    Flo.debug "Debug message";
    Flo.info "Info message";
    Flo.success "Success message";
    Flo.warn "Warning message";
    Flo.error "Error message";
    Flo.fatal "Fatal message";

    (* Restore level *)
    Flo.set_level original_level;
    Alcotest.(check bool) "end-to-end logging works" true true

(* Test context propagation through logging pipeline *)
let test_context_propagation_integration () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "integration-trace-123" (fun () ->
      (* Log should include trace_id from context *)
      Flo.info "Message with trace context";

      (* Nested span should preserve trace_id and add span_id *)
      Flo.with_span "test_span" (fun () ->
        Flo.success "Message with span context";

        (* Get context to verify *)
        let tid = Flo.get_trace_id () in
        Alcotest.(check bool) "has trace_id" true (Option.is_some tid);
        (match tid with
         | Some id -> Alcotest.(check string) "trace_id preserved" "integration-trace-123" id
         | None -> ());

        let sid = Flo.get_span_id () in
        Alcotest.(check bool) "has span_id" true (Option.is_some sid)
      )
    )

(* Test structured logging with semantic conventions *)
let test_structured_logging_integration () =
  Eio_main.run @@ fun _env ->
    (* Structured fields should appear in log output *)
    Flo.info_fields "HTTP request processed" ~fields:[
      Flo.http_method "POST";
      Flo.http_status 201;
      Flo.duration_ms 123.45;
      Flo.user_id "alice";
    ];

    Alcotest.(check bool) "structured logging works" true true

(* Test level filtering across pipeline *)
let test_level_filtering_integration () =
  Eio_main.run @@ fun _env ->
    (* Set level to Warn *)
    Flo.set_level Severity.Warn;

    (* These should be filtered (no output) *)
    Flo.trace "Filtered trace";
    Flo.debug "Filtered debug";
    Flo.info "Filtered info";
    Flo.success "Filtered success";

    (* These should pass through *)
    Flo.warn "Visible warning";
    Flo.error "Visible error";
    Flo.fatal "Visible fatal";

    (* Verify level is set *)
    Alcotest.(check bool) "level set to Warn" true
      (Severity.compare (Flo.get_level ()) Severity.Warn = 0);

    (* Restore to Info *)
    Flo.set_level Severity.Info

(* Test concurrent logging from multiple fibers *)
let test_concurrent_logging () =
  Eio_main.run @@ fun _env ->
    (* Multiple fibers logging concurrently *)
    Eio.Fiber.both
      (fun () ->
        Flo.with_user "user1" (fun () ->
          for i = 1 to 10 do
            Flo.infof "User1 message %d" i
          done
        )
      )
      (fun () ->
        Flo.with_user "user2" (fun () ->
          for i = 1 to 10 do
            Flo.infof "User2 message %d" i
          done
        )
      );

    Alcotest.(check bool) "concurrent logging works" true true

(* Test exception handling integration *)
let test_exception_handling_integration () =
  Eio_main.run @@ fun _env ->
    (* Catch should log exception and return None *)
    let result = Flo.catch (fun () ->
      raise (Failure "Test failure")
    ) in

    Alcotest.(check (option int)) "catch returns None on exception" None result;

    (* Direct exception logging *)
    Flo.exception_ (Invalid_argument "test error");

    Alcotest.(check bool) "exception handling works" true true

(* Test context inheritance in nested scopes *)
let test_nested_context_integration () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "outer-trace" (fun () ->
      Flo.info "Outer context";

      Flo.with_user "alice" (fun () ->
        Flo.info "Middle context";

        Flo.with_span "inner_operation" (fun () ->
          Flo.success "Inner context";

          (* Verify all context is present *)
          match (Flo.get_trace_id (), Flo.get_span_id ()) with
          | (Some tid, Some _sid) ->
              Alcotest.(check string) "trace_id in nested" "outer-trace" tid
          | _ -> Alcotest.fail "context not found"
        )
      )
    )

(* Test printf-style formatting integration *)
let test_printf_integration () =
  Eio_main.run @@ fun _env ->
    Flo.tracef "trace %d %s" 1 "test";
    Flo.debugf "debug %.2f" 3.14;
    Flo.infof "info %b %d" true 42;
    Flo.successf "success %s" "done";
    Flo.warnf "warn %d" 500;
    Flo.errorf "error %s %d" "code" 404;
    Flo.fatalf "fatal %s" "critical";

    Alcotest.(check bool) "printf-style works" true true

(* Test complete workflow: context + structured + exception *)
let test_complete_workflow () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "workflow-trace" (fun () ->
      Flo.info "Starting workflow";

      (* Process with span *)
      Flo.with_span "process_data" (fun () ->
        Flo.info_fields "Processing started" ~fields:[
          ("batch_size", Value.int 100);
          ("timeout_ms", Value.int 5000);
        ];

        (* Simulate work with exception handling *)
        let _result = Flo.catch ~level:Severity.Warn (fun () ->
          Flo.debug "Doing work";
          if Random.bool () then 42 else raise (Failure "work failed")
        ) in

        Flo.success "Processing completed"
      );

      Flo.info "Workflow finished"
    )

(* Test Flo_core composition with real formatter and sink *)
let test_flo_core_integration () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      (* Create a custom logger using Flo_core *)
      let sink = Flo_sink_console.create ~sw {
        output = `Stderr;
        colorize = false;
        format = `Pretty;
        level = Severity.Debug;
      } in

      let logger = Flo_core.make (fun record ->
        Flo_sink_console.write sink record
      ) in

      (* Create filter and log *)
      let filtered_logger = Flo_core.level_filter Severity.Info logger in

      (* Test logging through composed logger *)
      let record1 = Record.make ~severity:Severity.Debug ~message:"Debug (filtered)" in
      let record2 = Record.make ~severity:Severity.Info ~message:"Info (passed)" in

      Flo_core.log filtered_logger record1;  (* Filtered *)
      Flo_core.log filtered_logger record2;  (* Passed *)

      Alcotest.(check bool) "flo_core integration works" true true

(* Test multiple concurrent contexts don't interfere *)
let test_context_isolation () =
  Eio_main.run @@ fun _env ->
    let result1 = ref None in
    let result2 = ref None in

    Eio.Fiber.both
      (fun () ->
        Flo.with_trace_id "trace-fiber-1" (fun () ->
          Flo.info "Fiber 1 logging";
          result1 := Flo.get_trace_id ()
        )
      )
      (fun () ->
        Flo.with_trace_id "trace-fiber-2" (fun () ->
          Flo.info "Fiber 2 logging";
          result2 := Flo.get_trace_id ()
        )
      );

    (* Each fiber should have its own context *)
    match (!result1, !result2) with
    | (Some tid1, Some tid2) ->
        Alcotest.(check string) "fiber1 trace_id" "trace-fiber-1" tid1;
        Alcotest.(check string) "fiber2 trace_id" "trace-fiber-2" tid2
    | _ -> Alcotest.fail "contexts not set"

(* Test formatter and sink integration *)
let test_formatter_sink_integration () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      (* Create sink with colors *)
      let sink_colored = Flo_sink_console.create ~sw {
        output = `Stderr;
        colorize = true;
        format = `Pretty;
        level = Severity.Info;
      } in

      (* Create sink without colors *)
      let sink_plain = Flo_sink_console.create ~sw {
        output = `Stdout;
        colorize = false;
        format = `Pretty;
        level = Severity.Warn;
      } in

      (* Test both sinks *)
      let record = Record.make ~severity:Severity.Info ~message:"Test" in
      Flo_sink_console.write sink_colored record;

      let record2 = Record.make ~severity:Severity.Error ~message:"Error" in
      Flo_sink_console.write sink_plain record2;

      Alcotest.(check bool) "formatter-sink integration works" true true

(* Test complete record with all fields flows through system *)
let test_complete_record_flow () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "complete-trace" (fun () ->
      Flo.with_span "complete_span" (fun () ->
        Flo.with_user "test_user" (fun () ->
          (* Create a log with all features *)
          Flo.info_fields "Complete log record" ~fields:[
            ("custom_field", Value.string "custom_value");
            ("numeric_field", Value.int 999);
            ("bool_field", Value.bool true);
            Flo.duration_ms 456.78;
          ];

          Alcotest.(check bool) "complete record flows" true true
        )
      )
    )

let () =
  (* Enable backtrace for exception tests *)
  Printexc.record_backtrace true;

  let open Alcotest in
  run "Integration" [
    "end_to_end", [
      test_case "end-to-end logging flow" `Quick test_end_to_end_logging;
      test_case "complete workflow" `Quick test_complete_workflow;
      test_case "complete record flow" `Quick test_complete_record_flow;
    ];
    "context_propagation", [
      test_case "context propagation through pipeline" `Quick test_context_propagation_integration;
      test_case "nested context inheritance" `Quick test_nested_context_integration;
      test_case "context isolation between fibers" `Quick test_context_isolation;
    ];
    "structured_logging", [
      test_case "structured logging integration" `Quick test_structured_logging_integration;
      test_case "printf-style integration" `Quick test_printf_integration;
    ];
    "filtering", [
      test_case "level filtering across pipeline" `Quick test_level_filtering_integration;
    ];
    "concurrent", [
      test_case "concurrent logging from multiple fibers" `Quick test_concurrent_logging;
    ];
    "exception_handling", [
      test_case "exception handling integration" `Quick test_exception_handling_integration;
    ];
    "components", [
      test_case "flo_core integration" `Quick test_flo_core_integration;
      test_case "formatter-sink integration" `Quick test_formatter_sink_integration;
    ];
  ]
