# Flō Implementation Plan

## Master Checklist - Phase 1

### Core Foundation
- [x] Task 1.1: Implement `Severity` module with OpenTelemetry compliance (Est: 50 LOC)
- [x] Task 1.2: Implement `Location` module for source location tracking (Est: 80 LOC)
- [x] Task 1.3: Implement `Value` module for type-safe structured values (Est: 150 LOC)
- [x] Task 1.4: Implement `Trace_context` module with W3C Trace Context (Est: 200 LOC)
- [x] Task 1.5: Implement `Record` module for log records (Est: 100 LOC)
- [x] Task 1.6: Implement `Flo_core` contravariant logger primitives (Est: 250 LOC)
- [x] Task 1.7: Implement `Flo_context` for fiber-local storage with Eio (Est: 200 LOC)
- [x] Task 1.8: Implement `Flo_format_pretty` for console output (Est: 300 LOC)
- [x] Task 1.9: Implement `Flo_sink_console` for console logging (Est: 150 LOC)
- [x] Task 1.10: Implement `Flo` simple API layer with global logger (Est: 300 LOC)
- [x] Task 1.11: Create `examples/simple_app.ml` demonstrating basic usage (Est: 50 LOC)
- [x] Task 1.12: Write unit tests for Severity, Location, Value modules (Est: 200 LOC)
- [x] Task 1.13: Write unit tests for Trace_context and Record modules (Est: 200 LOC)
- [x] Task 1.14: Write integration tests for core logging flow (Est: 150 LOC)
- [x] Task 1.15: Update master checklist and commit Phase 1

---

## Detailed Task Breakdown

### Phase 1: Core Foundation
**Goal**: Build the foundational types and simple console logging capability
**Success Criteria**: Can log messages to console with fiber-local context

---

#### Task 1.1: Implement Severity Module
**File**: `lib/severity.mli`, `lib/severity.ml`
**Lines**: ~50
**Dependencies**: None
**API Coverage**:
```ocaml
type t = Trace | Debug | Info | Success | Warn | Error | Fatal
val to_string : t -> string
val to_number : t -> int
val of_string : string -> (t, string) result
```

**Deliverables**:
1. Define severity type with 7 levels
2. Implement OpenTelemetry severity number mapping (5, 10, 20, 22, 30, 40, 50)
3. String conversion functions
4. Comparison support (derive compare)

**Example**: Used in `examples/simple_app.ml` - basic logging calls

**Tests**: `test/test_severity.ml`
- Test to_string/of_string round-trip
- Test to_number matches OpenTelemetry spec
- Test ordering (Trace < Debug < Info, etc.)

---

#### Task 1.2: Implement Location Module
**File**: `lib/location.mli`, `lib/location.ml`
**Lines**: ~80
**Dependencies**: None
**API Coverage**:
```ocaml
type t = {
  file : string;
  line : int;
  column : int;
  module_name : string;
  function_name : string option;
}
val unknown : t
val to_string : t -> string
```

**Deliverables**:
1. Define location record type
2. Implement `unknown` sentinel value
3. Pretty-print location as "file.ml:123:45" or "Module.function"
4. Support optional function_name

**Example**: Used in `examples/simple_app.ml` - logs show source location

**Tests**: `test/test_location.ml`
- Test to_string formatting
- Test unknown location handling
- Test with/without function_name

---

#### Task 1.3: Implement Value Module
**File**: `lib/value.mli`, `lib/value.ml`
**Lines**: ~150
**Dependencies**: `yojson` (add to dune)
**API Coverage**:
```ocaml
type t =
  | String of string
  | Int of int64
  | Float of float
  | Bool of bool
  | Array of t list
  | Object of (string * t) list
  | Bytes of bytes
  | Null
val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> t
```

**Deliverables**:
1. Define recursive type for structured values
2. Implement bidirectional Yojson conversion
3. Add helper constructors (string, int, float, bool, etc.)
4. Recursive traversal for nested structures

**Example**: Used in `examples/simple_app.ml` - structured field values

**Tests**: `test/test_value.ml`
- Test to_yojson/of_yojson round-trip
- Test nested Object and Array
- Test all primitive types
- Test Bytes handling

---

#### Task 1.4: Implement Trace_context Module
**File**: `lib/trace_context.mli`, `lib/trace_context.ml`
**Lines**: ~200
**Dependencies**: None
**API Coverage**:
```ocaml
type span_context = {
  trace_id : string;
  span_id : string;
  parent_span_id : string option;
  trace_flags : int;
}
val generate_trace_id : unit -> string
val generate_span_id : unit -> string
val create_child : span_context -> span_context
val parse_traceparent : string -> (span_context, string) result
val format_traceparent : span_context -> string
```

**Deliverables**:
1. Define span_context type
2. Generate cryptographically random trace_id (32 hex chars) using Random
3. Generate span_id (16 hex chars)
4. Parse W3C traceparent: "00-{trace_id}-{span_id}-{flags}"
5. Format traceparent string
6. Create child span with new span_id

**Example**: Used in `examples/web_service.ml` (Phase 2)

**Tests**: `test/test_trace_context.ml`
- Test parse_traceparent/format_traceparent round-trip
- Test generate_trace_id/span_id uniqueness
- Test create_child preserves trace_id
- Test invalid traceparent parsing

---

#### Task 1.5: Implement Record Module
**File**: `lib/record.mli`, `lib/record.ml`
**Lines**: ~100
**Dependencies**: `Severity`, `Location`, `Trace_context`, `Value`, `ptime`
**API Coverage**:
```ocaml
type t = {
  timestamp : Ptime.t;
  observed_timestamp : Ptime.t option;
  severity : Severity.t;
  message : string;
  location : Location.t option;
  span_context : Trace_context.span_context option;
  attributes : (string * Value.t) list;
  body : Value.t option;
  event_name : string option;
}
```

**Deliverables**:
1. Define record type following OpenTelemetry log data model
2. Add helper constructor with defaults
3. Add builder pattern helpers (with_location, with_attributes, etc.)
4. Pretty-print for debugging

**Example**: Internal type used by all examples

**Tests**: `test/test_record.ml`
- Test record construction
- Test builder pattern
- Test optional fields

---

#### Task 1.6: Implement Flo_core Module
**File**: `lib/flo_core.mli`, `lib/flo_core.ml`
**Lines**: ~250
**Dependencies**: `Record`
**API Coverage**:
```ocaml
type ('m, 'msg) t = 'msg -> 'm
val make : ('msg -> 'm) -> ('m, 'msg) t
val noop : ('m, 'msg) t
val contramap : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t
val (>$<) : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t
val combine : ('m, 'msg) t -> ('m, 'msg) t -> ('m, 'msg) t
val (<>) : ('m, 'msg) t -> ('m, 'msg) t -> ('m, 'msg) t
val combine_all : ('m, 'msg) t list -> ('m, 'msg) t
val filter : ('msg -> bool) -> ('m, 'msg) t -> ('m, 'msg) t
val level_filter : Severity.t -> ('m, Record.t) t -> ('m, Record.t) t
val log : ('m, 'msg) t -> 'msg -> 'm
val (<&) : ('m, 'msg) t -> 'msg -> 'm
```

**Deliverables**:
1. Define contravariant logger type
2. Implement contramap transformation
3. Implement monoid combine operation
4. Implement filtering
5. Add infix operators for ergonomics
6. Add level-based filtering for records

**Example**: Used in `examples/compositional_logging.ml` (Phase 2)

**Tests**: `test/test_flo_core.ml`
- Test contramap transformations
- Test combine composition
- Test filter predicates
- Test noop logger
- Test level_filter

---

#### Task 1.7: Implement Flo_context Module
**File**: `lib/flo_context.mli`, `lib/flo_context.ml`
**Lines**: ~200
**Dependencies**: `Eio`, `Value`
**API Coverage**:
```ocaml
type context
val context_key : context Eio.Fiber.key
val empty : context
val add : string -> Value.t -> context -> context
val get : string -> context -> Value.t option
val merge : context -> context -> context
val with_context : context -> (unit -> 'a) -> 'a
val get_current : unit -> context option
```

**Deliverables**:
1. Define context type (string map of Value.t)
2. Create Eio.Fiber.key for fiber-local storage
3. Implement context operations (add, get, merge)
4. Implement with_context scope binding
5. Merge parent context with child context
6. get_current retrieves fiber-local context

**Example**: Used in `examples/simple_app.ml` - automatic context propagation

**Tests**: `test/test_flo_context.ml`
- Test context add/get
- Test context merging
- Test fiber-local storage with Eio
- Test nested with_context scopes

---

#### Task 1.8: Implement Flo_format_pretty Module
**File**: `lib/flo_format_pretty.mli`, `lib/flo_format_pretty.ml`
**Lines**: ~300
**Dependencies**: `Record`, `Severity`, `Location`, `ptime`
**API Coverage**:
```ocaml
module type FORMATTER = sig
  val format : Record.t -> string
  val parse : string -> (Record.t, string) result
end
include FORMATTER
val with_colors : bool -> (module FORMATTER)
```

**Deliverables**:
1. Format record as human-readable colored output
2. ANSI color codes for severity levels:
   - Trace: dim gray
   - Debug: cyan
   - Info: blue
   - Success: green (Loguru-style)
   - Warn: yellow
   - Error: red
   - Fatal: bold red
3. Format: `[TIMESTAMP] [LEVEL] message (location.ml:123)`
4. Optional: Show attributes as key=value
5. Support colorize on/off

**Example**: Used in `examples/simple_app.ml` - pretty console output

**Tests**: `test/test_flo_format_pretty.ml`
- Test formatting with colors
- Test formatting without colors
- Test all severity levels
- Test with/without location
- Test with attributes

---

#### Task 1.9: Implement Flo_sink_console Module
**File**: `lib/flo_sink_console.mli`, `lib/flo_sink_console.ml`
**Lines**: ~150
**Dependencies**: `Flo_format_pretty`, `Record`, `Eio`
**API Coverage**:
```ocaml
type config = {
  output : [ `Stderr | `Stdout ];
  colorize : bool;
  format : [ `Pretty | `Json | `Logfmt ];
  level : Severity.t;
}
type t
val create : sw:Eio.Switch.t -> config -> t
val write : t -> Record.t -> unit
val flush : t -> unit
val permits : t -> Record.t -> bool
```

**Deliverables**:
1. Define console sink type and config
2. Create sink with Eio stdout/stderr
3. Implement write using formatter
4. Implement level-based filtering (permits)
5. Thread-safe writes using Eio
6. Auto-flush on each write for console

**Example**: Used in `examples/simple_app.ml` - default console output

**Tests**: `test/test_flo_sink_console.ml`
- Test write to stderr/stdout
- Test level filtering
- Test flush operation
- Test colorize on/off

---

#### Task 1.10: Implement Flo Simple API Layer
**File**: `lib/flo.mli`, `lib/flo.ml`
**Lines**: ~300
**Dependencies**: `Flo_core`, `Flo_context`, `Flo_sink_console`, `Record`
**API Coverage**:
```ocaml
(* Zero-configuration logging *)
val trace : string -> unit
val debug : string -> unit
val info : string -> unit
val success : string -> unit
val warn : string -> unit
val error : string -> unit
val fatal : string -> unit

(* Printf-style *)
val tracef : ('a, unit, string, unit) format4 -> 'a
val debugf : ('a, unit, string, unit) format4 -> 'a
val infof : ('a, unit, string, unit) format4 -> 'a
val successf : ('a, unit, string, unit) format4 -> 'a
val warnf : ('a, unit, string, unit) format4 -> 'a
val errorf : ('a, unit, string, unit) format4 -> 'a
val fatalf : ('a, unit, string, unit) format4 -> 'a

(* Structured logging *)
val with_fields : (string * Value.t) list -> unit
val info_fields : string -> fields:(string * Value.t) list -> unit

(* Common field shortcuts *)
val http_method : string -> string * Value.t
val http_status : int -> string * Value.t
val user_id : string -> string * Value.t
val duration_ms : float -> string * Value.t
val error_type : string -> string * Value.t
val error_message : string -> string * Value.t

(* Context propagation *)
val with_trace_id : string -> (unit -> 'a) -> 'a
val with_span : string -> (unit -> 'a) -> 'a
val with_user : string -> (unit -> 'a) -> 'a
val bind : (string * Value.t) list -> unit
val get_trace_id : unit -> string option
val get_span_id : unit -> string option

(* Exception handling *)
val catch : ?level:Severity.t -> (unit -> 'a) -> 'a option
val exception_ : exn -> unit

(* Sink management *)
type sink_config = {
  format : [ `Json | `Logfmt | `Pretty ];
  level : Severity.t;
  colorize : bool;
  filter : (Record.t -> bool) option;
}
val add_sink :
  ?config:sink_config ->
  [ `Stderr | `File of string | `Custom of (Record.t -> unit) ] -> int
val remove_sink : int -> unit

(* Configuration *)
val set_level : Severity.t -> unit
val enable : string -> unit
val disable : string -> unit
```

**Deliverables**:
1. Initialize global logger with console sink (stderr, pretty, colorized)
2. Implement 7 level functions (trace, debug, info, success, warn, error, fatal)
3. Implement printf-style variants using Printf.ksprintf
4. Implement structured logging with fields
5. Semantic convention helpers (http_method, http_status, etc.)
6. Context propagation wrappers
7. Exception catching decorator
8. Global sink registry with add/remove
9. Global level configuration

**Example**: Primary API for `examples/simple_app.ml`

**Tests**: `test/test_flo.ml`
- Test basic logging functions
- Test printf-style formatting
- Test structured fields
- Test context propagation
- Test exception catching
- Test sink management
- Test level filtering

---

#### Task 1.11: Create examples/simple_app.ml
**File**: `examples/simple_app.ml`, `examples/dune`
**Lines**: ~50
**Dependencies**: `Flo`, `Eio_main`
**API Coverage**: Demonstrates basic usage from DESIGN.md:
```ocaml
(* Zero configuration - just use it *)
Flo.info "Application started"
Flo.successf "Processed %d items in %fs" count duration

(* Structured logging *)
Flo.info_fields "HTTP request" ~fields:[
  Flo.http_method "POST";
  Flo.http_status 201;
  Flo.duration_ms 42.5;
]

(* Context for request *)
Flo.with_span "handle_order" (fun () ->
  Flo.bind [Flo.user_id "alice"; ("order_id", String "12345")];
  Flo.info "Processing order";
  process_order ()
)

(* Exception handling *)
Flo.catch (fun () ->
  risky_operation ()
)
```

**Deliverables**:
1. Simple example matching DESIGN.md usage section
2. Demonstrates zero-configuration logging
3. Shows structured fields
4. Shows context propagation
5. Shows exception handling
6. Runnable with `dune exec examples/simple_app.exe`

---

#### Task 1.12: Unit Tests for Severity, Location, Value
**File**: `test/test_severity.ml`, `test/test_location.ml`, `test/test_value.ml`, `test/dune`
**Lines**: ~200
**Dependencies**: `alcotest`, core modules

**Test Coverage**:
1. **Severity**:
   - to_string/of_string round-trip
   - to_number OpenTelemetry compliance
   - Ordering and comparison
   - Invalid string parsing

2. **Location**:
   - to_string formatting
   - unknown sentinel
   - Optional function_name

3. **Value**:
   - to_yojson/of_yojson round-trip
   - All primitive types
   - Nested Object and Array
   - Bytes encoding

**Deliverables**: Runnable test suite with `dune test`

---

#### Task 1.13: Unit Tests for Trace_context and Record
**File**: `test/test_trace_context.ml`, `test/test_record.ml`
**Lines**: ~200

**Test Coverage**:
1. **Trace_context**:
   - parse_traceparent/format_traceparent round-trip
   - generate_trace_id/span_id format validation
   - create_child span linking
   - Invalid traceparent handling

2. **Record**:
   - Record construction with all fields
   - Builder pattern helpers
   - Optional field handling

**Deliverables**: Comprehensive test coverage

---

#### Task 1.14: Integration Tests for Core Logging Flow
**File**: `test/test_integration.ml`
**Lines**: ~150

**Test Coverage**:
1. End-to-end logging flow
2. Fiber-local context propagation
3. Multiple sink composition
4. Level filtering across pipeline
5. Concurrent logging from multiple fibers

**Deliverables**: Integration tests validating complete system

---

#### Task 1.15: Update Master Checklist and Commit Phase 1
**File**: `PLAN.md`
**Action**:
1. Mark all Phase 1 tasks as completed: `[x]`
2. Git commit with message:
   ```
   Phase 1 complete: Core foundation

   - Implemented all core types (Severity, Location, Value, Trace_context, Record)
   - Implemented Flo_core compositional primitives
   - Implemented Flo_context for fiber-local storage
   - Implemented console sink with pretty formatter
   - Implemented Flo simple API layer
   - Created simple_app.ml example
   - 100% test coverage, all tests passing
   ```

---

## Future Phases (Outline)

### Phase 2: Structured Logging (8 tasks, ~1200 LOC)
- [x] Task 2.1: Implement `Flo_format_json` formatter
- [x] Task 2.2: Implement `Flo_format_logfmt` formatter
- [x] Task 2.3: Implement `Flo_structured` GADT-based type-safe keys
- [x] Task 2.4: Implement `Flo_structured` span management
- [ ] Task 2.5: Implement `Flo_semconv` semantic conventions
- [x] Task 2.6: Create `examples/structured_events.ml`
- [ ] Task 2.7: Write tests for formatters
- [ ] Task 2.8: Update checklist and commit Phase 2

### Phase 3: File Sinks & Rotation (6 tasks, ~900 LOC)
- [ ] Task 3.1: Implement `Flo_sink_file` basic file sink
- [ ] Task 3.2: Implement file rotation (size-based)
- [ ] Task 3.3: Implement file rotation (time-based)
- [ ] Task 3.4: Implement file retention policies
- [ ] Task 3.5: Create `examples/file_logging.ml`
- [ ] Task 3.6: Update checklist and commit Phase 3

### Phase 4: Async Sinks & Performance (5 tasks, ~800 LOC)
- [ ] Task 4.1: Implement `Flo_sink_async` with ring buffer
- [ ] Task 4.2: Implement batching and flush interval
- [ ] Task 4.3: Implement drain on shutdown
- [ ] Task 4.4: Create `examples/perf_app.ml`
- [ ] Task 4.5: Update checklist and commit Phase 4

### Phase 5: Distributed Tracing Integration (6 tasks, ~700 LOC)
- [ ] Task 5.1: Implement `Flo_eio` HTTP context extraction
- [ ] Task 5.2: Implement trace context injection
- [ ] Task 5.3: Implement with_http_context wrapper
- [ ] Task 5.4: Enhance span management with parent links
- [ ] Task 5.5: Create `examples/web_service.ml`
- [ ] Task 5.6: Update checklist and commit Phase 5

### Phase 6: Polish & Documentation (7 tasks, ~600 LOC)
- [ ] Task 6.1: Implement PPX for automatic location capture
- [ ] Task 6.2: Enhance pretty formatter with templates
- [ ] Task 6.3: Add compression support for rotating files
- [ ] Task 6.4: Write comprehensive README.md
- [ ] Task 6.5: Write TUTORIAL.md with common patterns
- [ ] Task 6.6: Generate API documentation with odoc
- [ ] Task 6.7: Update checklist and commit Phase 6

---

## API Coverage Matrix

| API Surface | Implementation Task | Example File | Test File |
|-------------|-------------------|--------------|-----------|
| `Severity` | Task 1.1 | `simple_app.ml` | `test_severity.ml` |
| `Location` | Task 1.2 | `simple_app.ml` | `test_location.ml` |
| `Value` | Task 1.3 | `simple_app.ml` | `test_value.ml` |
| `Trace_context` | Task 1.4 | `web_service.ml` | `test_trace_context.ml` |
| `Record` | Task 1.5 | Internal | `test_record.ml` |
| `Flo_core` | Task 1.6 | `compositional_logging.ml` | `test_flo_core.ml` |
| `Flo_context` | Task 1.7 | `simple_app.ml` | `test_flo_context.ml` |
| `Flo_format_pretty` | Task 1.8 | `simple_app.ml` | `test_flo_format_pretty.ml` |
| `Flo_sink_console` | Task 1.9 | `simple_app.ml` | `test_flo_sink_console.ml` |
| `Flo` (simple API) | Task 1.10 | `simple_app.ml` | `test_flo.ml` |
| `Flo_format_json` | Task 2.1 | `web_service.ml` | `test_flo_format_json.ml` |
| `Flo_format_logfmt` | Task 2.2 | `logfmt_app.ml` | `test_flo_format_logfmt.ml` |
| `Flo_structured` | Task 2.3-2.4 | `structured_events.ml` | `test_flo_structured.ml` |
| `Flo_sink_file` | Task 3.1-3.4 | `file_logging.ml` | `test_flo_sink_file.ml` |
| `Flo_sink_async` | Task 4.1-4.3 | `perf_app.ml` | `test_flo_sink_async.ml` |
| `Flo_eio` | Task 5.1-5.3 | `web_service.ml` | `test_flo_eio.ml` |
| `ppx_flo` | Task 6.1 | `ppx_example.ml` | `test_ppx_flo.ml` |

---

## Validation Criteria

Each task is considered complete when:

1. **Implementation**: Code written, compiles without warnings
2. **API Coverage**: All public functions from DESIGN.md implemented
3. **Example**: Corresponding example file exists and runs
4. **Tests**: Unit tests written, all passing, >90% coverage
5. **Documentation**: Docstrings in .mli files match DESIGN.md
6. **No Warnings**: `dune build` produces zero warnings

---

## Dependencies & Build System

### Opam Dependencies
```
ocaml >= 5.0
dune >= 3.0
eio >= 0.12
yojson >= 2.0
ptime >= 1.0
alcotest >= 1.6 (test only)
```

### Directory Structure
```
flo/
├── lib/
│   ├── severity.ml{i}
│   ├── location.ml{i}
│   ├── value.ml{i}
│   ├── trace_context.ml{i}
│   ├── record.ml{i}
│   ├── flo_core.ml{i}
│   ├── flo_context.ml{i}
│   ├── flo_format_pretty.ml{i}
│   ├── flo_sink_console.ml{i}
│   ├── flo.ml{i}
│   └── dune
├── examples/
│   ├── simple_app.ml
│   └── dune
├── test/
│   ├── test_*.ml
│   └── dune
├── DESIGN.md
├── PLAN.md
└── dune-project
```

---

## Execution Strategy

### Iterative Development
1. Implement task N
2. Write corresponding test
3. Create/update example
4. Run full test suite
5. Verify example runs
6. Update checklist
7. Commit with descriptive message
8. Move to task N+1

### Commit Message Format
```
Task X.Y: [Brief description]

- Bullet point of what was implemented
- Reference to DESIGN.md section
- Reference to example file

Tests: test_*.ml
Example: examples/*.ml
```

### Quality Gates
- No task proceeds until previous task complete
- All tests must pass before committing
- Examples must run successfully
- No compiler warnings allowed

---

## Notes

- Each task is designed to be ≤300 lines to maintain focus
- Tasks have clear dependencies to enable parallel work (future)
- Every public API function must have a working example
- Test coverage target: >90% for core modules
- Integration tests validate end-to-end flows
- Examples should be copy-pasteable into user projects
