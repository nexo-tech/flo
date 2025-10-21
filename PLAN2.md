# Flō Namespace/Scoped Logging - Implementation Plan

## Problem Statement

**Use Case**: When using Flo in a library, the application developer needs fine-grained control over log verbosity per library/component.

**Example Scenario**:
```
User Application
  ├── Uses LibraryA (uses Flo internally)
  ├── Uses LibraryB (uses Flo internally)
  └── Application code (uses Flo)
```

**Desired Configuration**:
```ocaml
(* Application wants different verbosity for each component *)
Flo.set_level_for "library_a.database" Debug;
Flo.set_level_for "library_b" Warn;
Flo.set_level_for "myapp.api" Info;
Flo.set_level Debug;  (* Default for root namespace *)
```

## Design Philosophy

Following Flo's core principles:
1. **Zero-config default** - Existing global API continues to work without changes
2. **Type-safe** - Compile-time guarantees where possible
3. **Composable** - Functors and modules for flexibility
4. **Eio-native** - Fiber-local namespace propagation
5. **Minimal overhead** - Fast path for disabled logs

## Proposed Solution

### Hierarchical Namespace System

Similar to:
- Python's `logging.getLogger(name)`
- Haskell's `katip` namespaces
- OCaml's `logs` with `Logs.Src`
- Rust's `tracing` targets

**Key Features**:
1. **Dotted namespaces**: `"mylib.database.pool"`
2. **Hierarchical matching**: Searches `"a.b.c"` → `"a.b"` → `"a"` → `""` (root)
3. **Per-namespace levels**: Each namespace can have its own minimum level
4. **Backward compatible**: Global functions use root namespace `""`

---

## API Specification

### 1. Scoped Logger API

```ocaml
(** flo.mli additions *)

(** {1 Namespace Support} *)

(** Scoped logger for namespace-based filtering.

    Libraries should create their own namespace to allow applications
    to configure logging verbosity per component.

    Example:
    {[
      (* In your library *)
      module Log = struct
        let namespace = "mylib.database"
        let info msg = Flo.scoped_info namespace msg
        let debug msg = Flo.scoped_debug namespace msg
      end

      (* Use in library code *)
      Log.info "Connection established"

      (* Application configures *)
      Flo.set_level_for "mylib.database" Debug
    ]}
*)

(** Scoped logging at each severity level *)
val scoped_trace : string -> ?location:Location.t -> string -> unit
val scoped_debug : string -> ?location:Location.t -> string -> unit
val scoped_info : string -> ?location:Location.t -> string -> unit
val scoped_success : string -> ?location:Location.t -> string -> unit
val scoped_warn : string -> ?location:Location.t -> string -> unit
val scoped_error : string -> ?location:Location.t -> string -> unit
val scoped_fatal : string -> ?location:Location.t -> string -> unit

(** Scoped printf-style logging *)
val scoped_tracef : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_debugf : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_infof : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_successf : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_warnf : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_errorf : string -> ('a, unit, string, unit) format4 -> 'a
val scoped_fatalf : string -> ('a, unit, string, unit) format4 -> 'a

(** Scoped structured logging *)
val scoped_info_fields : string -> ?location:Location.t -> string ->
  fields:(string * Value.t) list -> unit
(* ... similar for other levels *)

(** {2 Namespace Configuration} *)

(** Set minimum log level for a specific namespace.

    When a log is emitted with namespace "a.b.c", the effective level
    is determined by searching in order:
    1. Exact match: "a.b.c"
    2. Parent namespaces: "a.b", then "a"
    3. Root: "" (set via set_level)

    @param namespace Dotted namespace (e.g., "mylib.database")
    @param level Minimum severity level
*)
val set_level_for : string -> Severity.t -> unit

(** Get configured level for a namespace.

    Returns None if no level set (will use parent or root).

    @param namespace The namespace to query
    @return Some level if configured, None otherwise
*)
val get_level_for : string -> Severity.t option

(** Get effective level for a namespace (includes inheritance).

    This resolves the actual level after checking the hierarchy.

    @param namespace The namespace to query
    @return The effective level (never None)
*)
val get_effective_level : string -> Severity.t

(** Clear level for a namespace (will use parent/root level).

    @param namespace The namespace to clear
*)
val clear_level_for : string -> unit

(** List all configured namespace levels.

    @return List of (namespace, level) pairs
*)
val get_all_levels : unit -> (string * Severity.t) list

(** {2 Namespace Context} *)

(** Execute function with namespace in fiber-local context.

    All logs within the function (and child fibers) will use this
    namespace unless overridden.

    Example:
    {[
      Flo.with_namespace "mylib.handler" (fun () ->
        Flo.info "Using mylib.handler namespace";
        process ()
      )
    ]}

    @param namespace The namespace to set
    @param f The function to execute
    @return Result of f
*)
val with_namespace : string -> (unit -> 'a) -> 'a

(** Get current namespace from fiber-local context.

    @return Some namespace if set, None for root namespace
*)
val get_current_namespace : unit -> string option
```

### 2. Functor-Based Scoped Loggers

```ocaml
(** flo_scoped.mli - Type-safe scoped loggers via functors *)

(** Signature for namespace specification *)
module type NAMESPACE = sig
  val namespace : string
end

(** Signature for scoped logger *)
module type LOGGER = sig
  (** The namespace for this logger *)
  val namespace : string

  (** Simple logging API (same as Flo but scoped) *)
  val trace : ?location:Location.t -> string -> unit
  val debug : ?location:Location.t -> string -> unit
  val info : ?location:Location.t -> string -> unit
  val success : ?location:Location.t -> string -> unit
  val warn : ?location:Location.t -> string -> unit
  val error : ?location:Location.t -> string -> unit
  val fatal : ?location:Location.t -> string -> unit

  (** Printf-style *)
  val tracef : ('a, unit, string, unit) format4 -> 'a
  val debugf : ('a, unit, string, unit) format4 -> 'a
  val infof : ('a, unit, string, unit) format4 -> 'a
  val successf : ('a, unit, string, unit) format4 -> 'a
  val warnf : ('a, unit, string, unit) format4 -> 'a
  val errorf : ('a, unit, string, unit) format4 -> 'a
  val fatalf : ('a, unit, string, unit) format4 -> 'a

  (** Structured logging *)
  val info_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  (* ... etc *)

  (** Context propagation (scoped to this namespace) *)
  val with_span : string -> (unit -> 'a) -> 'a
  val bind : (string * Value.t) list -> unit

  (** Configuration *)
  val set_level : Severity.t -> unit
  val get_level : unit -> Severity.t option
  val get_effective_level : unit -> Severity.t
end

(** Create a scoped logger with type safety.

    Example:
    {[
      (* In your library *)
      module Log = Flo_scoped.Make(struct
        let namespace = "mylib.database"
      end)

      (* Use like global Flo but automatically scoped *)
      let connect () =
        Log.info "Connecting to database";
        Log.debug_fields "Connection params" ~fields:[
          ("host", Value.string db_host);
          ("port", Value.int db_port);
        ]
    ]}
*)
module Make (N : NAMESPACE) : LOGGER

(** Create scoped logger with runtime namespace.

    Use when namespace is determined at runtime.

    Example:
    {[
      let logger = Flo_scoped.create "mylib.database"
      let module Log = (val logger : Flo_scoped.LOGGER) in
      Log.info "Hello"
    ]}
*)
val create : string -> (module LOGGER)
```

### 3. Record Enhancement

```ocaml
(** record.mli additions *)

(** Add namespace to record.

    @param namespace The namespace (e.g., "mylib.database")
    @param record The record
    @return New record with namespace set
*)
val with_namespace : string -> t -> t

(** Get namespace from record.

    @param record The record
    @return Some namespace if set, None for root
*)
val namespace : t -> string option
```

---

## Implementation Phases

### Phase 1: Core Namespace Infrastructure (Week 1)

**Goal**: Implement basic namespace storage and hierarchical lookup.

#### Tasks:

- [x] **1.1. Namespace Registry Module**
  - Create `lib/flo_namespace.ml` and `.mli`
  - Implement namespace → level mapping (hash table)
  - Hierarchical lookup algorithm
  - Thread-safe access (use `Eio.Mutex` or atomic refs)

- [x] **1.2. Update Record Type**
  - Add `namespace : string option` field to `Record.t`
  - Implement `Record.with_namespace`
  - Implement `Record.namespace`
  - Update record constructors

- [x] **1.3. Update Dispatch Logic**
  - Modify `Flo.dispatch_record` to check namespace level
  - Implement hierarchical level resolution
  - Add namespace to formatted output
  - Performance: cache effective levels

- [x] **1.4. Basic Configuration API**
  - Implement `Flo.set_level_for`
  - Implement `Flo.get_level_for`
  - Implement `Flo.get_effective_level`
  - Implement `Flo.clear_level_for`
  - Implement `Flo.get_all_levels`

- [x] **1.5. Unit Tests**
  - Test hierarchical level lookup
  - Test namespace configuration
  - Test level inheritance (parent → child)
  - Test edge cases (empty namespace, deep nesting)
  - Test dispatch filtering with namespaces
  - Test cache invalidation
  - Test formatter output
  - Add to `test/test_namespace.ml`

- [x] **Commit**: Phase 1 complete - Core namespace infrastructure

---

### Phase 2: Scoped Logging API (Week 1-2)

**Goal**: Add scoped logging functions to main API.

#### Tasks:

- [x] **2.1. Scoped Functions in Flo**
  - Implement `scoped_trace`, `scoped_debug`, etc.
  - Implement `scoped_tracef`, `scoped_debugf`, etc.
  - Implement `scoped_*_fields` variants
  - Add namespace parameter to log dispatch

- [x] **2.2. Fiber-Local Namespace Context**
  - Add namespace to `Flo_context`
  - Implement `Flo.with_namespace`
  - Implement `Flo.get_current_namespace`
  - Auto-merge namespace into records

- [x] **2.3. Integration with Existing Context**
  - Ensure namespace works with trace_id, span_id
  - Update `Flo.with_span` to preserve namespace
  - Namespace in structured events

- [x] **2.4. Unit Tests**
  - Test all scoped functions
  - Test namespace context propagation
  - Test namespace + other context
  - Add to `test/test_namespace.ml`

- [x] **2.5. Update Documentation**
  - Add namespace examples to `lib/flo.mli`
  - Document hierarchical behavior
  - Add migration guide

- [x] **Commit**: Phase 2 complete - Scoped logging API

---

### Phase 3: Functor-Based Loggers (Week 2)

**Goal**: Implement `Flo_scoped` module with functors.

#### Tasks:

- [x] **3.1. Create Flo_scoped Module**
  - Create `lib/flo_scoped.ml` and `.mli`
  - Define `NAMESPACE` and `LOGGER` signatures
  - Stub out module structure

- [x] **3.2. Implement Make Functor**
  - Implement `Make` functor
  - Forward all logging calls to `Flo.scoped_*`
  - Implement scoped configuration functions
  - Implement scoped context propagation

- [x] **3.3. Runtime Logger Creation**
  - Implement `Flo_scoped.create`
  - Return first-class module
  - Handle dynamic namespace assignment

- [x] **3.4. Unit Tests**
  - Test functor-based loggers
  - Test multiple loggers simultaneously
  - Test configuration per logger
  - Add to `test/test_flo_scoped.ml`

- [x] **3.5. Example Code**
  - Create `examples/scoped_logging.ml`
  - Demonstrate library usage pattern
  - Show application configuration
  - Show multiple namespaces

- [x] **Commit**: Phase 3 complete - Functor-based loggers

---

### Phase 4: Formatter & Sink Integration (Week 2-3)

**Goal**: Display namespaces in all formatters and sinks.

#### Tasks:

- [ ] **4.1. Update Pretty Formatter**
  - Add namespace to pretty output
  - Color-code namespaces
  - Configurable namespace width/truncation
  - Test in `test/test_flo_format_pretty.ml`

- [ ] **4.2. Update JSON Formatter**
  - Add `"namespace"` field to JSON
  - Follow OpenTelemetry conventions
  - Test in `test/test_flo_format_json.ml`

- [ ] **4.3. Update Logfmt Formatter**
  - Add `namespace=` to logfmt output
  - Test in `test/test_flo_format_logfmt.ml`

- [ ] **4.4. Update Console Sink**
  - Ensure namespace filtering works
  - Test namespace display

- [ ] **4.5. Update File Sink**
  - Namespace in file output
  - Optional namespace-based file rotation

- [ ] **4.6. Update Async Sink**
  - Namespace preserved in async writes

- [ ] **4.7. Integration Tests**
  - Test namespaces with all formatters
  - Test namespaces with all sinks
  - Add to `test/test_integration_namespace.ml`

- [ ] **Commit**: Phase 4 complete - Formatter & sink integration

---

### Phase 5: PPX Support (Week 3)

**Goal**: Add namespace support to `ppx_flo`.

#### Tasks:

- [ ] **5.1. PPX Namespace Attribute**
  - Add `[@flo.namespace "..."]` attribute support
  - Automatically inject namespace into logs
  - Support module-level namespace

- [ ] **5.2. Automatic Namespace from Module Path**
  - Extract module path as namespace
  - `MyLib.Database.connect` → `"mylib.database"`
  - Configurable transformation rules

- [ ] **5.3. PPX Extensions**
  - `[%log.scoped "namespace" "message"]`
  - `let%log.namespace "mylib" = ... in ...`

- [ ] **5.4. PPX Tests**
  - Test namespace attributes
  - Test module path extraction
  - Add to `test/test_ppx_namespace.ml`

- [ ] **5.5. Documentation**
  - Update `PPX_GUIDE.md`
  - Add namespace examples

- [ ] **Commit**: Phase 5 complete - PPX namespace support

---

### Phase 6: Documentation & Examples (Week 3-4)

**Goal**: Comprehensive documentation for namespace feature.

#### Tasks:

- [ ] **6.1. Tutorial Section**
  - Add "Namespace Logging" to `TUTORIAL.md`
  - Step-by-step guide for libraries
  - Step-by-step guide for applications
  - Common patterns and best practices

- [ ] **6.2. Design Documentation**
  - Update `DESIGN.md` with namespace architecture
  - Document hierarchical lookup algorithm
  - Performance characteristics

- [ ] **6.3. README Updates**
  - Add namespace quick example
  - Update feature list

- [ ] **6.4. API Documentation**
  - Complete odoc comments
  - Cross-references
  - Usage examples in docstrings

- [ ] **6.5. Real-World Examples**
  - Create `examples/library_with_logging/` - sample library
  - Create `examples/app_with_library_logging/` - app using library
  - Show configuration patterns

- [ ] **6.6. Migration Guide**
  - Document backward compatibility
  - How to add namespaces to existing code
  - Performance considerations

- [ ] **Commit**: Phase 6 complete - Documentation & examples

---

### Phase 7: Performance Optimization (Week 4)

**Goal**: Ensure namespace lookups don't impact performance.

#### Tasks:

- [ ] **7.1. Level Cache**
  - Implement effective level cache
  - Cache invalidation on config change
  - Per-namespace cache entries

- [ ] **7.2. Fast Path for Disabled Logs**
  - Inline level check before building record
  - Zero allocation for filtered logs
  - Benchmark disabled log overhead

- [ ] **7.3. Namespace String Optimization**
  - Intern namespace strings
  - Avoid repeated allocations
  - Efficient string splitting for hierarchy

- [ ] **7.4. Benchmarks**
  - Add namespace benchmarks to `bench/bench_logging.ml`
  - Compare global vs scoped performance
  - Benchmark hierarchical lookup
  - Benchmark with/without caching

- [ ] **7.5. Performance Tests**
  - Test high-throughput scenarios
  - Test many namespaces (100+)
  - Test deep namespace hierarchies

- [ ] **7.6. Optimization Report**
  - Document performance characteristics
  - Publish benchmark results
  - Recommendations for users

- [ ] **Commit**: Phase 7 complete - Performance optimization

---

### Phase 8: Advanced Features (Week 4-5)

**Goal**: Advanced namespace functionality.

#### Tasks:

- [ ] **8.1. Wildcard/Pattern Matching**
  - Support `"mylib.*"` patterns
  - Regex-based namespace matching
  - Configuration: `set_level_pattern "mylib.*" Debug`

- [ ] **8.2. Namespace Filtering in Sinks**
  - Per-sink namespace filters
  - Example: JSON sink only logs "api.*"
  - Console sink excludes "verbose.component"

- [ ] **8.3. Dynamic Level Adjustment**
  - Runtime level changes
  - Configuration from environment variables
  - Configuration from config files

- [ ] **8.4. Namespace Metrics**
  - Track log counts per namespace
  - Diagnostic API: `Flo.get_namespace_stats`
  - Help identify noisy namespaces

- [ ] **8.5. Namespace Hierarchies**
  - Helper to list child namespaces
  - Namespace tree visualization
  - Debugging tools

- [ ] **8.6. Tests**
  - Test all advanced features
  - Add to `test/test_namespace_advanced.ml`

- [ ] **Commit**: Phase 8 complete - Advanced namespace features

---

### Phase 9: Integration & Testing (Week 5)

**Goal**: Ensure everything works together perfectly.

#### Tasks:

- [ ] **9.1. Full Integration Tests**
  - Multi-namespace application test
  - Library + app integration test
  - All formatters + all sinks + namespaces
  - Add to `test/test_integration_full.ml`

- [ ] **9.2. Edge Case Testing**
  - Very long namespaces
  - Special characters in namespaces
  - Namespace with spaces (should error?)
  - Unicode in namespaces

- [ ] **9.3. Concurrency Testing**
  - Multiple fibers with different namespaces
  - Namespace context isolation
  - Thread-safety of configuration

- [ ] **9.4. Backward Compatibility**
  - Ensure all existing examples still work
  - No breaking changes to existing API
  - All existing tests pass

- [ ] **9.5. Code Review**
  - Review all code for consistency
  - Check error handling
  - Verify documentation completeness

- [ ] **9.6. Performance Validation**
  - Run full benchmark suite
  - Ensure no regressions
  - Document performance impact

- [ ] **Commit**: Phase 9 complete - Integration & testing

---

### Phase 10: Polish & Release (Week 5-6)

**Goal**: Final polish and prepare for release.

#### Tasks:

- [ ] **10.1. Code Quality**
  - Run `dune build` with zero warnings
  - Format all code consistently
  - Remove any TODO comments
  - Dead code elimination

- [ ] **10.2. Documentation Review**
  - Proofread all documentation
  - Check all examples compile and run
  - Verify all links work
  - Generate odoc documentation

- [ ] **10.3. Changelog**
  - Update `CHANGELOG.md`
  - Document new namespace feature
  - List all new APIs
  - Breaking changes (if any)

- [ ] **10.4. Example Applications**
  - Polish all examples
  - Ensure examples demonstrate best practices
  - Add comments and documentation

- [ ] **10.5. Build & Package**
  - Test `opam install` process
  - Verify dune-project metadata
  - Check dependencies

- [ ] **10.6. Final Testing**
  - Run complete test suite
  - Test on fresh install
  - Test with minimal dependencies

- [ ] **10.7. Announcement**
  - Write release notes
  - Prepare examples for blog post
  - Update README with namespace feature

- [ ] **Commit**: Phase 10 complete - Polish & release preparation

---

## Master Checklist

### Core Implementation
- [ ] Phase 1: Core Namespace Infrastructure
- [ ] Phase 2: Scoped Logging API
- [ ] Phase 3: Functor-Based Loggers
- [ ] Phase 4: Formatter & Sink Integration
- [ ] Phase 5: PPX Support

### Documentation & Polish
- [ ] Phase 6: Documentation & Examples
- [ ] Phase 7: Performance Optimization
- [ ] Phase 8: Advanced Features
- [ ] Phase 9: Integration & Testing
- [ ] Phase 10: Polish & Release

---

## Success Criteria

### Functionality
- ✅ Libraries can create namespaced loggers
- ✅ Applications can configure levels per namespace
- ✅ Hierarchical namespace lookup works correctly
- ✅ All formatters display namespaces
- ✅ Backward compatible (existing code works unchanged)

### Performance
- ✅ Namespace lookup adds \u003c 1μs overhead
- ✅ Disabled logs have zero allocation
- ✅ Cache reduces repeated lookups to O(1)

### Usability
- ✅ Simple API for common cases
- ✅ Type-safe functor API for libraries
- ✅ Clear documentation with examples
- ✅ PPX support for ergonomics

### Quality
- ✅ \u003e 95% test coverage for namespace code
- ✅ All tests passing (including existing tests)
- ✅ No compiler warnings
- ✅ Comprehensive documentation

---

## Example Usage

### Library Code

```ocaml
(* mylib/database.ml *)

(* Option 1: Functor-based *)
module Log = Flo_scoped.Make(struct
  let namespace = "mylib.database"
end)

let connect ~host ~port =
  Log.info "Connecting to database";
  Log.debug_fields "Connection parameters" ~fields:[
    ("host", Value.string host);
    ("port", Value.int port);
  ];

  match establish_connection host port with
  | Ok conn ->
      Log.success "Database connection established";
      conn
  | Error err ->
      Log.error_fields "Connection failed" ~fields:[
        Flo.error_message err;
      ];
      raise (Connection_error err)

(* Option 2: Direct scoped calls *)
let query sql =
  Flo.scoped_debug "mylib.database"
    (Printf.sprintf "Executing query: %s" sql);
  execute sql
```

### Application Code

```ocaml
(* app/main.ml *)

let () =
  Eio_main.run @@ fun env ->

    (* Configure logging verbosity per namespace *)
    Flo.set_level Info;                        (* Default: Info *)
    Flo.set_level_for "mylib.database" Debug;  (* Debug for database *)
    Flo.set_level_for "mylib.cache" Warn;      (* Only warnings for cache *)
    Flo.set_level_for "app.api" Debug;         (* Debug for our API *)

    (* Use scoped logger for app code *)
    module AppLog = Flo_scoped.Make(struct
      let namespace = "app.api"
    end)

    AppLog.info "Starting application";

    (* Library logs at its configured level *)
    let db = MyLib.Database.connect ~host:"localhost" ~port:5432 in

    (* This will show DEBUG from mylib.database but only WARN from mylib.cache *)
    process_requests db
```

### Output Example

```
2024-01-15T10:30:00.123Z INFO  [app.api] Starting application
2024-01-15T10:30:00.125Z INFO  [mylib.database] Connecting to database
2024-01-15T10:30:00.126Z DEBUG [mylib.database] Connection parameters host="localhost" port=5432
2024-01-15T10:30:00.145Z SUCCESS [mylib.database] Database connection established
2024-01-15T10:30:01.234Z DEBUG [app.api] Processing request request_id="req-123"
```

---

## Notes

### Backward Compatibility

All existing Flo code continues to work without changes:
- Global functions (`Flo.info`, etc.) use root namespace `""`
- Existing logs are not affected
- Configuration is opt-in

### Namespace Conventions

Recommended naming:
- Lowercase with dots: `"mylib.component.subcomponent"`
- Library name as prefix: `"dream.router"`, `"cohttp.client"`
- Avoid special characters
- Keep reasonably short (\u003c 50 chars)

### Performance Considerations

- Namespace lookup is cached
- Hierarchical search is optimized
- Fast path for disabled logs (no record construction)
- Namespace strings are interned

### Comparison with Other Libraries

**OCaml Logs**:
- Flo: Runtime namespace strings + functor modules
- Logs: Compile-time `Logs.Src` modules only

**Python logging**:
- Flo: Similar hierarchical namespace model
- Flo: Type-safe via functors (Python is dynamic)

**Rust tracing**:
- Flo: Namespace strings (more flexible)
- Rust: Compile-time `target` (more optimized)

### Future Enhancements

Not in this plan but possible later:
- Namespace-based routing to different sinks
- Namespace ACLs (security: hide sensitive namespaces)
- Namespace-aware log aggregation
- Namespace completion in development tools
