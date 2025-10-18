(** Pretty formatter for human-readable console output

    This module provides a pretty formatter with ANSI color support for
    console logging. Inspired by Loguru's beautiful output.
*)

(** Formatter module type *)
module type FORMATTER = sig
  (** Format log record to string.

      @param record The log record to format
      @return Formatted string representation
  *)
  val format : Record.t -> string

  (** Parse string back to record.

      Note: Parsing is not implemented for pretty format as it's lossy.

      @param s The string to parse
      @return Error indicating parsing is not supported
  *)
  val parse : string -> (Record.t, string) result
end

(** Default pretty formatter with colors enabled. *)
include FORMATTER

(** Create a formatter with configurable color support.

    @param colorize Whether to include ANSI color codes
    @return A formatter module
*)
val with_colors : bool -> (module FORMATTER)

(** {1 ANSI Color Codes} *)

(** ANSI color codes for terminal output.

    These can be used to manually construct colored strings.
*)

(** Reset all attributes *)
val reset : string

(** Bold text *)
val bold : string

(** Dim/faint text *)
val dim : string

val black : string
val red : string
val green : string
val yellow : string
val blue : string
val magenta : string
val cyan : string
val white : string

(** Dim white *)
val gray : string

val bright_red : string
val bright_green : string
val bright_yellow : string
val bright_blue : string
val bright_magenta : string
val bright_cyan : string
val bright_white : string

(** Get color for severity level.

    @param severity The severity level
    @return ANSI color code
*)
val color_for_severity : Severity.t -> string
