(** W3C Trace Context implementation

    This module implements the W3C Trace Context standard for distributed tracing.
    See: https://www.w3.org/TR/trace-context/
*)

(** Span context following W3C Trace Context standard.

    Contains trace identification and propagation information for distributed tracing.
*)
type span_context = {
  trace_id : string;           (** 32 hex characters (16 bytes), globally unique *)
  span_id : string;            (** 16 hex characters (8 bytes), current span *)
  parent_span_id : string option;  (** Parent span ID for linking *)
  trace_flags : int;           (** 8-bit flags, bit 0 = sampled *)
}

(** Generate a cryptographically random trace ID.

    Returns a 32-character lowercase hexadecimal string (16 bytes).
    Guaranteed to not be all-zeros as per W3C spec.

    Example: "0af7651916cd43dd8448eb211c80319c"
*)
val generate_trace_id : unit -> string

(** Generate a cryptographically random span ID.

    Returns a 16-character lowercase hexadecimal string (8 bytes).
    Guaranteed to not be all-zeros as per W3C spec.

    Example: "b7ad6b7169203331"
*)
val generate_span_id : unit -> string

(** Create a child span context.

    - Preserves trace_id from parent
    - Generates new span_id for the child
    - Sets parent_span_id to parent's span_id
    - Preserves trace_flags from parent

    @param parent The parent span context
    @return New child span context
*)
val create_child : span_context -> span_context

(** Parse W3C traceparent header value.

    Format: "00-{trace_id}-{span_id}-{flags}"
    - Version must be "00"
    - trace_id: 32 hex characters
    - span_id: 16 hex characters
    - flags: 2 hex characters

    Example: "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

    @param header The traceparent header value
    @return Ok span_context if valid, Error message if invalid
*)
val parse_traceparent : string -> (span_context, string) result

(** Format span context as W3C traceparent header value.

    Produces format: "00-{trace_id}-{span_id}-{flags}"

    Example: "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

    @param ctx The span context to format
    @return Formatted traceparent string
*)
val format_traceparent : span_context -> string

(** {1 Trace Flags} *)

(** Check if the sampled flag is set.

    @param flags The trace_flags value
    @return true if bit 0 (sampled) is set
*)
val is_sampled : int -> bool

(** Set the sampled flag.

    @param flags The current trace_flags value
    @return New flags with sampled bit set
*)
val set_sampled : int -> int

(** Clear the sampled flag.

    @param flags The current trace_flags value
    @return New flags with sampled bit cleared
*)
val clear_sampled : int -> int

(** {1 Validation} *)

(** Validate trace ID format.

    - Must be exactly 32 hex characters
    - Must not be all zeros

    @param trace_id The trace ID to validate
    @return true if valid
*)
val is_valid_trace_id : string -> bool

(** Validate span ID format.

    - Must be exactly 16 hex characters
    - Must not be all zeros

    @param span_id The span ID to validate
    @return true if valid
*)
val is_valid_span_id : string -> bool
