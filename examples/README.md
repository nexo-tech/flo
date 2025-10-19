# Flō Examples

Comprehensive examples demonstrating all features of the Flō logging library.

## Quick Start

**New to Flō?** Start here:
1. [`simple_app.ml`](#simple_appml) - Zero-configuration logging basics
2. [`ppx_usage.ml`](#ppx_usageml) - PPX extensions for ergonomic logging
3. [`structured_events.ml`](#structured_eventsml) - Type-safe structured logging

## Example Index

### Core API & Basics

#### [`simple_app.ml`](simple_app.ml)
**Zero-configuration logging demonstration**
- All 7 severity levels (trace, debug, info, success, warn, error, fatal)
- Printf-style logging (debugf, successf, etc.)
- Structured logging with semantic conventions
- Context propagation (with_trace_id, with_span, with_user)
- Exception handling (catch decorator, exception_)
- Level filtering (get_level, set_level)

**See also:** DESIGN.md Pattern 1

#### [`core_composition.ml`](core_composition.ml)
**Contravariant functor and monoid composition**
- Flo_core.make, noop, contramap, combine
- Operators: (>$<), (<>), (<&)
- Filtering pipelines (filter, level_filter)
- Multi-destination logging
- Type transformations

**See also:** DESIGN.md Section 4

### Structured Logging

#### [`structured_events.ml`](structured_events.ml)
**Type-safe structured logging with GADT context**
- STRUCTURED module pattern
- Type-safe context keys (user_id_key, request_id_key)
- Span management (start_span, end_span, in_span)
- First-class modules with log_event
- Domain events (User_Registered, Payment_Failed, Order_Created)

**See also:** DESIGN.md Pattern 4

### PPX Extensions

#### [`ppx_usage.ml`](ppx_usage.ml)
**Comprehensive PPX extension demonstrations**
- Automatic location capture: `[%log.info "msg"]`
- Structured logging with type inference: `[%log.info "msg" ~field:value]`
- Span annotations: `[%span expr]`
- Variable support with runtime auto-conversion
- Nested spans and exception handling

**See also:** PPX_GUIDE.md

### Formatters

#### [`custom_formatter.ml`](custom_formatter.ml)
**Custom formatter implementations**
- Custom color schemes (Solarized)
- Field filtering (security: remove password/api_key)
- Key transformations (camelCase → snake_case)
- Colored vs non-colored output
- Compact and detailed formatters

**See also:** DESIGN.md Section 6

#### [`json_logging.ml`](json_logging.ml)
**JSON format for log aggregators**
- JSON to stdout for ELK/Splunk/Datadog
- OpenTelemetry-compliant structure
- Parsing and querying
- Nested structures
- Cloud logging patterns (GCP, AWS)

**See also:** DESIGN.md Pattern 2

#### [`logfmt_output.ml`](logfmt_output.ml)
**Logfmt format for human readability**
- key=value pair format
- Structured fields with proper quoting
- Nested attribute flattening
- Special character handling
- Round-trip parsing
- Production log patterns

**See also:** DESIGN.md Section 6

#### [`pretty_console.ml`](pretty_console.ml)
**Beautiful terminal output**
- Colored output (7 severity colors)
- No-color mode (CI/CD)
- Custom color schemes
- Compact vs verbose formats
- Icons and emojis

### Sinks & Output

#### [`file_logging.ml`](file_logging.ml)
**File-based logging with rotation**
- Basic file logging
- Size-based rotation
- Time-based rotation (Daily, Interval)
- Retention policies (Keep_last, Keep_duration)
- Production logging patterns

**See also:** DESIGN.md Pattern 3

#### [`multi_sink.ml`](multi_sink.ml)
**Multiple destination logging**
- Console (Pretty) + File (JSON) simultaneously
- Different log levels per sink
- Filtered sinks (errors-only)
- Development vs production configs
- Performance comparison

**See also:** DESIGN.md Section 5

#### [`custom_sink.ml`](custom_sink.ml)
**Custom sink implementations**
- In-memory sink (testing)
- Webhook sink (HTTP POST for Slack/PagerDuty)
- Database sink (batched SQL inserts)
- Filtered sink (predicate-based)
- Rate-limited sink (prevent flooding)
- Multi-format sink (auto-select by severity)

### Performance

#### [`perf_app.ml`](perf_app.ml)
**High-performance async logging**
- Async sink with batching
- Non-blocking writes
- Background processing
- Benchmarking (1000+ logs)
- Production tuning

**See also:** DESIGN.md Pattern 3

### Context & Tracing

#### [`context_propagation.ml`](context_propagation.ml)
**Fiber-local context patterns**
- Multi-fiber context isolation
- Parent-child context inheritance
- Context merging strategies
- Type-safe GADT keys
- HTTP header extraction/injection
- Distributed traces across services

**See also:** DESIGN.md Pattern 2

#### [`distributed_tracing.ml`](distributed_tracing.ml)
**W3C Trace Context & OpenTelemetry**
- traceparent parsing/formatting
- Span relationships (parent/child)
- End-to-end traces across 3 services
- Trace sampling strategies
- Visualization structure
- OpenTelemetry integration

**See also:** DESIGN.md Section 3

#### [`semantic_conventions.ml`](semantic_conventions.ml)
**OpenTelemetry semantic conventions**
- HTTP server instrumentation
- Database operation logging
- RPC call instrumentation (gRPC)
- Cloud provider attributes (GCP, AWS)
- User and session tracking
- Custom semantic conventions

**See also:** DESIGN.md Section 3

### Testing & Error Handling

#### [`testing_with_flo.ml`](testing_with_flo.ml)
**Testing patterns with Flo**
- In-memory test sink
- Asserting log messages
- Checking structured field values
- Testing span relationships
- Mock sinks for library testing
- Integration testing workflows

#### [`error_handling.ml`](error_handling.ml)
**Exception and error patterns**
- Exception decorator (catch)
- Backtraces and stack traces
- Error context propagation
- Structured error events (Payment_Failed module)
- Error rate monitoring
- Panic vs recoverable errors

### Eio Integration

#### [`eio_integration.ml`](eio_integration.ml)
**Eio-specific features**
- Fiber-local context isolation
- Structured concurrency with switch
- HTTP context extraction
- Multi-domain logging
- Context propagation across fibers
- Switch-bound resource management

**See also:** DESIGN.md Section 7

#### [`web_service.ml`](web_service.ml)
**HTTP web service with distributed tracing**
- HTTP request handling with spans
- Trace context extraction from headers
- Request/response logging
- Concurrent request processing

## Example Categories

### By Difficulty

**Beginner:**
- simple_app.ml
- pretty_console.ml
- json_logging.ml

**Intermediate:**
- ppx_usage.ml
- structured_events.ml
- file_logging.ml
- multi_sink.ml

**Advanced:**
- context_propagation.ml
- distributed_tracing.ml
- perf_app.ml
- core_composition.ml

### By Feature

**Formatting:**
- custom_formatter.ml
- json_logging.ml
- logfmt_output.ml
- pretty_console.ml

**Context & Tracing:**
- context_propagation.ml
- distributed_tracing.ml
- semantic_conventions.ml

**Testing:**
- testing_with_flo.ml
- error_handling.ml

**Performance:**
- perf_app.ml
- multi_sink.ml

**PPX:**
- ppx_usage.ml

## Running Examples

Build all examples:
```bash
dune build
```

Run a specific example:
```bash
dune exec examples/simple_app.exe
dune exec examples/ppx_usage.exe
dune exec examples/distributed_tracing.exe
```

Test all examples (automated):
```bash
./test_examples.sh
```

## Cross-References

### DESIGN.md Patterns

- Pattern 1 (Simple Application) → `simple_app.ml`
- Pattern 2 (Web Service) → `web_service.ml`, `context_propagation.ml`
- Pattern 3 (High-Performance) → `perf_app.ml`, `file_logging.ml`
- Pattern 4 (Type-Safe Events) → `structured_events.ml`
- Pattern 5 (Testing) → `testing_with_flo.ml`

### Feature Coverage

| Feature | Examples |
|---------|----------|
| All severity levels | simple_app.ml, pretty_console.ml |
| Printf-style | simple_app.ml |
| Structured logging | structured_events.ml, ppx_usage.ml |
| PPX extensions | ppx_usage.ml |
| Context propagation | context_propagation.ml, eio_integration.ml |
| Distributed tracing | distributed_tracing.ml, context_propagation.ml |
| W3C Trace Context | distributed_tracing.ml, web_service.ml |
| Semantic conventions | semantic_conventions.ml |
| Custom formatters | custom_formatter.ml |
| JSON output | json_logging.ml |
| Logfmt output | logfmt_output.ml |
| Pretty console | pretty_console.ml |
| File logging | file_logging.ml |
| Rotating files | file_logging.ml |
| Async sinks | perf_app.ml |
| Multi-sink | multi_sink.ml |
| Custom sinks | custom_sink.ml |
| Error handling | error_handling.ml |
| Testing | testing_with_flo.ml |
| Eio integration | eio_integration.ml |
| Composition | core_composition.ml |

## Total Examples

- **19 example files**
- **3500+ lines** of working code
- **100+ individual examples** across all files
- **All examples verified working** ✓

## Need Help?

- **Getting started?** → simple_app.ml
- **Using PPX?** → ppx_usage.ml + PPX_GUIDE.md
- **Production deployment?** → perf_app.ml, file_logging.ml, multi_sink.ml
- **Testing?** → testing_with_flo.ml
- **Distributed systems?** → distributed_tracing.ml, context_propagation.ml
- **Custom integration?** → custom_sink.ml, custom_formatter.ml

See also: DESIGN.md, TUTORIAL.md, PPX_GUIDE.md
