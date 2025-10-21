# Flō - Modern Logging for OCaml 5 + Eio

**Flō** (from Latin "flow") is a fully-featured logging library for OCaml 5 applications using Eio. It combines Loguru's "just works" ergonomics with Haskell's functional elegance and modern observability standards.

[![OCaml](https://img.shields.io/badge/OCaml-5.1%2B-orange)](https://ocaml.org/)
[![Eio](https://img.shields.io/badge/Eio-1.0%2B-blue)](https://github.com/ocaml-multicore/eio)

## Features

- ✨ **Zero Configuration** - Pre-configured singleton, works immediately
- 🎨 **Beautiful Output** - Colored console logging inspired by Loguru
- 📊 **Structured Logging** - Type-safe structured fields with GADTs
- 🔗 **Distributed Tracing** - W3C Trace Context and OpenTelemetry compliance
- ⚡ **Async Performance** - Non-blocking writes with background processing
- 📁 **File Rotation** - Size and time-based rotation with retention policies
- 🧵 **Fiber-Local Context** - Automatic context propagation with Eio
- 🛡️ **Type Safety** - Compile-time guarantees throughout
- 🔧 **PPX Extensions** - Automatic location capture and ergonomic syntax
- 🎯 **Variable Support** - PPX works with both literals and variables
- 🏷️ **Namespace-Based Logging** - Fine-grained per-component verbosity control

## Quick Start

```ocaml
open Flo

let () =
  (* Zero configuration - just use it *)
  info "Application started";
  successf "Processed %d items" 42;

  (* Structured logging with semantic conventions *)
  info_fields "HTTP request" ~fields:[
    http_method "POST";
    http_status 201;
    duration_ms 42.5;
  ]
```

## Installation

```bash
opam install flo
opam install ppx_flo  # Optional: PPX extensions
```

Add to your `dune` file:

```lisp
(executable
 (name my_app)
 (libraries flo eio_main)
 (preprocess (pps ppx_flo)))  ; Optional: Enable PPX
```

Or add to your `dune-project`:

```lisp
(depends
  (flo (>= 0.1.0))
  (ppx_flo (>= 0.1.0))  ; Optional
  (eio (>= 1.0))
  (eio_main (>= 1.0)))
```

## Core Examples

### Simple Logging

```ocaml
open Flo

(* 7 severity levels *)
trace "Fine-grained debug";
debug "Debug information";
info "Informational";
success "Operation succeeded!";
warn "Warning";
error "Error occurred";
fatal "Critical failure";

(* Printf-style *)
infof "User %s from %s" user_id ip;
```

### Structured Logging

```ocaml
info_fields "Database query" ~fields:[
  Flo_semconv.db_system "postgresql";
  Flo_semconv.db_operation "SELECT";
  Flo_semconv.duration_ms 15.3;
]
```

### Context Propagation

```ocaml
with_span "handle_request" (fun () ->
  bind [user_id "alice"; ("request_id", String "req-123")];
  info "Processing";  (* Includes user_id and request_id *)
  process_order ()
)
```

### Distributed Tracing

```ocaml
let handle_request headers =
  Flo_eio.with_http_context ~headers (fun () ->
    info "Request received";
    Flo_structured.in_span "db_query" (fun _ ->
      query_database ()
    );
    success "Complete"
  )
```

### Namespace-Based Logging

Control log verbosity per library/component:

```ocaml
(* Library code with PPX *)
[@@@flo.namespace "mylib.database"]

let connect host =
  [%log.info "Connecting"];  (* Tagged with "mylib.database" *)
  [%log.debug "Host" ~host];
  establish_connection host

(* Or use functor for type safety *)
module Log = Flo_scoped.Make(struct
  let namespace = "mylib.database"
end)

(* Application configures verbosity *)
let () =
  Flo.set_level_for "mylib.database" Severity.Debug;  (* Debug for DB *)
  Flo.set_level_for "mylib.cache" Severity.Warn;       (* Only warnings *)

  (* Hierarchical: child inherits parent level *)
  (* "mylib.database.pool" inherits Debug from "mylib.database" *)
```

### File Logging

```ocaml
Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let sink = Flo_sink_file.create_rotating ~sw {
      path = Eio.Path.(Eio.Stdenv.cwd env / "logs" / "app.log");
      format = `Json;
      rotation = Size 10485760L;  (* 10MB *)
      retention = Some (Keep_last 7);
      level = Severity.Info;
      buffer_size = 4096;
      create_dirs = true;
    } in
    (* File sink ready to use *)
```

### Async Logging

```ocaml
(* Non-blocking, high-throughput logging *)
let async_sink = Flo_sink_async.create ~sw ~env
  ~config:{
    buffer_capacity = 10000;
    batch_size = 500;
    flush_interval = 1.0;
    level = Severity.Info;
  }
  ~underlying:file_sink
in

(* Writes return immediately *)
for i = 1 to 100_000 do
  Flo_sink_async.write async_sink (Record.make ...)
done;

Flo_sink_async.drain async_sink  (* Ensure all written *)
```

## PPX Extensions

The `ppx_flo` preprocessor provides ergonomic syntax extensions:

### Automatic Location Capture

```ocaml
[%log.info "User logged in"]
(* Expands to: *)
Flo.info ~location:(Location.make_full ~file:"app.ml" ~line:42 ...) "User logged in"
```

### Structured Logging with Variables

```ocaml
let user_id = get_user_id () in
let count = process_items () in

[%log.info "Processing complete" ~user_id ~count]
(* Variables automatically converted to Value.t! *)
```

### Span Annotations

```ocaml
let result = [%span
  begin
    [%log.info "Computing result"];
    expensive_computation ()
  end
]
(* Automatically wraps in distributed tracing span *)
```

**See [PPX_GUIDE.md](PPX_GUIDE.md) for complete documentation.**

## Modules

- **Flo** - Simple API for everyday logging
- **Flo_scoped** - Type-safe namespace-scoped loggers
- **Flo_namespace** - Namespace registry and configuration
- **Flo_structured** - Type-safe structured logging
- **Flo_semconv** - OpenTelemetry semantic conventions
- **Flo_eio** - Distributed tracing integration
- **Flo_sink_file** - File output with rotation
- **Flo_sink_async** - Async high-performance sink
- **Flo_format_json** - JSON formatter
- **Flo_format_logfmt** - Logfmt formatter
- **Flo_format_pretty** - Pretty console output

## Examples

Run the examples to see Flō in action:

```bash
dune exec examples/simple_app.exe           # Basic usage
dune exec examples/structured_events.exe    # Structured logging
dune exec examples/scoped_logging.exe       # Namespace-based logging
dune exec examples/file_logging.exe         # File rotation
dune exec examples/perf_app.exe             # Performance
dune exec examples/web_service.exe          # Distributed tracing
```

## Documentation

- [TUTORIAL.md](TUTORIAL.md) - Step-by-step guide with namespace examples
- [DESIGN.md](DESIGN.md) - Architecture details with namespace design
- [PPX_GUIDE.md](PPX_GUIDE.md) - PPX namespace attributes
- [PLAN.md](PLAN.md) - Original implementation roadmap
- [PLAN2.md](PLAN2.md) - Namespace feature implementation plan

## Requirements

- OCaml >= 5.1.0
- Eio >= 1.0
- Dune >= 3.16
- Yojson >= 2.0
- Ptime >= 1.0

## Development

```bash
dune build        # Build library
dune test         # Run test suite (229+ tests)
dune clean        # Clean build artifacts
```

## License

MIT

