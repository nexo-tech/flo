(** File sinks with rotation and retention support.

    This module provides file-based logging sinks with support for:
    - Basic file output with buffering
    - Size-based rotation (rotate when file reaches a size limit)
    - Time-based rotation (rotate daily or at intervals)
    - Retention policies (keep last N files or files within duration)
    - Automatic directory creation
*)

(** {1 Rotation Strategies} *)

(** Rotation strategy for log files. *)
type rotation =
  | Size of int64
      (** Rotate when file reaches specified size in bytes *)
  | Daily of int * int
      (** Rotate daily at specified hour and minute (24-hour format) *)
  | Interval of float
      (** Rotate after specified interval in seconds *)

(** {1 Retention Policies} *)

(** Retention policy for old log files. *)
type retention =
  | Keep_last of int
      (** Keep only the last N rotated files *)
  | Keep_duration of float
      (** Keep files created within the last N seconds *)
  | Custom of (Eio.Fs.dir_ty Eio.Path.t list -> Eio.Fs.dir_ty Eio.Path.t list)
      (** Custom retention function that filters files to keep *)

(** {1 Basic File Sink} *)

(** Configuration for basic file sink without rotation. *)
type basic_config = {
  path : Eio.Fs.dir_ty Eio.Path.t;
      (** File path for logging *)
  format : [ `Json | `Logfmt ];
      (** Output format *)
  level : Severity.t;
      (** Minimum log level *)
  buffer_size : int;
      (** Buffer size in bytes (0 for unbuffered) *)
  create_dirs : bool;
      (** Create parent directories if they don't exist *)
}

(** Type for basic file sink. *)
type basic_sink

(** Create a basic file sink.

    @param sw Eio switch for resource management
    @param config Sink configuration
    @return File sink instance
*)
val create_basic : sw:Eio.Switch.t -> basic_config -> basic_sink

(** Write a log record to the basic file sink.

    @param sink The file sink
    @param record The log record to write
*)
val write_basic : basic_sink -> Record.t -> unit

(** Flush buffered logs to disk.

    @param sink The file sink
*)
val flush_basic : basic_sink -> unit

(** Check if sink accepts a record based on level filtering.

    @param sink The file sink
    @param record The log record
    @return true if the record should be logged
*)
val permits_basic : basic_sink -> Record.t -> bool

(** {1 Rotating File Sink} *)

(** Configuration for rotating file sink. *)
type rotating_config = {
  path : Eio.Fs.dir_ty Eio.Path.t;
      (** Base file path (will append timestamps for rotated files) *)
  format : [ `Json | `Logfmt ];
      (** Output format *)
  rotation : rotation;
      (** Rotation strategy *)
  retention : retention option;
      (** Optional retention policy *)
  level : Severity.t;
      (** Minimum log level *)
  buffer_size : int;
      (** Buffer size in bytes (0 for unbuffered) *)
  create_dirs : bool;
      (** Create parent directories if they don't exist *)
}

(** Type for rotating file sink. *)
type rotating_sink

(** Create a rotating file sink.

    The sink will automatically rotate log files according to the
    configured strategy and apply retention policies to old files.

    @param sw Eio switch for resource management
    @param env Eio environment for clock access
    @param config Sink configuration
    @return Rotating file sink instance
*)
val create_rotating :
  sw:Eio.Switch.t ->
  rotating_config ->
  rotating_sink

(** Write a log record to the rotating file sink.

    May trigger rotation if rotation criteria are met.

    @param sink The rotating file sink
    @param record The log record to write
*)
val write_rotating : rotating_sink -> Record.t -> unit

(** Flush buffered logs to disk.

    @param sink The rotating file sink
*)
val flush_rotating : rotating_sink -> unit

(** Check if sink accepts a record based on level filtering.

    @param sink The rotating file sink
    @param record The log record
    @return true if the record should be logged
*)
val permits_rotating : rotating_sink -> Record.t -> bool

(** Force rotation of the current log file.

    Useful for testing or manual rotation triggers.

    @param sink The rotating file sink
*)
val rotate : rotating_sink -> unit

(** {1 Utilities} *)

(** Get the current size of a file.

    @param fs Eio filesystem
    @param path File path
    @return File size in bytes, or 0 if file doesn't exist
*)
val file_size : Eio.Fs.dir_ty Eio.Path.t -> Eio.Fs.dir_ty Eio.Path.t -> int64

(** Generate rotated filename with timestamp.

    @param base_path Base filename
    @param timestamp Current time
    @return New filename with timestamp appended
*)
val rotated_filename : string -> Ptime.t -> string
