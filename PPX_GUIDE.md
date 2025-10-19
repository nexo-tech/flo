# Flō PPX Extensions Guide

## Overview

The `ppx_flo` preprocessor provides three main extensions to make logging more convenient and powerful:

1. **Automatic Location Capture** - `[%log.level "message"]`
2. **Structured Logging with Type Inference** - `[%log.level "message" ~field:value]`
3. **Span Annotations** - `[%span expr]`

## Installation

Add `ppx_flo` to your `dune` file:

```dune
(executable
 (name my_app)
 (libraries flo eio_main)
 (preprocess (pps ppx_flo)))
```

## Feature 1: Automatic Location Capture

### Usage

```ocaml
[%log.info "User logged in"]
```

### Expands to:

```ocaml
Flo.info ~location:(Location.make_full
  ~file:"my_app.ml"
  ~line:42
  ~column:2
  ~module_name:"My_app"
  ())
  "User logged in"
```

### All Severity Levels

- `[%log.trace "message"]`
- `[%log.debug "message"]`
- `[%log.info "message"]`
- `[%log.success "message"]`
- `[%log.warn "message"]`
- `[%log.error "message"]`
- `[%log.fatal "message"]`

### Benefits

- **Zero boilerplate** - No need to manually pass location
- **Accurate** - Captures exact file, line, column
- **Module-aware** - Includes module name
- **Production-ready** - Helps trace logs to source code

## Feature 2: Structured Logging with Type Inference

### Usage

```ocaml
[%log.info "Order created"
  ~order_id:"12345"
  ~total:99.99
  ~item_count:3
  ~is_paid:true]
```

### Expands to:

```ocaml
Flo.info_fields ~location:(...) "Order created" ~fields:[
  ("order_id", Value.String "12345");
  ("total", Value.Float 99.99);
  ("item_count", Value.Int 3L);
  ("is_paid", Value.Bool true);
]
```

### Supported Types

| OCaml Type | Value.t Constructor | Example |
|------------|-------------------|---------|
| `string` literal | `Value.String` | `~name:"alice"` |
| `int` literal | `Value.Int` | `~count:42` |
| `float` literal | `Value.Float` | `~price:9.99` |
| `true` / `false` | `Value.Bool` | `~enabled:true` |
| `[]` | `Value.Array []` | `~tags:[]` |
| `[1; 2; 3]` | `Value.Array [...]` | `~nums:[1; 2; 3]` |

### Variable Support

✅ **The PPX works with both literals AND variables!**

```ocaml
(* ✓ Works - literal value *)
[%log.info "Message" ~count:42]

(* ✓ Also works - variable *)
let count = 42 in
[%log.info "Message" ~count]

(* ✓ Also works - computed value *)
let count = List.length items in
[%log.info "Message" ~count]

(* ✓ Also works - function results *)
let user = get_user_id () in
[%log.info "Message" ~user]
```

**How it works:**
- Literals are converted at compile time (zero overhead)
- Variables use runtime type-directed conversion (`Flo_ppx_runtime.auto`)
- Automatic type detection for: string, int, float, bool, int64
- Works seamlessly with OCaml's type inference

## Feature 3: Span Annotations

### Usage

```ocaml
let result = [%span
  begin
    [%log.info "Processing data"];
    process_data ()
  end
]
```

### Expands to:

```ocaml
let result = Flo_structured.in_span "span" (fun _span ->
  begin
    [%log.info "Processing data"];
    process_data ()
  end
)
```

### Nested Spans

```ocaml
[%span
  begin
    [%log.info "Outer span"];
    let x = [%span compute_x ()] in
    let y = [%span compute_y ()] in
    combine x y
  end
]
```

### Features

- **Automatic trace_id generation** - Creates new trace if not in context
- **Parent span linking** - Child spans reference parent span_id
- **Duration tracking** - Logs span completion with duration_ms
- **Exception-safe** - Span ends even if exception occurs
- **Transparent** - Doesn't change return value or type

## Combining Features

You can use all three features together:

```ocaml
let handle_request () = [%span
  begin
    [%log.info "Request received"
      ~method_:"POST"
      ~path:"/api/orders"];

    let result = process_order () in

    [%log.success "Request completed"
      ~status:201
      ~duration_ms:42.5];

    result
  end
]
```

## Troubleshooting

### Error: "Unbound module Flo_ppx_runtime"

**Cause:** The PPX runtime module is not available.

**Solution:** Make sure you have `flo` library in your dependencies:

```dune
(executable
 (name my_app)
 (libraries flo)  ; Ensure flo is in libraries
 (preprocess (pps ppx_flo)))
```

### Error: "ppx_flo: fields must be labeled arguments"

**Cause:** You're using unlabeled arguments in structured logging.

**Solution:** All fields must be labeled with `~`:

```ocaml
(* ✗ Wrong *)
[%log.info "Message" "value"]

(* ✓ Right *)
[%log.info "Message" ~field:"value"]
```

### PPX not applied / location not captured

**Cause:** Missing `(preprocess (pps ppx_flo))` in dune file.

**Solution:** Add preprocessing to your dune stanza:

```dune
(executable
 (name my_app)
 (libraries flo)
 (preprocess (pps ppx_flo)))  ; Add this line
```

### Compilation is slow

**Cause:** PPX rewriters add compile-time overhead.

**Solution:** This is normal. For faster iteration:
- Use `dune build -w` (watch mode)
- Build in release mode: `dune build --profile=release`
- The runtime performance is not affected

## Performance Considerations

### Compile-time

- **PPX overhead**: ~5-10% slower compilation
- **Recommendation**: Use watch mode during development

### Runtime

- **Zero overhead**: PPX transformations are done at compile time
- **Location capture**: No runtime cost compared to manual location passing
- **Structured fields**: Same performance as manual API
- **Span annotations**: Identical to calling `Flo_structured.in_span`

## Best Practices

### 1. Use PPX for ergonomic logging (works with both literals and variables)

```ocaml
(* Great: Static configuration with literals *)
[%log.info "Server started" ~port:8080 ~env:"production"]

(* Great: Dynamic data with variables *)
let user_id = get_user_id () in
let duration = compute_duration () in
[%log.info "Request processed" ~user_id ~duration]
```

### 2. Combine PPX location with manual fields

```ocaml
(* Get automatic location capture + dynamic fields *)
let log_with_user user_id =
  Flo.info_fields "Action performed" ~fields:[
    ("user_id", Value.String user_id);
    ("timestamp", Value.Float (Unix.gettimeofday ()));
  ]
```

### 3. Use spans for high-level operations

```ocaml
(* Wrap business logic in spans *)
let handle_order order_id = [%span
  begin
    validate_order order_id;
    process_payment order_id;
    send_confirmation order_id
  end
]
```

### 4. Use computed values directly in PPX

```ocaml
let process_batch items =
  let size = List.length items in
  [%log.info "Starting batch" ~size];  (* Works with variables! *)

  (* You can also use complex expressions *)
  [%log.info "Processing" ~total:(List.length items * 2)];
```

## Examples

See `examples/ppx_usage.ml` for comprehensive examples of all PPX features.

## API Compatibility

The PPX is **100% compatible** with the manual API:

- PPX-generated code calls the same Flo functions
- You can mix PPX and manual API in the same file
- No performance difference between PPX and manual
- All features available in both PPX and manual forms

## Future Enhancements

Potential future additions (not currently implemented):

- Custom span names in [%span] (currently fixed to "span")
- Function argument auto-capture in spans
- Format string support in PPX extensions (e.g., `[%log.infof "Count: %d" count]`)
- Type-safe field validation at compile time

---

For more information:
- See `DESIGN.md` for architecture
- See `examples/ppx_usage.ml` for working examples
- See test files `test/test_ppx_*.ml` for edge cases
