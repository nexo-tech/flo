# Flō API Reference

Quick reference for all public APIs in the Flō logging library.

## Core API (Flo module)

### Zero-Configuration Logging

```ocaml
val trace : ?location:Location.t -> string -> unit
val debug : ?location:Location.t -> string -> unit
val info : ?location:Location.t -> string -> unit
val success : ?location:Location.t -> string -> unit
val warn : ?location:Location.t -> string -> unit
val error : ?location:Location.t -> string -> unit
val fatal : ?location:Location.t -> string -> unit
```

### Printf-Style Logging

```ocaml
val tracef : ('a, unit, string, unit) format4 -> 'a
val debugf : ('a, unit, string, unit) format4 -> 'a
val infof : ('a, unit, string, unit) format4 -> 'a
val successf : ('a, unit, string, unit) format4 -> 'a
val warnf : ('a, unit, string, unit) format4 -> 'a
val errorf : ('a, unit, string, unit) format4 -> 'a
val fatalf : ('a, unit, string, unit) format4 -> 'a
```

### Structured Logging

```ocaml
val trace_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val debug_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val info_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val success_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val warn_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val error_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val fatal_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
```

### Semantic Convention Shortcuts

```ocaml
val http_method : string -> string * Value.t
val http_status : int -> string * Value.t
val user_id : string -> string * Value.t
val duration_ms : float -> string * Value.t
val error_type : string -> string * Value.t
val error_message : string -> string * Value.t
```

### Context Propagation

```ocaml
val with_trace_id : string -> (unit -> 'a) -> 'a
val with_span : string -> (unit -> 'a) -> 'a
val with_user : string -> (unit -> 'a) -> 'a
val bind : (string * Value.t) list -> unit
val get_trace_id : unit -> string option
val get_span_id : unit -> string option
```

### Exception Handling

```ocaml
val catch : ?level:Severity.t -> (unit -> 'a) -> 'a option
val exception_ : exn -> unit
```

### Level Management

```ocaml
val set_level : Severity.t -> unit
val get_level : unit -> Severity.t
val enable : string -> unit
val disable : string -> unit
```

## Structured API (Flo_structured module)

### Type-Safe Context Keys

```ocaml
type 'a key

val user_id_key : string key
val request_id_key : string key
val trace_id_key : string key
val session_id_key : string key

val add : 'a key -> 'a -> unit
val get : 'a key -> 'a option
val with_binding : 'a key -> 'a -> (unit -> 'b) -> 'b
```

### Span Management

```ocaml
type span

val start_span : string -> ?attributes:(string * Value.t) list -> ?parent:span option -> unit -> span
val end_span : span -> unit
val in_span : string -> (span -> 'a) -> 'a

val span_trace_id : span -> string
val span_id : span -> string
val span_name : span -> string
```

### Structured Events

```ocaml
module type STRUCTURED = sig
  type t
  val to_value : t -> Value.t
  val event_name : string
  val severity : Severity.t
end

val log_event : (module STRUCTURED with type t = 'a) -> 'a -> unit
```

## Compositional API (Flo_core module)

### Logger Type

```ocaml
type ('m, 'msg) t = 'msg -> 'm
```

### Construction

```ocaml
val make : ('msg -> 'm) -> ('m, 'msg) t
val noop : ('m, 'msg) t
```

### Contravariant Operations

```ocaml
val contramap : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t
val (>$<) : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t
```

### Composition (Monoid)

```ocaml
val combine : ('m, 'msg) t -> ('m, 'msg) t -> ('m, 'msg) t
val (<>) : ('m, 'msg) t -> ('m, 'msg) t -> ('m, 'msg) t
val combine_all : ('m, 'msg) t list -> ('m, 'msg) t
```

### Filtering

```ocaml
val filter : ('msg -> bool) -> ('m, 'msg) t -> ('m, 'msg) t
val level_filter : Severity.t -> ('m, Record.t) t -> ('m, Record.t) t
```

### Application

```ocaml
val log : ('m, 'msg) t -> 'msg -> 'm
val (<&) : ('m, 'msg) t -> 'msg -> 'm
```

## Semantic Conventions (Flo_semconv module)

### Service Attributes

```ocaml
val service_name : string -> string * Value.t
val service_version : string -> string * Value.t
val deployment_environment : string -> string * Value.t
```

### HTTP Attributes

```ocaml
val http_method : string -> string * Value.t
val http_status_code : int -> string * Value.t
val http_url : string -> string * Value.t
val http_target : string -> string * Value.t
val http_host : string -> string * Value.t
val http_scheme : string -> string * Value.t
val http_user_agent : string -> string * Value.t
```

### Database Attributes

```ocaml
val db_system : string -> string * Value.t
val db_name : string -> string * Value.t
val db_operation : string -> string * Value.t
val db_statement : string -> string * Value.t
val db_sql_table : string -> string * Value.t
```

### RPC Attributes

```ocaml
val rpc_system : string -> string * Value.t
val rpc_service : string -> string * Value.t
val rpc_method : string -> string * Value.t
```

### Cloud Attributes

```ocaml
val cloud_provider : string -> string * Value.t
val cloud_region : string -> string * Value.t
val cloud_availability_zone : string -> string * Value.t
val host_name : string -> string * Value.t
```

### User Attributes

```ocaml
val user_id : string -> string * Value.t
val user_email : string -> string * Value.t
val user_name : string -> string * Value.t
```

## Eio Integration (Flo_eio module)

### Context Management

```ocaml
val with_context :
  ?trace_id:string ->
  ?span_id:string ->
  ?attributes:(string * Value.t) list ->
  (unit -> 'a) -> 'a

val get_context : unit -> Flo_structured.context option
```

### HTTP Context Propagation

```ocaml
val extract_trace_context : (string * string) list -> Trace_context.span_context option
val inject_trace_context : Trace_context.span_context -> (string * string) list
val with_http_context : headers:(string * string) list -> (unit -> 'a) -> 'a
```

## Trace Context (Trace_context module)

### Types

```ocaml
type span_context = {
  trace_id : string;        (* 32 hex characters *)
  span_id : string;         (* 16 hex characters *)
  parent_span_id : string option;
  trace_flags : int;        (* Bit 0: sampled *)
}
```

### ID Generation

```ocaml
val generate_trace_id : unit -> string
val generate_span_id : unit -> string
```

### W3C Trace Context

```ocaml
val parse_traceparent : string -> (span_context, string) result
val format_traceparent : span_context -> string
val create_child : span_context -> span_context
```

## PPX Extensions (ppx_flo)

### Extension Points

```ocaml
[%log.info "message"]              (* Automatic location capture *)
[%log.info "msg" ~field:value]     (* Structured logging *)
[%span expr]                       (* Span annotation *)
```

### Supported in PPX

- All 7 severity levels: trace, debug, info, success, warn, error, fatal
- Literal values: strings, ints, floats, bools
- Variables: automatic type conversion
- Lists and nested structures

**See [PPX_GUIDE.md](PPX_GUIDE.md) for details.**

## Formatters

### Built-in Formatters

```ocaml
module Flo_format_json : FORMATTER
module Flo_format_logfmt : FORMATTER
module Flo_format_pretty : FORMATTER
```

### FORMATTER Interface

```ocaml
module type FORMATTER = sig
  val format : Record.t -> string
  val parse : string -> (Record.t, string) result
end
```

## Sinks

### Console Sink

```ocaml
type config = {
  output : [ `Stderr | `Stdout ];
  colorize : bool;
  format : [ `Pretty | `Json | `Logfmt ];
  level : Severity.t;
}

val create : sw:Eio.Switch.t -> config -> t
val write : t -> Record.t -> unit
val flush : t -> unit
```

### File Sink

```ocaml
type config = {
  path : Eio.Fs.dir_ty Eio.Path.t;
  format : [ `Json | `Logfmt ];
  level : Severity.t;
  buffer_size : int;
  create_dirs : bool;
}

val create_basic : sw:Eio.Switch.t -> config -> t
val write_basic : t -> Record.t -> unit
val flush_basic : t -> unit
```

### Rotating File Sink

```ocaml
type rotation =
  | Size of int64
  | Daily of int * int
  | Interval of float

type retention =
  | Keep_last of int
  | Keep_duration of float

val create_rotating : sw:Eio.Switch.t -> config -> t
val write_rotating : t -> Record.t -> unit
val flush_rotating : t -> unit
```

### Async Sink

```ocaml
type config = {
  buffer_capacity : int;
  batch_size : int;
  flush_interval : float;
  level : Severity.t;
}

val create : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> config -> underlying:t -> t
val write : t -> Record.t -> unit
val drain : t -> unit
```

## Value Types

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

val string : string -> t
val int : int -> t
val float : float -> t
val bool : bool -> t
val to_string : t -> string
```

## See Also

- **[DESIGN.md](DESIGN.md)** - Architecture and design philosophy
- **[TUTORIAL.md](TUTORIAL.md)** - Patterns and best practices
- **[PPX_GUIDE.md](PPX_GUIDE.md)** - PPX extension guide
- **[examples/](examples/)** - 19 working examples
- **[examples/README.md](examples/README.md)** - Example index
