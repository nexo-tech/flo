(** Log severity levels following OpenTelemetry conventions *)

(** Severity level type.

    Levels are ordered from least to most severe:
    Trace < Debug < Info < Success < Warn < Error < Fatal

    OpenTelemetry severity numbers:
    - Trace: 1 (fine-grained debugging)
    - Debug: 5 (debug information)
    - Info: 9 (informational events)
    - Success: 10 (successful operations - Loguru-inspired)
    - Warn: 13 (warning conditions)
    - Error: 17 (error events)
    - Fatal: 21 (critical failures)
*)
type t =
  | Trace    (** Fine-grained debugging *)
  | Debug    (** Debug information *)
  | Info     (** Informational events *)
  | Success  (** Successful operations (Loguru-inspired) *)
  | Warn     (** Warning conditions *)
  | Error    (** Error events *)
  | Fatal    (** Critical failures *)

(** Convert severity to string representation.

    Returns lowercase name: "trace", "debug", "info", "success", "warn", "error", "fatal"
*)
val to_string : t -> string

(** Convert severity to OpenTelemetry severity number.

    Numbers follow OpenTelemetry Logs Data Model specification.
*)
val to_number : t -> int

(** Parse severity from string.

    Case-insensitive. Accepts: "trace", "debug", "info", "success", "warn", "error", "fatal"

    Returns Error if string is not a valid severity level.
*)
val of_string : string -> (t, string) result

(** Compare two severity levels. Useful for filtering.

    Example: [compare Debug Info] returns a negative value
*)
val compare : t -> t -> int
