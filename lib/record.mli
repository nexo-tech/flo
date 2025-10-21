(** OpenTelemetry-compliant log record

    This module defines the log record type following the OpenTelemetry
    Logs Data Model specification.

    See: https://opentelemetry.io/docs/specs/otel/logs/data-model/
*)

(** Log record type.

    A log record represents a single log event with metadata following
    the OpenTelemetry Logs Data Model.
*)
type t = {
  timestamp : Ptime.t;
      (** Time when the event occurred (event time) *)

  observed_timestamp : Ptime.t option;
      (** Time when the event was observed by the logging system.
          If None, defaults to timestamp. *)

  severity : Severity.t;
      (** Severity level of the log event *)

  message : string;
      (** Human-readable log message *)

  location : Location.t option;
      (** Source code location where the log was created *)

  span_context : Trace_context.span_context option;
      (** W3C Trace Context for distributed tracing *)

  attributes : (string * Value.t) list;
      (** Structured key-value attributes (metadata) *)

  body : Value.t option;
      (** Structured body for complex log data *)

  event_name : string option;
      (** Name of the event (e.g., "user.login", "order.created") *)

  namespace : string option;
      (** Namespace for hierarchical log filtering (e.g., "mylib.database").
          If None, uses the root namespace. *)
}

(** {1 Construction} *)

(** Create a log record with required fields.

    Optional fields are set to None or empty.
    Uses current time for timestamp.

    @param severity The log severity level
    @param message The log message
    @return A new log record
*)
val make : severity:Severity.t -> message:string -> t

(** Create a log record with a specific timestamp.

    @param timestamp Event time
    @param severity The log severity level
    @param message The log message
    @return A new log record
*)
val make_with_timestamp :
  timestamp:Ptime.t ->
  severity:Severity.t ->
  message:string ->
  t

(** {1 Builder Pattern Helpers} *)

(** Add location information to a record.

    @param location Source location
    @param record The log record
    @return Updated record
*)
val with_location : Location.t -> t -> t

(** Add span context for distributed tracing.

    @param span_context W3C Trace Context
    @param record The log record
    @return Updated record
*)
val with_span_context : Trace_context.span_context -> t -> t

(** Add or append attributes to a record.

    @param attributes Key-value pairs to add
    @param record The log record
    @return Updated record with merged attributes
*)
val with_attributes : (string * Value.t) list -> t -> t

(** Set the structured body.

    @param body Structured log body
    @param record The log record
    @return Updated record
*)
val with_body : Value.t -> t -> t

(** Set the event name.

    @param event_name Event name (e.g., "user.login")
    @param record The log record
    @return Updated record
*)
val with_event_name : string -> t -> t

(** Set the observed timestamp.

    @param observed_timestamp Time when event was observed
    @param record The log record
    @return Updated record
*)
val with_observed_timestamp : Ptime.t -> t -> t

(** Add namespace to a record.

    @param namespace The namespace (e.g., "mylib.database")
    @param record The log record
    @return Updated record
*)
val with_namespace : string -> t -> t

(** Get namespace from a record.

    @param record The log record
    @return Some namespace if set, None for root namespace
*)
val namespace : t -> string option

(** {1 Utilities} *)

(** Get the effective timestamp.

    Returns observed_timestamp if set, otherwise timestamp.

    @param record The log record
    @return The effective timestamp
*)
val get_timestamp : t -> Ptime.t

(** Convert record to a human-readable string for debugging.

    Not suitable for production logging - use formatters for that.

    @param record The log record
    @return Debug string representation
*)
val to_string : t -> string
