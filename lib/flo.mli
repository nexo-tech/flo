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

(** {1 Module Re-exports} *)

(** Re-export modules for convenience *)

module Severity = Severity
module Location = Location
module Value = Value
module Trace_context = Trace_context
module Record = Record
module Flo_core = Flo_core
module Flo_context = Flo_context
module Flo_format_pretty = Flo_format_pretty
module Flo_format_json = Flo_format_json
module Flo_format_logfmt = Flo_format_logfmt
module Flo_sink_console = Flo_sink_console
