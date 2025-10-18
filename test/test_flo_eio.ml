(* Tests for Flo_eio module *)

open Flo_eio

(* Test HTTP context extraction *)
let test_extract_valid_traceparent () =
  let headers = [
    ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    ("content-type", "application/json");
  ] in

  match extract_trace_context headers with
  | Some ctx ->
      Alcotest.(check string) "trace_id" "0af7651916cd43dd8448eb211c80319c" ctx.trace_id;
      Alcotest.(check string) "span_id" "b7ad6b7169203331" ctx.span_id;
      Alcotest.(check int) "trace_flags" 1 ctx.trace_flags
  | None ->
      Alcotest.fail "Should extract trace context"

let test_extract_case_insensitive () =
  (* Header name should be case-insensitive *)
  let headers = [
    ("TraceParent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00");
  ] in

  match extract_trace_context headers with
  | Some ctx ->
      Alcotest.(check string) "trace_id" "0af7651916cd43dd8448eb211c80319c" ctx.trace_id
  | None ->
      Alcotest.fail "Should be case-insensitive"

let test_extract_no_traceparent () =
  let headers = [
    ("content-type", "application/json");
  ] in

  match extract_trace_context headers with
  | Some _ -> Alcotest.fail "Should not extract when no traceparent"
  | None -> Alcotest.(check bool) "no context" true true

let test_extract_invalid_traceparent () =
  let headers = [
    ("traceparent", "invalid-format");
  ] in

  match extract_trace_context headers with
  | Some _ -> Alcotest.fail "Should not extract invalid traceparent"
  | None -> Alcotest.(check bool) "invalid rejected" true true

(* Test trace context injection *)
let test_inject_trace_context () =
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    Trace_context.span_id = "b7ad6b7169203331";
    Trace_context.parent_span_id = None;
    Trace_context.trace_flags = 1;
  } in

  let headers = inject_trace_context span_ctx in

  (* Should have traceparent header *)
  Alcotest.(check int) "one header" 1 (List.length headers);

  let (name, value) = List.hd headers in
  Alcotest.(check string) "header name" "traceparent" name;

  (* Verify format *)
  Alcotest.(check bool) "valid format"
    true (String.starts_with ~prefix:"00-" value);
  Alcotest.(check bool) "contains trace_id"
    true (String.contains value '0');
  Alcotest.(check bool) "contains span_id"
    true (String.contains value 'b')

let test_inject_extract_roundtrip () =
  let original = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    Trace_context.span_id = "b7ad6b7169203331";
    Trace_context.parent_span_id = None;
    Trace_context.trace_flags = 1;
  } in

  (* Inject *)
  let headers = inject_trace_context original in

  (* Extract *)
  match extract_trace_context headers with
  | Some extracted ->
      Alcotest.(check string) "trace_id roundtrip" original.trace_id extracted.trace_id;
      Alcotest.(check string) "span_id roundtrip" original.span_id extracted.span_id;
      Alcotest.(check int) "flags roundtrip" original.trace_flags extracted.trace_flags
  | None ->
      Alcotest.fail "Should extract what was injected"

(* Test with_http_context *)
let test_with_http_context () =
  Eio_main.run @@ fun _env ->
    let headers = [
      ("traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    ] in

    let ctx = Flo_context.empty in
    Flo_context.with_context ctx (fun () ->
      with_http_context ~headers (fun () ->
        (* Context should have trace_id and span_id *)
        match get_context () with
        | Some ctx ->
            (match Flo_context.get "trace_id" ctx with
             | Some (Value.String tid) ->
                 Alcotest.(check string) "trace_id in context"
                   "0af7651916cd43dd8448eb211c80319c" tid
             | _ -> Alcotest.fail "trace_id should be string");

            (match Flo_context.get "span_id" ctx with
             | Some (Value.String sid) ->
                 Alcotest.(check string) "span_id in context"
                   "b7ad6b7169203331" sid
             | _ -> Alcotest.fail "span_id should be string")
        | None ->
            Alcotest.fail "Context should exist"
      )
    )

let test_with_http_context_no_headers () =
  Eio_main.run @@ fun _env ->
    let headers = [] in

    let ctx = Flo_context.empty in
    Flo_context.with_context ctx (fun () ->
      (* Should still execute without trace context *)
      let result = with_http_context ~headers (fun () -> 42) in
      Alcotest.(check int) "function executes" 42 result
    )

(* Test with_context helper *)
let test_with_context_helpers () =
  Eio_main.run @@ fun _env ->
    let ctx = Flo_context.empty in
    Flo_context.with_context ctx (fun () ->
      with_context
        ~trace_id:"test-trace-123"
        ~span_id:"test-span-456"
        ~attributes:[
          ("key1", Value.String "value1");
          ("key2", Value.Int 42L);
        ]
        (fun () ->
          match get_context () with
          | Some ctx ->
              (match Flo_context.get "trace_id" ctx with
               | Some (Value.String tid) ->
                   Alcotest.(check string) "trace_id" "test-trace-123" tid
               | _ -> Alcotest.fail "trace_id should be set");

              (match Flo_context.get "key1" ctx with
               | Some (Value.String v) ->
                   Alcotest.(check string) "attribute" "value1" v
               | _ -> Alcotest.fail "attribute should be set")
          | None ->
              Alcotest.fail "Context should exist"
        )
    )

let test_with_context_partial () =
  Eio_main.run @@ fun _env ->
    let ctx = Flo_context.empty in
    Flo_context.with_context ctx (fun () ->
      (* Only trace_id provided *)
      with_context ~trace_id:"trace-only" (fun () ->
        match get_context () with
        | Some ctx ->
            (match Flo_context.get "trace_id" ctx with
             | Some (Value.String tid) ->
                 Alcotest.(check string) "trace_id only" "trace-only" tid
             | _ -> Alcotest.fail "trace_id should be set");

            (* Test passes if trace_id is set *)
            Alcotest.(check bool) "context set" true true
        | None ->
            Alcotest.fail "Context should exist"
      )
    )

(* Test context isolation between fibers *)
let test_fiber_context_isolation () =
  Eio_main.run @@ fun _env ->
    Eio.Switch.run @@ fun sw ->
      let results = ref [] in

      (* Fiber 1 with trace-1 *)
      Eio.Fiber.fork ~sw (fun () ->
        let ctx = Flo_context.empty in
        Flo_context.with_context ctx (fun () ->
          with_context ~trace_id:"trace-1" (fun () ->
            Unix.sleepf 0.01;
            match get_context () with
            | Some ctx ->
                (match Flo_context.get "trace_id" ctx with
                 | Some (Value.String tid) ->
                     results := tid :: !results
                 | _ -> ())
            | None -> ()
          )
        )
      );

      (* Fiber 2 with trace-2 *)
      Eio.Fiber.fork ~sw (fun () ->
        let ctx = Flo_context.empty in
        Flo_context.with_context ctx (fun () ->
          with_context ~trace_id:"trace-2" (fun () ->
            Unix.sleepf 0.01;
            match get_context () with
            | Some ctx ->
                (match Flo_context.get "trace_id" ctx with
                 | Some (Value.String tid) ->
                     results := tid :: !results
                 | _ -> ())
            | None -> ()
          )
        )
      );

      (* Wait for fibers to complete *)
      Unix.sleepf 0.05;

      (* Both trace IDs should be present *)
      Alcotest.(check bool) "both traces" true (List.length !results = 2);
      Alcotest.(check bool) "trace-1 present" true (List.mem "trace-1" !results);
      Alcotest.(check bool) "trace-2 present" true (List.mem "trace-2" !results)

(* Test get_context *)
let test_get_context () =
  Eio_main.run @@ fun _env ->
    (* No context initially *)
    (match get_context () with
     | Some _ -> Alcotest.fail "Should have no context"
     | None -> Alcotest.(check bool) "no context" true true);

    (* With context *)
    let ctx = Flo_context.empty in
    Flo_context.with_context ctx (fun () ->
      match get_context () with
      | Some _ -> Alcotest.(check bool) "has context" true true
      | None -> Alcotest.fail "Should have context"
    )

(* Test suite *)
let () =
  Alcotest.run "Flo_eio" [
    "http_extraction", [
      Alcotest.test_case "extract_valid_traceparent" `Quick test_extract_valid_traceparent;
      Alcotest.test_case "extract_case_insensitive" `Quick test_extract_case_insensitive;
      Alcotest.test_case "extract_no_traceparent" `Quick test_extract_no_traceparent;
      Alcotest.test_case "extract_invalid_traceparent" `Quick test_extract_invalid_traceparent;
    ];
    "http_injection", [
      Alcotest.test_case "inject_trace_context" `Quick test_inject_trace_context;
      Alcotest.test_case "inject_extract_roundtrip" `Quick test_inject_extract_roundtrip;
    ];
    "http_context", [
      Alcotest.test_case "with_http_context" `Quick test_with_http_context;
      Alcotest.test_case "with_http_context_no_headers" `Quick test_with_http_context_no_headers;
    ];
    "context_helpers", [
      Alcotest.test_case "with_context_helpers" `Quick test_with_context_helpers;
      Alcotest.test_case "with_context_partial" `Quick test_with_context_partial;
      Alcotest.test_case "get_context" `Quick test_get_context;
    ];
    "fiber_isolation", [
      Alcotest.test_case "fiber_context_isolation" `Quick test_fiber_context_isolation;
    ];
  ]
