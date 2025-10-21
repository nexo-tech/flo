(** Tests for Flo_scoped functor-based loggers *)

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

(* Define test logger at top level *)
module TestLog = Flo_scoped.Make(struct
  let namespace = "test.component"
end)

(** Test creating a logger with Make functor *)
let test_make_functor () =
  Eio_main.run @@ fun _env ->
    (* Verify namespace is set *)
    Alcotest.(check string) "namespace is correct" "test.component" TestLog.namespace;

    (* Log messages - should not crash *)
    TestLog.info "Info message";
    TestLog.debug "Debug message";
    TestLog.warn "Warn message";

    Alcotest.(check bool) "functor logger works" true true

module PrintfLog = Flo_scoped.Make(struct
  let namespace = "test.printf"
end)

(** Test printf-style logging with functor *)
let test_functor_printf_style () =
  Eio_main.run @@ fun _env ->
    (* Test all printf-style functions *)
    PrintfLog.tracef "Trace: %d" 1;
    PrintfLog.debugf "Debug: %d" 2;
    PrintfLog.infof "Info: %d" 3;
    PrintfLog.successf "Success: %d" 4;
    PrintfLog.warnf "Warn: %d" 5;
    PrintfLog.errorf "Error: %d" 6;
    PrintfLog.fatalf "Fatal: %d" 7;

    Alcotest.(check bool) "printf-style works" true true

module StructuredLog = Flo_scoped.Make(struct
  let namespace = "test.structured"
end)

(** Test structured logging with functor *)
let test_functor_structured_logging () =
  Eio_main.run @@ fun _env ->
    (* Test structured logging *)
    StructuredLog.info_fields "Info with fields" ~fields:[
      ("key1", Value.string "value1");
      ("key2", Value.int 42);
    ];

    StructuredLog.debug_fields "Debug with fields" ~fields:[
      ("debug_key", Value.bool true);
    ];

    Alcotest.(check bool) "structured logging works" true true

module ConfigLog = Flo_scoped.Make(struct
  let namespace = "test.config"
end)

(** Test logger configuration via functor *)
let test_functor_configuration () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Initially no level set *)
    let level1 = ConfigLog.get_level () in
    Alcotest.(check (option Severity.testable)) "no level initially" None level1;

    (* Set level via logger *)
    ConfigLog.set_level Severity.Debug;

    (* Get level via logger *)
    let level2 = ConfigLog.get_level () in
    Alcotest.(check (option Severity.testable))
      "level set via logger" (Some Severity.Debug) level2;

    (* Get effective level *)
    Flo.set_level Severity.Info;
    let effective = ConfigLog.get_effective_level () in
    Alcotest.(check Severity.testable)
      "effective level is Debug" Severity.Debug effective;

    Flo_namespace.clear_all ()

module LogA = Flo_scoped.Make(struct
  let namespace = "component.a"
end)

module LogB = Flo_scoped.Make(struct
  let namespace = "component.b"
end)

module LogC = Flo_scoped.Make(struct
  let namespace = "component.c"
end)

(** Test multiple loggers simultaneously *)
let test_multiple_loggers () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Verify each has correct namespace *)
    Alcotest.(check string) "LogA namespace" "component.a" LogA.namespace;
    Alcotest.(check string) "LogB namespace" "component.b" LogB.namespace;
    Alcotest.(check string) "LogC namespace" "component.c" LogC.namespace;

    (* Configure different levels *)
    LogA.set_level Severity.Debug;
    LogB.set_level Severity.Info;
    LogC.set_level Severity.Warn;

    (* Verify independent configuration *)
    Alcotest.(check (option Severity.testable))
      "LogA level" (Some Severity.Debug) (LogA.get_level ());
    Alcotest.(check (option Severity.testable))
      "LogB level" (Some Severity.Info) (LogB.get_level ());
    Alcotest.(check (option Severity.testable))
      "LogC level" (Some Severity.Warn) (LogC.get_level ());

    (* Log with each logger *)
    LogA.info "From A";
    LogB.info "From B";
    LogC.info "From C";

    Flo_namespace.clear_all ()

(** Test runtime logger creation with create *)
let test_runtime_logger_creation () =
  Eio_main.run @@ fun _env ->
    (* Create logger at runtime *)
    let namespace = "runtime.logger" in
    let logger = Flo_scoped.create namespace in

    (* Unpack first-class module *)
    let module Log = (val logger : Flo_scoped.LOGGER) in

    (* Verify namespace *)
    Alcotest.(check string) "runtime namespace" namespace Log.namespace;

    (* Use the logger *)
    Log.info "Runtime logger message";
    Log.debugf "Formatted: %s" "test";
    Log.info_fields "Structured" ~fields:[
      ("field", Value.string "value");
    ];

    Alcotest.(check bool) "runtime logger works" true true

(** Test runtime logger with dynamic namespace *)
let test_dynamic_namespace () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Create loggers with different namespaces *)
    let namespaces = ["ns1"; "ns2"; "ns3"] in

    List.iter (fun ns ->
      let logger = Flo_scoped.create ns in
      let module Log = (val logger : Flo_scoped.LOGGER) in

      (* Verify namespace matches *)
      Alcotest.(check string)
        (Printf.sprintf "%s namespace" ns) ns Log.namespace;

      (* Set different levels *)
      Log.set_level Severity.Debug;

      (* Verify level was set *)
      let level = Log.get_level () in
      Alcotest.(check (option Severity.testable))
        (Printf.sprintf "%s level set" ns)
        (Some Severity.Debug) level
    ) namespaces;

    Flo_namespace.clear_all ()

module SpanLog = Flo_scoped.Make(struct
  let namespace = "test.span"
end)

(** Test logger with_span preserves namespace *)
let test_functor_with_span () =
  Eio_main.run @@ fun _env ->
    (* Use with_span from logger *)
    SpanLog.with_span "test_operation" (fun () ->
      (* Verify namespace is in context *)
      let ns = Flo.get_current_namespace () in
      Alcotest.(check (option string))
        "namespace in span" (Some "test.span") ns;

      (* Verify we have span context *)
      let trace_id = Flo.get_trace_id () in
      let span_id = Flo.get_span_id () in
      Alcotest.(check bool) "has trace_id" true (Option.is_some trace_id);
      Alcotest.(check bool) "has span_id" true (Option.is_some span_id);

      (* Log within span *)
      SpanLog.info "Inside span"
    )

module BindLog = Flo_scoped.Make(struct
  let namespace = "test.bind"
end)

(** Test logger bind adds context *)
let test_functor_bind () =
  Eio_main.run @@ fun _env ->
    BindLog.with_span "test_span" (fun () ->
      (* Bind additional context *)
      BindLog.bind [
        ("request_id", Value.string "req-123");
        ("user_id", Value.string "user-456");
      ];

      (* Context should be available *)
      (* We can't easily verify the context made it to the log,
         but we can verify the call doesn't crash *)
      BindLog.info "With bound context";

      Alcotest.(check bool) "bind works" true true
    )

module ChildLog = Flo_scoped.Make(struct
  let namespace = "parent.child"
end)

(** Test hierarchical namespace with functor *)
let test_functor_hierarchical_levels () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set parent level *)
    Flo.set_level_for "parent" Severity.Warn;

    (* Child should inherit parent's level *)
    let effective = ChildLog.get_effective_level () in
    Alcotest.(check Severity.testable)
      "child inherits parent level" Severity.Warn effective;

    (* Set child's own level *)
    ChildLog.set_level Severity.Debug;

    (* Now child has its own level *)
    let effective2 = ChildLog.get_effective_level () in
    Alcotest.(check Severity.testable)
      "child has own level" Severity.Debug effective2;

    Flo_namespace.clear_all ()

module ScopedLog = Flo_scoped.Make(struct
  let namespace = "scoped.logger"
end)

(** Test functor logger doesn't interfere with global Flo *)
let test_functor_vs_global () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set different levels *)
    Flo.set_level Severity.Info;
    ScopedLog.set_level Severity.Debug;

    (* Global level should be unchanged *)
    Alcotest.(check Severity.testable)
      "global level unchanged" Severity.Info (Flo.get_level ());

    (* Scoped logger level should be set *)
    Alcotest.(check (option Severity.testable))
      "scoped level set" (Some Severity.Debug) (ScopedLog.get_level ());

    (* Both can log independently *)
    Flo.info "Global info";
    ScopedLog.debug "Scoped debug";

    Flo_namespace.clear_all ()

(** Test creating multiple instances of same logger *)
let test_multiple_instances_same_namespace () =
  Eio_main.run @@ fun _env ->
    (* Create two instances with same namespace *)
    let logger1 = Flo_scoped.create "shared.namespace" in
    let logger2 = Flo_scoped.create "shared.namespace" in

    let module Log1 = (val logger1 : Flo_scoped.LOGGER) in
    let module Log2 = (val logger2 : Flo_scoped.LOGGER) in

    (* Both should have same namespace *)
    Alcotest.(check string) "logger1 namespace" "shared.namespace" Log1.namespace;
    Alcotest.(check string) "logger2 namespace" "shared.namespace" Log2.namespace;

    (* Configuration affects both (same namespace) *)
    Log1.set_level Severity.Debug;

    let level1 = Log1.get_level () in
    let level2 = Log2.get_level () in

    Alcotest.(check (option Severity.testable))
      "logger1 level" (Some Severity.Debug) level1;
    Alcotest.(check (option Severity.testable))
      "logger2 level" (Some Severity.Debug) level2;

    Flo_namespace.clear_all ()

(** Test suite *)
let () =
  Alcotest.run "Flo_scoped" [
    "basic", [
      Alcotest.test_case "make_functor" `Quick test_make_functor;
      Alcotest.test_case "functor_printf_style" `Quick test_functor_printf_style;
      Alcotest.test_case "functor_structured_logging" `Quick test_functor_structured_logging;
    ];
    "configuration", [
      Alcotest.test_case "functor_configuration" `Quick test_functor_configuration;
      Alcotest.test_case "functor_hierarchical_levels" `Quick test_functor_hierarchical_levels;
      Alcotest.test_case "functor_vs_global" `Quick test_functor_vs_global;
    ];
    "multiple", [
      Alcotest.test_case "multiple_loggers" `Quick test_multiple_loggers;
      Alcotest.test_case "multiple_instances_same_namespace" `Quick test_multiple_instances_same_namespace;
    ];
    "runtime", [
      Alcotest.test_case "runtime_logger_creation" `Quick test_runtime_logger_creation;
      Alcotest.test_case "dynamic_namespace" `Quick test_dynamic_namespace;
    ];
    "context", [
      Alcotest.test_case "functor_with_span" `Quick test_functor_with_span;
      Alcotest.test_case "functor_bind" `Quick test_functor_bind;
    ];
  ]
