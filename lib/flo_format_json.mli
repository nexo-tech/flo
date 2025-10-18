(** JSON formatter for structured log output

    This module provides a JSON formatter that outputs log records
    in a structured JSON format suitable for log aggregation systems.
*)

(** Formatter module type *)
module type FORMATTER = sig
  (** Format log record to JSON string.

      Produces a single-line JSON object with all record fields.

      @param record The log record to format
      @return JSON string (single line)
  *)
  val format : Record.t -> string

  (** Parse JSON string back to record.

      @param s The JSON string to parse
      @return Ok record if valid JSON, Error message otherwise
  *)
  val parse : string -> (Record.t, string) result
end

(** Default JSON formatter. *)
include FORMATTER

(** {1 JSON Format Specification} *)

(**
   Output format (single-line JSON):
   {[
     {
       "timestamp": "2024-01-15T10:30:45.123Z",
       "severity": "info",
       "severity_number": 9,
       "message": "Log message",
       "attributes": { "key": "value", ... },
       "location": { "file": "app.ml", "line": 42, ... },
       "span_context": { "trace_id": "...", "span_id": "...", ... },
       "event_name": "user.login",
       "body": { ... }
     }
   ]}

   Fields:
   - timestamp: ISO 8601 timestamp (RFC3339)
   - severity: Severity level as lowercase string
   - severity_number: OpenTelemetry severity number
   - message: Log message string
   - attributes: Object with key-value pairs (optional if empty)
   - location: Object with file, line, column, etc. (optional)
   - span_context: Object with trace_id, span_id, etc. (optional)
   - event_name: Event identifier (optional)
   - body: Structured log body (optional)
*)
