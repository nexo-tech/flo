(** Console sink for logging to stdout/stderr

    This module provides a sink for writing log records to the console
    (stdout or stderr) with configurable formatting and filtering.
*)

(** SINK module type *)
module type SINK = sig
  type t
  type config

  (** Create sink with configuration.

      The sink is bound to the switch lifecycle and will be automatically
      cleaned up when the switch finishes.

      @param sw Eio switch for resource management
      @param config Sink configuration
      @return New sink instance
  *)
  val create : sw:Eio.Switch.t -> config -> t

  (** Write a log record to the sink.

      @param sink The sink instance
      @param record The log record to write
  *)
  val write : t -> Record.t -> unit

  (** Flush buffered logs.

      For console sink, this is typically a no-op as writes are unbuffered.

      @param sink The sink instance
  *)
  val flush : t -> unit

  (** Check if sink accepts a record (filtering).

      Returns true if the record should be logged based on the sink's
      configuration (e.g., minimum severity level).

      @param sink The sink instance
      @param record The log record to check
      @return true if the record should be logged
  *)
  val permits : t -> Record.t -> bool
end

(** Console sink configuration *)
type config = {
  output : [ `Stderr | `Stdout ];
      (** Output stream (stderr recommended for logging) *)

  colorize : bool;
      (** Enable ANSI color codes *)

  format : [ `Pretty | `Json | `Logfmt ];
      (** Output format (Pretty is default) *)

  level : Severity.t;
      (** Minimum severity level to log *)
}

(** Console sink type *)
type t

include SINK with type t := t and type config := config

(** {1 Default Configurations} *)

(** Default configuration: stderr, colorized, pretty format, Info level *)
val default_config : config

(** Create stderr sink with pretty format and colors *)
val stderr : sw:Eio.Switch.t -> t

(** Create stdout sink with pretty format and colors *)
val stdout : sw:Eio.Switch.t -> t
