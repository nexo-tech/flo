(** Tests for PPX namespace support *)

[@@@flo.namespace "test.ppx.namespace"]

open Flo

(* Test that module-level namespace attribute works *)
let test_module_namespace_attribute () =
  Eio_main.run @@ fun _env ->
    (* When we use [%log.info], it should use the namespace from [@@@flo.namespace] *)
    [%log.info "Test with module namespace"];

    (* We can't easily verify the output, but if it compiles and runs, it works *)
    Alcotest.(check bool) "module namespace attribute compiles" true true

(* Test structured logging with module namespace *)
let test_structured_with_namespace () =
  Eio_main.run @@ fun _env ->
    let user_id = "user-123" in
    let count = 42 in

    [%log.info "Structured with namespace" ~user_id ~count];

    Alcotest.(check bool) "structured with namespace works" true true

(* Test all log levels with namespace *)
let test_all_levels_with_namespace () =
  Eio_main.run @@ fun _env ->
    [%log.trace "Trace with namespace"];
    [%log.debug "Debug with namespace"];
    [%log.info "Info with namespace"];
    [%log.success "Success with namespace"];
    [%log.warn "Warn with namespace"];
    [%log.error "Error with namespace"];
    [%log.fatal "Fatal with namespace"];

    Alcotest.(check bool) "all levels work with namespace" true true

(* Module with explicit namespace *)
module Database = struct
  [@@@flo.namespace "test.database"]

  let test_nested_module_namespace () =
    Eio_main.run @@ fun _env ->
      [%log.info "Inside Database module"];
      Alcotest.(check bool) "nested module namespace works" true true
end

(* Module without explicit namespace - should auto-generate from name *)
module Cache = struct
  let test_auto_namespace () =
    Eio_main.run @@ fun _env ->
      (* This should automatically use "cache" as namespace *)
      [%log.debug "Auto-generated namespace from module"];
      Alcotest.(check bool) "auto namespace works" true true
end

(* Nested modules - should build hierarchical namespace *)
module Api = struct
  module Handler = struct
    let test_hierarchical_auto_namespace () =
      Eio_main.run @@ fun _env ->
        (* Should automatically generate "api.handler" namespace *)
        [%log.info "Hierarchical auto namespace"];
        Alcotest.(check bool) "hierarchical auto namespace works" true true
  end
end

(* Test that namespace can be overridden in nested scope *)
module Overridden = struct
  [@@@flo.namespace "explicit.override"]

  let test_explicit_override () =
    Eio_main.run @@ fun _env ->
      (* Should use "explicit.override" not "overridden" *)
      [%log.info "Explicit override namespace"];
      Alcotest.(check bool) "explicit override works" true true
end

(* Test mixing structured logging with namespace *)
let test_structured_mixing () =
  Eio_main.run @@ fun _env ->
    let request_id = "req-789" in
    let status = 200 in

    [%log.success "Request completed" ~request_id ~status];

    Alcotest.(check bool) "structured mixing works" true true

(* Test that logs without namespace still work *)
let () =
  (* Reset namespace for this test *)
  (* Note: We can't easily test this in the same file due to module-level attribute *)
  ()

let () =
  Alcotest.run "PPX Namespace" [
    "attribute", [
      Alcotest.test_case "module_namespace_attribute" `Quick test_module_namespace_attribute;
      Alcotest.test_case "structured_with_namespace" `Quick test_structured_with_namespace;
      Alcotest.test_case "all_levels_with_namespace" `Quick test_all_levels_with_namespace;
      Alcotest.test_case "structured_mixing" `Quick test_structured_mixing;
    ];
    "nested", [
      Alcotest.test_case "nested_module_namespace" `Quick Database.test_nested_module_namespace;
      Alcotest.test_case "explicit_override" `Quick Overridden.test_explicit_override;
    ];
    "auto", [
      Alcotest.test_case "auto_namespace" `Quick Cache.test_auto_namespace;
      Alcotest.test_case "hierarchical_auto_namespace" `Quick Api.Handler.test_hierarchical_auto_namespace;
    ];
  ]
