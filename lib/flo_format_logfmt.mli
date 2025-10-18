(** Logfmt formatter for flat key-value log output

    This module provides a logfmt formatter that outputs log records
    in the logfmt format - a simple key=value format popular in cloud
    environments and monitoring systems.

    See: https://brandur.org/logfmt
*)

(** Formatter module type *)
module type FORMATTER = sig
  (** Format log record to logfmt string.

      Produces a single-line logfmt output with space-separated key=value pairs.

      @param record The log record to format
      @return Logfmt string (single line)
  *)
  val format : Record.t -> string

  (** Parse logfmt string back to record.

      Note: Parsing is partially implemented. Some information may be lost
      as logfmt is a flat format.

      @param s The logfmt string to parse
      @return Ok record if valid logfmt, Error message otherwise
  *)
  val parse : string -> (Record.t, string) result
end

(** Default logfmt formatter. *)
include FORMATTER

(** {1 Logfmt Format Specification} *)

(**
   Output format (single-line key=value pairs):
   {[
     timestamp="2024-01-15T10:30:45.123Z" severity=info severity_number=9 message="Log message" key1=value1 key2="value with spaces"
   ]}

   Rules:
   - Keys: alphanumeric and underscore, no spaces
   - Values: unquoted if simple, quoted if contains spaces or special chars
   - Quoted values: double quotes with backslash escaping
   - Separator: single space between pairs
   - Format: key=value (no space around =)
   - Single line per log entry

   Quoting:
   - Simple values (alphanumeric): key=value
   - Values with spaces: key="value with spaces"
   - Values with quotes: key="escaped \"quotes\""
   - Values with backslash: key="escaped \\backslash"
   - Empty values: key=""

   Fields:
   - timestamp: ISO 8601 timestamp (always quoted)
   - severity: Severity level as lowercase string
   - severity_number: OpenTelemetry severity number
   - message: Log message (quoted if contains spaces)
   - Flattened attributes: attr_key=attr_value
   - location_file, location_line, location_column (if present)
   - trace_id, span_id, trace_flags (if span_context present)
   - event_name (if present)
   - Note: body is flattened as body_* fields if it's an Object
*)
