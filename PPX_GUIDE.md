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

### Important Limitations

⚠️ **The PPX only works with literal values, not variables:**

```ocaml
(* ✓ Works - literal value *)
[%log.info "Message" ~count:42]

(* ✗ Doesn't work - variable *)
let count = 42 in
[%log.info "Message" ~count]  (* ERROR *)

(* ✓ Workaround - use manual API *)
let count = 42 in
Flo.info_fields "Message" ~fields:[
  ("count", Value.Int (Int64.of_int count))
]
```

**Why this limitation?**
- PPX runs at compile time, before runtime values exist
- Variables require runtime type information
- Use manual API for dynamic/computed values

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

### Error: "This expression has type X but an expression was expected of type Value.t"

**Cause:** You're using a variable in a PPX structured log field.

**Solution:** Use literals or switch to the manual API:

```ocaml
(* Instead of: *)
let user_id = get_user_id () in
[%log.info "User" ~user_id]  (* ERROR *)

(* Use: *)
let user_id = get_user_id () in
Flo.info_fields "User" ~fields:[
  ("user_id", Value.String user_id)
]
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

### 1. Use PPX for literals, manual API for dynamic values

```ocaml
(* Good: Static configuration *)
[%log.info "Server started" ~port:8080 ~env:"production"]

(* Good: Dynamic data with manual API *)
Flo.info_fields "Request processed" ~fields:[
  ("user_id", Value.String user_id);
  ("duration_ms", Value.Float duration);
]
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

### 4. Mix PPX with manual API as needed

```ocaml
let process_batch items =
  [%log.info "Starting batch" ~size:(List.length items)];  (* ERROR - variable *)

  (* Use manual API instead *)
  Flo.info_fields "Starting batch" ~fields:[
    ("size", Value.Int (Int64.of_int (List.length items)))
  ]
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

- Variable capture in structured fields
- Custom span names (currently fixed to "span")
- Function argument auto-capture in spans
- Format string support in PPX extensions

---

For more information:
- See `DESIGN.md` for architecture
- See `examples/ppx_usage.ml` for working examples
- See test files `test/test_ppx_*.ml` for edge cases
