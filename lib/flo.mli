(** Main user-facing API for Flō logging

    This module provides a zero-configuration logging API that works immediately.
    Just import and use - no setup required.

    Example:
    {[
      Flo.info "Application started";
      Flo.successf "Processed %d items" count;
    ]}
*)

(** {1 Zero-Configuration Logging} *)

(** Pre-configured global logger - works immediately *)

(** Log at TRACE level (fine-grained debugging) *)
val trace : ?location:Location.t -> string -> unit

(** Log at DEBUG level (debug information) *)
val debug : ?location:Location.t -> string -> unit

(** Log at INFO level (informational events) *)
val info : ?location:Location.t -> string -> unit

(** Log at SUCCESS level (successful operations - celebrate when things work!) *)
val success : ?location:Location.t -> string -> unit

(** Log at WARN level (warning conditions) *)
val warn : ?location:Location.t -> string -> unit

(** Log at ERROR level (error events) *)
val error : ?location:Location.t -> string -> unit

(** Log at FATAL level (critical failures) *)
val fatal : ?location:Location.t -> string -> unit

(** {1 Printf-Style Logging} *)

(** Printf-style with format strings *)

val tracef : ('a, unit, string, unit) format4 -> 'a
val debugf : ('a, unit, string, unit) format4 -> 'a
val infof : ('a, unit, string, unit) format4 -> 'a
val successf : ('a, unit, string, unit) format4 -> 'a
val warnf : ('a, unit, string, unit) format4 -> 'a
val errorf : ('a, unit, string, unit) format4 -> 'a
val fatalf : ('a, unit, string, unit) format4 -> 'a

(** {1 Scoped Logging} *)

(** Scoped logging functions with explicit namespace.

    Libraries should use scoped logging to allow applications to configure
    log levels per component.

    Example:
    {[
      (* In your library *)
      let log_database msg = Flo.scoped_info "mylib.database" msg

      (* Application configures *)
      Flo.set_level_for "mylib.database" Debug;

      (* Log is emitted with namespace *)
      log_database "Connection established"
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
val scoped_trace_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_debug_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_info_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_success_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_warn_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_error_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val scoped_fatal_fields : string -> ?location:Location.t -> string -> fields:(string * Value.t) list -> unit

(** {1 Structured Logging} *)

(** Log message with structured fields at various severity levels.

    @param location Optional source location
    @param message The log message
    @param fields Structured key-value pairs
*)

val trace_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val debug_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val info_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val success_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val warn_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val error_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit
val fatal_fields : ?location:Location.t -> string -> fields:(string * Value.t) list -> unit

(** {1 Common Field Shortcuts} *)

(** Common field shortcuts using OpenTelemetry semantic conventions *)

(** HTTP method field (e.g., "GET", "POST") *)
val http_method : string -> string * Value.t

(** HTTP status code field (e.g., 200, 404) *)
val http_status : int -> string * Value.t

(** User ID field *)
val user_id : string -> string * Value.t

(** Duration in milliseconds *)
val duration_ms : float -> string * Value.t

(** Error type field *)
val error_type : string -> string * Value.t

(** Error message field *)
val error_message : string -> string * Value.t

(** {1 Context Propagation} *)

(** Execute function with trace ID in context.

    @param trace_id W3C Trace Context trace ID
    @param f Function to execute
    @return Result of f
*)
val with_trace_id : string -> (unit -> 'a) -> 'a

(** Execute function with span context.

    Creates a new span with the given name.

    @param span_name Name of the span
    @param f Function to execute
    @return Result of f
*)
val with_span : string -> (unit -> 'a) -> 'a

(** Execute function with user ID in context.

    @param user_id User identifier
    @param f Function to execute
    @return Result of f
*)
val with_user : string -> (unit -> 'a) -> 'a

(** Bind additional context for current fiber.

    Adds key-value pairs to the current fiber's logging context.

    @param fields Key-value pairs to add to context
*)
val bind : (string * Value.t) list -> unit

(** Get current trace ID from context.

    @return Some trace_id if in traced context, None otherwise
*)
val get_trace_id : unit -> string option

(** Get current span ID from context.

    @return Some span_id if in span context, None otherwise
*)
val get_span_id : unit -> string option

(** {2 Namespace Context} *)

(** Execute function with namespace in fiber-local context.

    All logs within the function (and child fibers) will use this namespace
    unless explicitly overridden with scoped_* functions.

    Example:
    {[
      Flo.with_namespace "mylib.handler" (fun () ->
        Flo.info "Request received";  (* Uses "mylib.handler" namespace *)
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

(** {1 Exception Handling} *)

(** Catch decorator - automatically log exceptions.

    Executes the function and catches any exception, logging it with
    the specified level. Returns Some result on success, None on exception.

    Example:
    {[
      match Flo.catch (fun () -> risky_operation ()) with
      | Some result -> process result
      | None -> handle_error ()
    ]}

    @param level Severity level for exception logging (default: Error)
    @param f Function to execute
    @return Some result if successful, None if exception caught
*)
val catch : ?level:Severity.t -> (unit -> 'a) -> 'a option

(** Log exception with stack trace.

    @param exn The exception to log
*)
val exception_ : exn -> unit

(** {1 Configuration} *)

(** Set global minimum log level.

    Records below this level will not be logged by any sink.

    @param level Minimum severity level
*)
val set_level : Severity.t -> unit

(** Get current global minimum log level.

    @return Current minimum level
*)
val get_level : unit -> Severity.t

(** {1 Namespace Configuration} *)

(** Set minimum log level for a specific namespace.

    When a log is emitted with namespace "a.b.c", the effective level
    is determined by searching in order:
    1. Exact match: "a.b.c"
    2. Parent namespaces: "a.b", then "a"
    3. Root: "" (set via set_level)

    Example:
    {[
      (* Set level for a specific library component *)
      Flo.set_level_for "mylib.database" Debug;
      Flo.set_level_for "mylib.cache" Warn;

      (* Records with namespace "mylib.database.pool" will use Debug level *)
      (* Records with namespace "mylib.cache" will use Warn level *)
    ]}

    @param namespace Dotted namespace (e.g., "mylib.database")
    @param level Minimum severity level
*)
val set_level_for : string -> Severity.t -> unit

(** Get configured level for a specific namespace.

    Returns None if no level is explicitly set for this exact namespace.
    Use {!get_effective_level} to get the level including parent lookup.

    @param namespace The namespace to query
    @return Some level if explicitly configured, None otherwise
*)
val get_level_for : string -> Severity.t option

(** Get effective level for a namespace (includes hierarchy lookup).

    This resolves the actual level after checking the namespace hierarchy.
    Searches from most specific to least specific namespace, then uses
    the root level if no match is found.

    @param namespace The namespace to query
    @return The effective level (never None)
*)
val get_effective_level : string -> Severity.t

(** Clear level for a namespace.

    After clearing, the namespace will use parent or root level.

    @param namespace The namespace to clear
*)
val clear_level_for : string -> unit

(** List all configured namespace levels.

    Returns all explicitly configured namespaces and their levels.
    Does not include the root level or inherited levels.

    @return List of (namespace, level) pairs
*)
val get_all_levels : unit -> (string * Severity.t) list

(** {1 Module Re-exports} *)

(** Re-export modules for convenience *)

module Severity = Severity
module Location = Location
module Value = Value
module Trace_context = Trace_context
module Record = Record
module Flo_core = Flo_core
module Flo_context = Flo_context
module Flo_namespace = Flo_namespace
module Flo_format_pretty = Flo_format_pretty
module Flo_format_json = Flo_format_json
module Flo_format_logfmt = Flo_format_logfmt
module Flo_sink_console = Flo_sink_console
