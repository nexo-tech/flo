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
```

Or add to your `dune-project`:

```lisp
(depends
  (flo (>= 0.1.0))
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

## Modules

- **Flo** - Simple API for everyday logging
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
dune exec examples/file_logging.exe         # File rotation
dune exec examples/perf_app.exe             # Performance
dune exec examples/web_service.exe          # Distributed tracing
```

## Documentation

- [TUTORIAL.md](TUTORIAL.md) - Step-by-step guide
- [DESIGN.md](DESIGN.md) - Architecture details
- [PLAN.md](PLAN.md) - Implementation roadmap

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

