# Flō - Modern Logging for OCaml 5 + Eio

A logging library combining Loguru's ergonomics with Haskell's functional elegance and modern observability standards.

## Status

🚧 **Under Development** - Currently implementing Phase 1 (Core Foundation)

See [PLAN.md](PLAN.md) for implementation roadmap and [DESIGN.md](DESIGN.md) for complete API specification.

## Quick Start

```ocaml
open Flo

let () =
  Eio_main.run @@ fun _env ->
    info "Application started";
    successf "Processed %d items" 42
```

## Building

```bash
opam install . --deps-only
dune build
dune test
```

## Documentation

- [DESIGN.md](DESIGN.md) - Complete API specification and design philosophy
- [PLAN.md](PLAN.md) - Implementation plan with task breakdown

## License

MIT
