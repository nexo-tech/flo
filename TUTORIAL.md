# Flō Tutorial - Common Patterns and Best Practices

This tutorial walks through common logging patterns and best practices for using Flō in your OCaml 5 + Eio applications.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Logging](#basic-logging)
3. [PPX Extensions](#ppx-extensions) ⭐ NEW
4. [Structured Logging](#structured-logging)
5. [Context Propagation](#context-propagation)
6. [Namespace-Based Logging](#namespace-based-logging) ⭐ NEW
7. [File Logging](#file-logging)
8. [High-Performance Logging](#high-performance-logging)
9. [Distributed Tracing](#distributed-tracing)
10. [Testing Best Practices](#testing-best-practices) ⭐ NEW
11. [Production Patterns](#production-patterns)

## Getting Started

### Installation

Add Flō to your `dune-project`:

```lisp
(package
 (name my_app)
 (depends
  (ocaml (>= 5.1.0))
  (flo (>= 0.1.0))
  (eio (>= 1.0))
  (eio_main (>= 1.0))))
```

Then install dependencies:

```bash
opam install . --deps-only
```

### Your First Log

```ocaml
open Flo

let () =
  info "Hello, Flō!"
```

That's it! Flō is pre-configured and ready to use. No setup required.

## Basic Logging

### Severity Levels

Flō provides 7 severity levels:

```ocaml
trace "Finest-grained debugging";
debug "Debug information";
info "Informational messages";
success "Celebrate successes!";
warn "Warning conditions";
error "Error events";
fatal "Critical failures";
```

### Printf-Style Formatting

```ocaml
infof "User %s logged in from IP %s" user_id ip_address;
warnf "Retry %d of %d failed" attempt max_attempts;
errorf "File not found: %s" filepath;
```

### Level Filtering

```ocaml
(* Set global minimum level *)
set_level Severity.Debug;  (* Show Debug and above *)

(* Or per-module *)
enable "MyModule";
disable "VerboseModule";
```

## PPX Extensions

### Why Use PPX?

The `ppx_flo` preprocessor makes logging more ergonomic:
- **Automatic location capture** - No manual file:line tracking
- **Variable support** - Use variables directly in structured logs
- **Less boilerplate** - Cleaner, more readable code

### Setup

Add preprocessing to your `dune` file:

```lisp
(executable
 (name my_app)
 (libraries flo eio_main)
 (preprocess (pps ppx_flo)))
```

### Location Capture

Without PPX:
```ocaml
(* Manual location - tedious *)
let loc = Location.make_full ~file:__FILE__ ~line:42 ~module_name:"My_app" () in
info ~location:loc "User action"
```

With PPX:
```ocaml
(* Automatic - much easier! *)
[%log.info "User action"]
```

The PPX automatically captures file, line, column, and module name.

### Structured Logging with Variables

Without PPX:
```ocaml
let user_id = get_user_id () in
let count = compute_count () in
info_fields "Task complete" ~fields:[
  ("user_id", Value.String user_id);
  ("count", Value.Int (Int64.of_int count));
]
```

With PPX:
```ocaml
let user_id = get_user_id () in
let count = compute_count () in
[%log.info "Task complete" ~user_id ~count]
```

Variables are automatically converted to the correct Value.t type!

### Span Annotations

```ocaml
let process_order order_id = [%span
  begin
    [%log.info "Processing" ~order_id];
    validate_order order_id;
    charge_payment order_id;
    [%log.success "Order complete" ~order_id];
    Ok ()
  end
]
```

Automatically wraps code in a distributed tracing span.

**See [PPX_GUIDE.md](PPX_GUIDE.md) and [examples/ppx_usage.ml](examples/ppx_usage.ml) for more.**

## Structured Logging

### Basic Structured Fields

```ocaml
info_fields "Database query completed" ~fields:[
  ("query", Value.String "SELECT * FROM users");
  ("duration_ms", Value.Float 23.5);
  ("rows_returned", Value.Int 156L);
]
```

### Semantic Conventions

Use OpenTelemetry semantic conventions for standardized attributes:

```ocaml
(* HTTP operations *)
info_fields "HTTP request" ~fields:[
  Flo_semconv.http_method "POST";
  Flo_semconv.http_status_code 201;
  Flo_semconv.http_target "/api/users";
  Flo_semconv.duration_ms 45.2;
];

(* Database operations *)
info_fields "Database query" ~fields:[
  Flo_semconv.db_system "postgresql";
  Flo_semconv.db_name "production";
  Flo_semconv.db_operation "SELECT";
  Flo_semconv.db_statement "SELECT * FROM orders WHERE user_id = $1";
];

(* Error tracking *)
info_fields "Error occurred" ~fields:[
  Flo_semconv.error_type "ValueError";
  Flo_semconv.error_message "Invalid email format";
  Flo_semconv.error_stack_trace stack_trace;
];
```

### Type-Safe Structured Events

Define domain events as modules for compile-time type safety:

```ocaml
module Order_Created = struct
  type t = {
    order_id : string;
    user_id : string;
    total : float;
  }

  let to_value t = Value.Object [
    ("order_id", Value.String t.order_id);
    ("user_id", Value.String t.user_id);
    ("total", Value.Float t.total);
  ]

  let event_name = "order.created"
  let severity = Severity.Info
end

(* Log the event with full type safety *)
Flo_structured.log_event (module Order_Created) {
  order_id = "ORD-123";
  user_id = "alice";
  total = 99.99;
}
```

## Context Propagation

### Fiber-Local Context

```ocaml
(* Context automatically propagates to child operations *)
with_span "process_request" (fun () ->
  bind [
    user_id "alice";
    ("request_id", String "req-abc-123");
  ];

  info "Starting processing";  (* Includes user_id and request_id *)

  (* Spawn child fiber - inherits context *)
  Eio.Fiber.fork ~sw (fun () ->
    info "Background task";  (* Also has user_id and request_id *)
  )
)
```

### Nested Spans

```ocaml
Flo_structured.in_span "handle_order" (fun _ ->
  info "Processing order";

  (* Nested span for database *)
  Flo_structured.in_span "fetch_user" (fun _ ->
    info "Fetching user data";
    fetch_user ()
  );

  (* Another nested span *)
  Flo_structured.in_span "charge_payment" (fun _ ->
    info "Charging payment";
    charge_card ()
  );

  success "Order complete"
)
(* All spans share the same trace_id, different span_ids *)
```

## Namespace-Based Logging

### Why Namespaces?

When building applications that use multiple libraries, you need fine-grained control over log verbosity per component. Namespaces solve this problem.

**The Problem**:
```ocaml
(* Your app uses LibraryA and LibraryB, both log internally *)
LibraryA.process ()  (* Logs at DEBUG level *)
LibraryB.cache ()    (* Also logs at DEBUG level *)

(* You want: *)
(* - See DEBUG logs from LibraryA.database *)
(* - See only WARN logs from LibraryB.cache *)
(* - See INFO logs from your app code *)
```

**The Solution**: Hierarchical namespaces with per-component configuration.

### For Library Authors

#### Step 1: Choose Your Namespace

Use your library name as the root namespace:

```ocaml
(* mylib/database.ml *)
[@@@flo.namespace "mylib.database"]  (* File-level PPX attribute *)

(* OR manually: *)
module Log = Flo_scoped.Make(struct
  let namespace = "mylib.database"
end)
```

#### Step 2: Use Scoped Logging

**With PPX** (recommended):
```ocaml
[@@@flo.namespace "mylib.database"]

let connect host port =
  [%log.info "Connecting to database"];
  [%log.debug "Connection params" ~host ~port];

  match establish_connection host port with
  | Ok conn ->
      [%log.success "Connected"];
      conn
  | Error err ->
      [%log.error "Connection failed" ~error:err];
      raise (Connection_error err)
```

**With Functor** (compile-time type safety):
```ocaml
(* mylib/log.ml *)
module Log = Flo_scoped.Make(struct
  let namespace = "mylib.database"
end)

(* mylib/database.ml *)
let connect host port =
  Log.info "Connecting to database";
  Log.debugf "Host: %s, Port: %d" host port;
  establish_connection host port
```

**With Manual Scoped Functions**:
```ocaml
let connect host port =
  Flo.scoped_info "mylib.database" "Connecting to database";
  Flo.scoped_debugf "mylib.database" "Host: %s, Port: %d" host port;
  establish_connection host port
```

#### Step 3: Organize Sub-Components

Use hierarchical namespaces for sub-components:

```ocaml
(* mylib/database.ml *)
[@@@flo.namespace "mylib.database"]

module Pool = struct
  (* Automatically becomes "mylib.database.pool" with PPX *)
  let acquire () =
    [%log.debug "Acquiring connection from pool"]
end

module Query = struct
  (* Automatically becomes "mylib.database.query" *)
  let execute sql =
    [%log.trace "Executing SQL" ~sql]
end
```

#### Step 4: Document Configuration

Tell users how to configure your library's logging:

```ocaml
(** Configure MyLib logging verbosity:

    {[
      (* Set level for entire library *)
      Flo.set_level_for "mylib" Severity.Warn;

      (* Enable debug for specific component *)
      Flo.set_level_for "mylib.database" Severity.Debug;

      (* Quiet the cache *)
      Flo.set_level_for "mylib.cache" Severity.Error;
    ]}
*)
```

### For Application Developers

#### Step 1: Configure Namespace Levels

Set up logging configuration at application startup:

```ocaml
let () =
  Eio_main.run @@ fun env ->
    (* Set global default *)
    Flo.set_level Severity.Info;

    (* Configure libraries *)
    Flo.set_level_for "mylib.database" Severity.Debug;
    Flo.set_level_for "mylib.cache" Severity.Warn;
    Flo.set_level_for "other_lib" Severity.Error;

    (* Configure your app components *)
    Flo.set_level_for "app.api" Severity.Debug;
    Flo.set_level_for "app.background" Severity.Info;

    (* Run application *)
    run_application env
```

#### Step 2: Use Namespaces in Your Code

**With PPX**:
```ocaml
(* app/api.ml *)
[@@@flo.namespace "app.api"]

let handle_request req =
  [%log.info "Request received" ~method_:req.method_ ~path:req.path];

  process_request req
```

**With Context**:
```ocaml
let handle_request req =
  Flo.with_namespace "app.api" (fun () ->
    Flo.info "Request received";

    (* Child fibers inherit namespace *)
    Eio.Fiber.fork (fun () ->
      Flo.debug "Processing in background"
    );

    process_request req
  )
```

#### Step 3: Monitor and Adjust

Check what namespaces are configured:

```ocaml
(* See all configured namespace levels *)
let levels = Flo.get_all_levels () in
List.iter (fun (ns, level) ->
  Printf.printf "%s -> %s\n" ns (Severity.to_string level)
) levels;

(* Check effective level for a namespace *)
let effective = Flo.get_effective_level "mylib.database.pool" in
Printf.printf "Effective level: %s\n" (Severity.to_string effective)
```

Adjust levels dynamically at runtime:

```ocaml
(* Increase verbosity for debugging *)
Flo.set_level_for "mylib.database" Severity.Trace;

(* Reduce verbosity in production *)
Flo.set_level_for "noisy.component" Severity.Warn
```

### Hierarchical Namespace Lookup

Namespaces use dot-separated hierarchies with parent-to-child inheritance:

```ocaml
(* Configure parent *)
Flo.set_level_for "mylib" Severity.Warn;

(* Child inherits parent level *)
Flo.get_effective_level "mylib.cache"     (* Returns Warn *)
Flo.get_effective_level "mylib.database"  (* Returns Warn *)

(* Override child *)
Flo.set_level_for "mylib.database" Severity.Debug;

(* Grandchild inherits from immediate parent *)
Flo.get_effective_level "mylib.database.pool"  (* Returns Debug *)

(* Sibling still uses original parent *)
Flo.get_effective_level "mylib.cache"  (* Still Warn *)
```

**Search order** for `"a.b.c.d"`:
1. Exact match: `"a.b.c.d"`
2. Parent: `"a.b.c"`
3. Grandparent: `"a.b"`
4. Great-grandparent: `"a"`
5. Root: `""` (global level)

### Common Patterns

#### Pattern 1: Library with Default Namespace

```ocaml
(* mylib/log.ml - centralized logging module *)
module Log = Flo_scoped.Make(struct
  let namespace = "mylib"
end)

(* Export for library-wide use *)
let info = Log.info
let debug = Log.debug
let warn = Log.warn
let error = Log.error

(* Convenience for sub-components *)
let with_component name f =
  Flo.with_namespace ("mylib." ^ name) f

(* mylib/database.ml *)
let connect () =
  MyLib.Log.info "Connecting";
  establish_connection ()

let query sql =
  MyLib.Log.with_component "database.query" (fun () ->
    MyLib.Log.debug "Executing query";
    execute sql
  )
```

#### Pattern 2: Application with Per-Feature Namespaces

```ocaml
(* app/main.ml *)
[@@@flo.namespace "app"]

module Api = struct
  (* Auto-becomes "app.api" *)
  let start () =
    [%log.info "Starting API server"]
end

module Background = struct
  (* Auto-becomes "app.background" *)
  let process_jobs () =
    [%log.debug "Processing background jobs"]
end

let () =
  (* Configure verbosity *)
  Flo.set_level_for "app.api" Severity.Info;
  Flo.set_level_for "app.background" Severity.Debug;

  Api.start ();
  Background.process_jobs ()
```

#### Pattern 3: Mixed Library and App Logging

```ocaml
let main () =
  Eio_main.run @@ fun env ->
    (* Configure third-party libraries *)
    Flo.set_level_for "dream" Severity.Warn;
    Flo.set_level_for "cohttp" Severity.Error;

    (* Configure your libraries *)
    Flo.set_level_for "mylib.database" Severity.Debug;
    Flo.set_level_for "mylib.cache" Severity.Info;

    (* Configure your app *)
    Flo.set_level_for "app" Severity.Info;
    Flo.set_level_for "app.diagnostics" Severity.Debug;

    run_application env
```

#### Pattern 4: Dynamic Namespace from Config

```ocaml
(* Load configuration from file/env *)
let setup_logging config =
  List.iter (fun (namespace, level_str) ->
    match Severity.of_string level_str with
    | Ok level -> Flo.set_level_for namespace level
    | Error _ -> Flo.warnf "Invalid level for %s: %s" namespace level_str
  ) config.log_levels

(* Example config.json *)
(* {
     "log_levels": {
       "mylib.database": "debug",
       "mylib.cache": "warn",
       "app": "info"
     }
   } *)
```

### Namespace Best Practices

#### ✅ DO

- **Use lowercase with dots**: `"mylib.component.subcomponent"`
- **Match your library name**: If library is `cohttp`, use `"cohttp"`
- **Keep depth reasonable**: 2-4 levels is ideal
- **Be consistent**: Use same naming across your codebase
- **Document configuration**: Tell users how to configure your namespaces
- **Configure early**: Set levels before logging begins

#### ❌ DON'T

- **Use special characters**: Avoid `"my-lib"`, `"my_lib"`, `"My.Lib"`
- **Go too deep**: `"a.b.c.d.e.f.g"` is hard to manage
- **Change namespaces frequently**: Pick one and stick with it
- **Forget to document**: Users need to know how to configure

### Debugging Namespace Issues

**Check effective level**:
```ocaml
let level = Flo.get_effective_level "mylib.database" in
Flo.infof "Effective level: %s" (Severity.to_string level)
```

**List all configured namespaces**:
```ocaml
let all = Flo.get_all_levels () in
List.iter (fun (ns, level) ->
  Flo.infof "%s -> %s" ns (Severity.to_string level)
) all
```

**Test if a log would be emitted**:
```ocaml
let effective = Flo.get_effective_level "mylib.database" in
let would_log = Severity.compare Severity.Debug effective >= 0 in
if would_log then
  Flo.info "Debug logs for mylib.database are enabled"
```

### Example: Real-World Library

See `examples/scoped_logging.ml` for a complete demonstration showing:
- Database library with scoped logging
- Cache library with different verbosity
- API handler with structured fields
- Authentication with runtime namespaces
- Application configuration
- Hierarchical inheritance
- Dynamic level changes

Run it:
```bash
dune exec examples/scoped_logging.exe
```

## File Logging

### Basic File Sink

```ocaml
Eio_main.run @@ fun env ->
  let cwd = Eio.Stdenv.cwd env in

  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_basic ~sw {
      path = Eio.Path.(cwd / "logs" / "app.log");
      format = `Json;
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in

    (* Write logs *)
    let record = Record.make ~severity:Info ~message:"App started" in
    Flo_sink_file.write_basic sink record;
    Flo_sink_file.flush_basic sink
```

### File Rotation

#### Size-Based Rotation

```ocaml
let sink = Flo_sink_file.create_rotating ~sw {
  path = Eio.Path.(cwd / "logs" / "app.log");
  format = `Json;
  rotation = Size 10485760L;  (* Rotate at 10MB *)
  retention = Some (Keep_last 7);  (* Keep 7 rotated files *)
  level = Severity.Info;
  buffer_size = 8192;
  create_dirs = true;
}
```

#### Time-Based Rotation

```ocaml
(* Rotate daily at midnight *)
rotation = Daily (0, 0);  (* Hour 0, Minute 0 *)

(* Or rotate every hour *)
rotation = Interval 3600.0;  (* 3600 seconds *)
```

### Retention Policies

```ocaml
(* Keep last N files *)
retention = Some (Keep_last 10);

(* Keep files from last 7 days *)
retention = Some (Keep_duration (7.0 *. 24.0 *. 3600.0));

(* Custom retention logic *)
retention = Some (Custom (fun files ->
  (* Return list of files to keep *)
  List.filter should_keep files
));
```

## High-Performance Logging

### Async Sink for Throughput

```ocaml
Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    (* Create underlying file sink *)
    let file_sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(cwd / "logs" / "fast.log");
      format = `Json;
      rotation = Size 52428800L;  (* 50MB *)
      retention = Some (Keep_last 5);
      level = Severity.Debug;
      buffer_size = 16384;  (* 16KB buffer *)
      create_dirs = true;
    } in

    (* Wrap with async sink *)
    let async_sink = Flo_sink_async.create ~sw ~env
      ~config:{
        buffer_capacity = 10000;  (* Queue 10K records *)
        batch_size = 500;          (* Write 500 at once *)
        flush_interval = 1.0;      (* Auto-flush every second *)
        level = Severity.Debug;
      }
      ~underlying:file_sink
    in

    (* High-throughput logging - non-blocking *)
    for i = 1 to 100_000 do
      let record = Record.make
        ~severity:Debug
        ~message:(Printf.sprintf "Processing item %d" i)
      in
      Flo_sink_async.write async_sink record
    done;

    (* Ensure all logs written before shutdown *)
    Flo_sink_async.drain async_sink;

    (* Check statistics *)
    let (queued, written, dropped) = Flo_sink_async.stats async_sink in
    Printf.printf "Stats: written=%Ld dropped=%Ld\n" written dropped
```

## Distributed Tracing

### HTTP Request Tracing

```ocaml
(* Extract trace context from incoming HTTP request *)
let handle_http_request headers body =
  Flo_eio.with_http_context ~headers (fun () ->
    info "Request received";

    (* Process request with automatic trace correlation *)
    let result = process_request body in

    success "Request completed";
    result
  )
```

### Multi-Service Trace Propagation

```ocaml
(* Service A receives request *)
let service_a_handler headers =
  Flo_eio.with_http_context ~headers (fun () ->
    info "Service A processing";

    (* Get current trace context *)
    let trace_id = Flo.get_trace_id () in
    let span_id = Flo.get_span_id () in

    (* Create span context for downstream call *)
    let span_ctx = {
      Trace_context.trace_id = Option.get trace_id;
      Trace_context.span_id = Option.get span_id;
      Trace_context.parent_span_id = None;
      Trace_context.trace_flags = 1;
    } in

    (* Inject trace into outgoing headers *)
    let downstream_headers = Flo_eio.inject_trace_context span_ctx in

    (* Call Service B with trace propagation *)
    call_service_b downstream_headers;

    success "Service A complete"
  )

(* Service B receives request with trace *)
let service_b_handler headers =
  Flo_eio.with_http_context ~headers (fun () ->
    (* Logs here share same trace_id as Service A *)
    info "Service B processing";
    success "Service B complete"
  )
```

### Span Hierarchy

```ocaml
Flo_structured.in_span "web_request" (fun parent_span ->
  info "Handling web request";

  Flo_structured.in_span "database_query" (fun _ ->
    info "Querying database";
    (* Child span has same trace_id, different span_id *)
  );

  Flo_structured.in_span "external_api_call" (fun _ ->
    info "Calling external API";
    (* Another child span *)
  );

  success "Request complete"
)
(* Automatic duration logging for all spans *)
```

## Testing Best Practices

### In-Memory Test Sink

```ocaml
(* Create a test sink to capture logs *)
let captured_logs = ref [] in

let test_sink record =
  captured_logs := record :: !captured_logs
in

(* Your function under test *)
let my_function user_id =
  let r = Record.make ~severity:Severity.Info ~message:"User action" in
  let r = Record.with_attributes [("user_id", Value.String user_id)] r in
  test_sink r
in

(* Run test *)
my_function "alice";

(* Assert *)
let logs = List.rev !captured_logs in
assert (List.length logs = 1);
assert (List.hd logs).Record.message = "User action")
```

### Testing Structured Fields

```ocaml
let record = List.hd captured_logs in
match List.assoc_opt "user_id" record.Record.attributes with
| Some (Value.String uid) ->
    assert (uid = "alice")
| _ ->
    failwith "user_id not found or wrong type"
```

### Testing with Alcotest

```ocaml
let test_logging () =
  let logs = ref [] in

  (* Test your logging code *)
  ...

  (* Assertions *)
  Alcotest.(check int) "log count" 3 (List.length !logs);
  Alcotest.(check bool) "has error"
    true (List.exists (fun r -> r.Record.severity = Severity.Error) !logs)
```

**See [examples/testing_with_flo.ml](examples/testing_with_flo.ml) for complete patterns.**

## Production Patterns

### Pattern 1: Web Service with Full Observability

```ocaml
let handle_api_request ~env headers method_ path body =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    Eio.Switch.run @@ fun sw ->
      (* Set up file logging *)
      let file_sink = Flo_sink_file.create_rotating ~sw {
        path = Eio.Path.(cwd / "logs" / "api.log");
        format = `Json;
        rotation = Daily (0, 0);
        retention = Some (Keep_last 30);
        level = Severity.Info;
        buffer_size = 8192;
        create_dirs = true;
      } in

      (* Wrap with async for performance *)
      let async_sink = Flo_sink_async.create ~sw ~env
        ~config:{
          buffer_capacity = 5000;
          batch_size = 250;
          flush_interval = 2.0;
          level = Severity.Info;
        }
        ~underlying:file_sink
      in

      (* Handle request with distributed tracing *)
      Flo_eio.with_http_request
        ~headers
        ~span_name:"api_request"
        ~attributes:[
          Flo_semconv.http_method method_;
          Flo_semconv.http_target path;
          Flo_semconv.service_name "my-api";
        ]
        (fun () ->
          info "Processing API request";

          let result = process_api_request path body in

          (* Write to async sink *)
          let record = Record.make
            ~severity:Info
            ~message:"API request completed"
          in
          let record = Record.with_attributes [
            Flo_semconv.http_status_code 200;
          ] record in
          Flo_sink_async.write async_sink record;

          Flo_sink_async.drain async_sink;

          result
        )
```

### Pattern 2: Background Job Processing

```ocaml
let process_jobs ~env jobs =
  Eio_main.run @@ fun env ->
    Eio.Switch.run @@ fun sw ->
      (* Concurrent job processing with isolated contexts *)
      List.iter (fun job ->
        Eio.Fiber.fork ~sw (fun () ->
          Flo_eio.with_context
            ~trace_id:job.id
            ~attributes:[
              ("job_type", Value.String job.type_);
              Flo_semconv.user_id job.user_id;
            ]
            (fun () ->
              info "Starting job";

              Flo_structured.in_span "execute_job" (fun _ ->
                match execute_job job with
                | Ok result ->
                    successf "Job completed: %s" result
                | Error err ->
                    errorf "Job failed: %s" err
              )
            )
        )
      ) jobs
```

### Pattern 3: Error Handling

```ocaml
(* Automatic exception logging *)
let safe_operation () =
  match catch (fun () ->
    dangerous_operation ()
  ) with
  | Some result -> result
  | None ->
      warn "Operation failed, using fallback";
      fallback_operation ()

(* Manual exception logging *)
try
  risky_code ()
with exn ->
  Flo.info_fields "Exception caught" ~fields:[
    Flo_semconv.error_type (Printexc.to_string exn);
    Flo_semconv.error_message (Printexc.to_string exn);
    Flo_semconv.error_stack_trace (Printexc.get_backtrace ());
  ];
  reraise exn
```

### Pattern 4: Multiple Output Formats

```ocaml
Eio.Switch.run @@ fun sw ->
  (* JSON for machine processing *)
  let json_sink = Flo_sink_file.create_rotating ~sw {
    path = Eio.Path.(cwd / "logs" / "app.json");
    format = `Json;
    rotation = Size 10485760L;
    retention = Some (Keep_last 7);
    level = Severity.Debug;
    buffer_size = 4096;
    create_dirs = true;
  } in

  (* Logfmt for human reading *)
  let logfmt_sink = Flo_sink_file.create_rotating ~sw {
    path = Eio.Path.(cwd / "logs" / "app.logfmt");
    format = `Logfmt;
    rotation = Daily (0, 0);
    retention = Some (Keep_duration (7.0 *. 86400.0));
    level = Severity.Info;
    buffer_size = 4096;
    create_dirs = true;
  } in

  (* Use both sinks... *)
```

### Pattern 5: Testing with Mock Sinks

```ocaml
(* In tests, verify logging behavior *)
let test_user_creation () =
  Eio_main.run @@ fun env ->
    let cwd = Eio.Stdenv.cwd env in

    Eio.Switch.run @@ fun sw ->
      let test_sink = Flo_sink_file.create_basic ~sw {
        path = Eio.Path.(cwd / "test_output.log");
        format = `Json;
        level = Severity.Debug;
        buffer_size = 0;
        create_dirs = true;
      } in

      (* Run code under test *)
      create_user "alice@example.com";

      (* Flush and read logs *)
      Flo_sink_file.flush_basic test_sink;
      let content = Eio.Path.load Eio.Path.(cwd / "test_output.log") in

      (* Assert expected logs *)
      assert (String.contains content "user.created");

      (* Clean up *)
      Eio.Path.unlink Eio.Path.(cwd / "test_output.log")
```

## Best Practices

### 1. Use Semantic Conventions

Always use `Flo_semconv` helpers for standard attributes:

```ocaml
(* Good *)
info_fields "Request" ~fields:[
  Flo_semconv.http_method "GET";
  Flo_semconv.http_status_code 200;
];

(* Avoid *)
info_fields "Request" ~fields:[
  ("method", Value.String "GET");  (* Non-standard key *)
  ("status", Value.Int 200L);      (* Should be http.status_code *)
];
```

### 2. Set Appropriate Levels

```ocaml
(* Development *)
set_level Severity.Debug;

(* Production *)
set_level Severity.Info;

(* High-traffic production *)
set_level Severity.Warn;
```

### 3. Use Context for Correlation

```ocaml
(* Bind context at entry points *)
let handle_request request =
  with_span "handle_request" (fun () ->
    bind [
      Flo_semconv.request_id request.id;
      Flo_semconv.user_id request.user;
    ];

    (* All child operations automatically include request_id and user_id *)
    process_request request
  )
```

### 4. Drain Async Sinks on Shutdown

```ocaml
let main env =
  Eio.Switch.run @@ fun sw ->
    let async_sink = setup_async_logging ~sw ~env in

    (* Application logic *)
    run_application ();

    (* IMPORTANT: Drain before switch closes *)
    Flo_sink_async.drain async_sink
    (* Without drain, buffered logs may be lost *)
```

### 5. Structure Events for Querying

```ocaml
(* Define events with clear structure for later querying *)
module Payment_Failed = struct
  type t = {
    payment_id : string;
    user_id : string;
    amount : float;
    error_code : string;
  }
  (* ... *)
  let event_name = "payment.failed"  (* Queryable event name *)
end

(* Later, query logs for: event_name = "payment.failed" *)
```

## Common Pitfalls

### ❌ Forgetting to Drain Async Sinks

```ocaml
(* BAD *)
Eio.Switch.run @@ fun sw ->
  let async_sink = create_async_sink ~sw ~env in
  log_lots_of_data async_sink
  (* Switch closes, buffered logs lost! *)

(* GOOD *)
Eio.Switch.run @@ fun sw ->
  let async_sink = create_async_sink ~sw ~env in
  log_lots_of_data async_sink;
  Flo_sink_async.drain async_sink  (* Ensure all written *)
```

### ❌ Logging in Hot Loops Without Filtering

```ocaml
(* BAD - creates Records on every iteration *)
for i = 1 to 1_000_000 do
  debug "Processing item";  (* Too verbose! *)
done

(* GOOD - use appropriate level or sample *)
set_level Severity.Info;  (* Filter out debug in production *)

for i = 1 to 1_000_000 do
  if i mod 1000 = 0 then
    infof "Progress: %d items" i  (* Only log milestones *)
done
```

### ❌ Not Using Eio Switch

```ocaml
(* BAD - no resource management *)
let sink = create_file_sink ...  (* How to clean up? *)

(* GOOD - use Eio.Switch *)
Eio.Switch.run @@ fun sw ->
  let sink = Flo_sink_file.create_rotating ~sw { ... } in
  (* Auto-cleanup when switch closes *)
```

## Performance Tips

1. **Use Async Sinks** for high-throughput scenarios (>1000 logs/sec)
2. **Buffer Writes** with appropriate buffer_size (4KB-16KB typical)
3. **Batch Appropriately** - Larger batches (500-1000) for fewer syscalls
4. **Filter Early** - Set minimum level to avoid creating unnecessary records
5. **Use Structured Fields** - More efficient than string concatenation

## Next Steps

- Explore [examples/](examples/) for complete working code
- Read [DESIGN.md](DESIGN.md) for architecture deep-dive
- Check [PLAN.md](PLAN.md) for implementation status

## Getting Help

- Report issues on GitHub
- Read the API documentation (generated with `dune build @doc`)
- Check existing examples for patterns
