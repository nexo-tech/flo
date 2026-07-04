open Flo

(* Test basic logging functions *)
let test_basic_logging () =
  Eio_main.run @@ fun _env ->
    (* Just test that they don't crash *)
    Flo.trace "trace message";
    Flo.debug "debug message";
    Flo.info "info message";
    Flo.success "success message";
    Flo.warn "warn message";
    Flo.error "error message";
    Flo.fatal "fatal message";
    Alcotest.(check bool) "basic logging works" true true

(* Test printf-style logging *)
let test_printf_logging () =
  Eio_main.run @@ fun _env ->
    Flo.tracef "trace %d" 1;
    Flo.debugf "debug %s" "test";
    Flo.infof "info %d %s" 42 "items";
    Flo.successf "success %.2f" 3.14;
    Flo.warnf "warn %b" true;
    Flo.errorf "error %d" 500;
    Flo.fatalf "fatal %s" "error";
    Alcotest.(check bool) "printf logging works" true true

(* Test info_fields structured logging *)
let test_info_fields () =
  Eio_main.run @@ fun _env ->
    Flo.info_fields "HTTP request" ~fields:[
      Flo.http_method "POST";
      Flo.http_status 201;
      Flo.duration_ms 42.5;
    ];
    Alcotest.(check bool) "info_fields works" true true

(* Test semantic convention helpers *)
let test_semantic_conventions () =
  let (k, v) = Flo.http_method "GET" in
  Alcotest.(check string) "http_method key" "http.method" k;
  (match v with
   | Value.String s -> Alcotest.(check string) "http_method value" "GET" s
   | _ -> Alcotest.fail "expected String");

  let (k, v) = Flo.http_status 200 in
  Alcotest.(check string) "http_status key" "http.status_code" k;
  (match v with
   | Value.Int i -> Alcotest.(check int64) "http_status value" 200L i
   | _ -> Alcotest.fail "expected Int");

  let (k, _v) = Flo.user_id "alice" in
  Alcotest.(check string) "user_id key" "user.id" k;

  let (k, _v) = Flo.duration_ms 123.45 in
  Alcotest.(check string) "duration_ms key" "duration_ms" k;

  let (k, _v) = Flo.error_type "ValueError" in
  Alcotest.(check string) "error_type key" "error.type" k;

  let (k, _v) = Flo.error_message "something failed" in
  Alcotest.(check string) "error_message key" "error.message" k

(* Test with_trace_id *)
let test_with_trace_id () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "test-trace-id-123" (fun () ->
      match Flo.get_trace_id () with
      | Some id -> Alcotest.(check string) "trace_id set" "test-trace-id-123" id
      | None -> Alcotest.fail "trace_id not found"
    );

    (* Outside context, should be None *)
    match Flo.get_trace_id () with
    | Some _ -> Alcotest.fail "trace_id should be None outside context"
    | None -> ()

(* Test with_span *)
let test_with_span () =
  Eio_main.run @@ fun _env ->
    Flo.with_span "test_operation" (fun () ->
      (* Should have trace_id and span_id *)
      let trace_id = Flo.get_trace_id () in
      let span_id = Flo.get_span_id () in

      Alcotest.(check bool) "has trace_id" true (Option.is_some trace_id);
      Alcotest.(check bool) "has span_id" true (Option.is_some span_id);

      match (trace_id, span_id) with
      | (Some tid, Some sid) ->
          Alcotest.(check int) "trace_id length" 32 (String.length tid);
          Alcotest.(check int) "span_id length" 16 (String.length sid)
      | _ -> ()
    )

(* Test with_user *)
let test_with_user () =
  Eio_main.run @@ fun _env ->
    Flo.with_user "alice" (fun () ->
      match Flo_context.get_current () with
      | Some ctx ->
          (match Flo_context.get "user_id" ctx with
           | Some (Value.String s) -> Alcotest.(check string) "user_id set" "alice" s
           | _ -> Alcotest.fail "user_id wrong type")
      | None -> Alcotest.fail "no context"
    )

(* Test get_trace_id and get_span_id return None without context *)
let test_get_context_no_context () =
  Eio_main.run @@ fun _env ->
    Alcotest.(check (option string)) "no trace_id" None (Flo.get_trace_id ());
    Alcotest.(check (option string)) "no span_id" None (Flo.get_span_id ())

(* Test catch returns Some on success *)
let test_catch_success () =
  Eio_main.run @@ fun _env ->
    let result = Flo.catch (fun () -> 42) in
    Alcotest.(check (option int)) "catch success returns Some" (Some 42) result

(* Test catch returns None on exception *)
let test_catch_exception () =
  Eio_main.run @@ fun _env ->
    let result = Flo.catch (fun () ->
      raise (Failure "test error")
    ) in
    Alcotest.(check (option int)) "catch exception returns None" None result

(* Test exception_ logs exception *)
let test_exception () =
  Eio_main.run @@ fun _env ->
    let exn = Failure "test exception" in
    Flo.exception_ exn;
    Alcotest.(check bool) "exception_ works" true true

(* Test set_level and get_level *)
let test_set_get_level () =
  let original = Flo.get_level () in

  Flo.set_level Severity.Warn;
  Alcotest.(check bool) "level set to Warn" true
    (Severity.compare (Flo.get_level ()) Severity.Warn = 0);

  Flo.set_level Severity.Debug;
  Alcotest.(check bool) "level set to Debug" true
    (Severity.compare (Flo.get_level ()) Severity.Debug = 0);

  (* Restore original *)
  Flo.set_level original

let test_logs_reporter_smoke () =
  let original_level = Flo.get_level () in
  Flo.set_level Severity.Debug;
  Flo.install_logs_reporter ();
  let src = Logs.Src.create "test.logs_bridge" in
  let module Log = (val Logs.src_log src : Logs.LOG) in
  let request_id_tag =
    Logs.Tag.def "request_id" Format.pp_print_string
  in
  let tags =
    Logs.Tag.(empty |> add request_id_tag "req-123")
  in
  Log.info (fun log -> log ~tags "bridged %d" 1);
  Flo.set_level original_level;
  Alcotest.(check bool) "logs reporter works" true true

(* Test nested context with with_span *)
let test_nested_span () =
  Eio_main.run @@ fun _env ->
    Flo.with_trace_id "outer-trace" (fun () ->
      Flo.with_span "inner_span" (fun () ->
        (* Should preserve outer trace_id *)
        let tid = Flo.get_trace_id () in
        Alcotest.(check bool) "has trace_id" true (Option.is_some tid);
        (match tid with
         | Some id -> Alcotest.(check string) "preserves trace_id" "outer-trace" id
         | None -> ());

        (* Should have new span_id *)
        let sid = Flo.get_span_id () in
        Alcotest.(check bool) "has span_id" true (Option.is_some sid)
      )
    )

let () =
  let open Alcotest in
  run "Flo" [
    "basic_logging", [
      test_case "basic logging functions" `Quick test_basic_logging;
      test_case "printf-style logging" `Quick test_printf_logging;
    ];
    "structured_logging", [
      test_case "info_fields with structured fields" `Quick test_info_fields;
      test_case "semantic convention helpers" `Quick test_semantic_conventions;
    ];
    "context_propagation", [
      test_case "with_trace_id sets trace context" `Quick test_with_trace_id;
      test_case "with_span creates span context" `Quick test_with_span;
      test_case "with_user sets user context" `Quick test_with_user;
      test_case "get context without context returns None" `Quick test_get_context_no_context;
      test_case "nested span preserves trace_id" `Quick test_nested_span;
    ];
    "exception_handling", [
      test_case "catch returns Some on success" `Quick test_catch_success;
      test_case "catch returns None on exception" `Quick test_catch_exception;
      test_case "exception_ logs exception" `Quick test_exception;
    ];
    "configuration", [
      test_case "set_level and get_level" `Quick test_set_get_level;
      test_case "Logs reporter smoke" `Quick test_logs_reporter_smoke;
    ];
  ]
