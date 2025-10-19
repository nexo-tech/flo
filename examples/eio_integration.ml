(* Eio Integration Examples
 *
 * This example demonstrates Flo's Eio-specific features including
 * fiber-local context, structured concurrency, and HTTP context propagation.
 *)

open Flo

(* Example 1: Fiber-Local Context *)
let example_fiber_local_context ~env =
  Eio.traceln "\n=== Fiber-Local Context ===\n";

  Eio.Switch.run @@ fun _sw ->
    (* Each fiber gets its own isolated context *)
    Eio.Fiber.all [
      (fun () ->
        Flo_eio.with_context
          ~trace_id:(Trace_context.generate_trace_id ())
          ~attributes:[("fiber", Value.String "fiber-1"); ("task", Value.String "fetch_users")]
          (fun () ->
            Flo.info "Fiber 1: Starting task";
            Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
            Flo.info "Fiber 1: Task complete";
          )
      );
      (fun () ->
        Flo_eio.with_context
          ~trace_id:(Trace_context.generate_trace_id ())
          ~attributes:[("fiber", Value.String "fiber-2"); ("task", Value.String "process_orders")]
          (fun () ->
            Flo.info "Fiber 2: Starting task";
            Eio.Time.sleep (Eio.Stdenv.clock env) 0.01;
            Flo.info "Fiber 2: Task complete";
          )
      );
    ];

  Eio.traceln "\nEach fiber has isolated context (different trace_ids)"

(* Example 2: Structured Concurrency with Switch Lifecycle *)
let example_structured_concurrency ~env =
  Eio.traceln "\n=== Structured Concurrency (Switch Lifecycle) ===\n";

  let cwd = Eio.Stdenv.cwd env in

  (* Create logger bound to switch - cleans up automatically *)
  Eio.Switch.run @@ fun sw ->
    Eio.traceln "Switch started - creating file sink";

    let file_sink = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "eio_lifecycle.log");
      format = `Json;
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Spawn concurrent tasks within switch *)
    Eio.Fiber.all [
      (fun () ->
        for i = 1 to 3 do
          let r = Record.make ~severity:Severity.Info
            ~message:(Printf.sprintf "Task A: Step %d" i) in
          Flo_sink_file.write_basic file_sink r
        done
      );
      (fun () ->
        for i = 1 to 3 do
          let r = Record.make ~severity:Severity.Info
            ~message:(Printf.sprintf "Task B: Step %d" i) in
          Flo_sink_file.write_basic file_sink r
        done
      );
    ];

    Flo_sink_file.flush_basic file_sink;
    Eio.traceln "All tasks complete - switch will clean up sink";

  Eio.traceln "Switch exited - sink closed automatically ✓"

(* Example 3: HTTP Context Extraction from Headers *)
let example_http_context_extraction () =
  Eio.traceln "\n=== HTTP Context Extraction ===\n";

  (* Simulate incoming HTTP request *)
  let incoming_headers = [
    ("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01");
    ("tracestate", "vendor1=value1,vendor2=value2");
    ("content-type", "application/json");
  ] in

  Eio.traceln "Incoming HTTP headers:";
  List.iter (fun (k, v) ->
    Eio.traceln "  %s: %s" k v
  ) incoming_headers;

  (* Extract trace context *)
  match Flo_eio.extract_trace_context incoming_headers with
  | Some span_ctx ->
      Eio.traceln "\n✓ Extracted W3C Trace Context:";
      Eio.traceln "  trace_id: %s" span_ctx.Trace_context.trace_id;
      Eio.traceln "  span_id: %s" span_ctx.Trace_context.span_id;
      Eio.traceln "  sampled: %b" (span_ctx.Trace_context.trace_flags land 1 = 1);

      (* Use extracted context *)
      Flo_eio.with_http_context ~headers:incoming_headers (fun () ->
        Flo.info "Processing request with inherited trace context";
        Flo.bind [("endpoint", Value.String "/api/orders")];
        Flo.info "Request processed";
      );

      (* Inject into outgoing request *)
      let outgoing = Flo_eio.inject_trace_context span_ctx in
      Eio.traceln "\nOutgoing headers for downstream service:";
      List.iter (fun (k, v) ->
        Eio.traceln "  %s: %s" k v
      ) outgoing
  | None ->
      Eio.traceln "No trace context in headers"

(* Example 4: Multi-Domain Logging with Eio *)
let example_multi_domain ~env =
  Eio.traceln "\n=== Multi-Domain Logging ===\n";

  (* Each domain can log independently *)
  Eio.Switch.run @@ fun sw ->
    (* Domain 1: Web server *)
    Eio.Fiber.fork ~sw (fun () ->
      Flo.with_user "domain-1" (fun () ->
        for i = 1 to 3 do
          Flo.info (Printf.sprintf "Domain 1: Request %d" i);
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.005
        done
      )
    );

    (* Domain 2: Background worker *)
    Eio.Fiber.fork ~sw (fun () ->
      Flo.with_user "domain-2" (fun () ->
        for i = 1 to 3 do
          Flo.info (Printf.sprintf "Domain 2: Job %d" i);
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.005
        done
      )
    );

  Eio.traceln "\nMulti-domain logging works with Eio's scheduler"

(* Example 5: Context Propagation Across Fiber Boundaries *)
let example_fiber_context_propagation _env =
  Eio.traceln "\n=== Context Propagation Across Fibers ===\n";

  Flo.with_trace_id (Trace_context.generate_trace_id ()) (fun () ->
    Flo.info "Parent: Setting up context";

    Eio.Switch.run @@ fun _sw ->
      (* Child fibers inherit parent context *)
      Eio.Fiber.all [
        (fun () ->
          Flo.info "Child 1: Inherited parent context";
          Flo.bind [("child", Value.String "child-1")];
          Flo.info "Child 1: Added own context";
        );
        (fun () ->
          Flo.info "Child 2: Inherited parent context";
          Flo.bind [("child", Value.String "child-2")];
          Flo.info "Child 2: Added own context";
        );
      ];

    Flo.info "Parent: All children complete";
  );

  Eio.traceln "\nChildren inherit parent trace_id but maintain isolated additions"

(* Example 6: Switch-Bound Resource Management *)
let example_switch_resources ~env =
  Eio.traceln "\n=== Switch-Bound Resource Management ===\n";

  let cwd = Eio.Stdenv.cwd env in

  Eio.traceln "Creating switch with logging resources...";

  Eio.Switch.run @@ fun sw ->
    (* All sinks bound to switch lifecycle *)
    let console = Flo_sink_console.create ~sw {
      output = `Stderr;
      colorize = true;
      format = `Pretty;
      level = Severity.Info;
    } in

    let file = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "switch_managed.log");
      format = `Logfmt;
      level = Severity.Debug;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Use sinks within switch scope *)
    for i = 1 to 3 do
      let record = Record.make ~severity:Severity.Info
        ~message:(Printf.sprintf "Managed log %d" i) in
      Flo_sink_console.write console record;
      Flo_sink_file.write_basic file record
    done;

    Flo_sink_console.flush console;
    Flo_sink_file.flush_basic file;

    Eio.traceln "Switch scope ending - resources will be cleaned up...";

  Eio.traceln "✓ Switch exited - all sinks closed automatically"

(* Main *)
let main env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Eio Integration Examples                          ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_fiber_local_context ~env;
  example_structured_concurrency ~env;
  example_http_context_extraction ();
  example_multi_domain ~env;
  example_fiber_context_propagation env;
  example_switch_resources ~env;

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
