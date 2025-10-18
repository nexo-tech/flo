(** Async sink with non-blocking writes and background processing.

    This module provides a high-performance async sink that:
    - Queues log records in a ring buffer for non-blocking writes
    - Processes records in a background fiber
    - Supports batching for efficient I/O
    - Auto-flushes at configurable intervals
    - Ensures clean shutdown with drain operation
*)

(** {1 Configuration} *)

(** Configuration for async sink. *)
type config = {
  buffer_capacity : int;
      (** Maximum number of records to queue (ring buffer size) *)
  batch_size : int;
      (** Number of records to write in each batch *)
  flush_interval : float;
      (** Auto-flush interval in seconds *)
  level : Severity.t;
      (** Minimum log level to accept *)
}

(** {1 Async Sink} *)

(** Type for async sink. *)
type t

(** Create an async sink wrapping an underlying file sink.

    The async sink spawns a background fiber that:
    1. Reads records from the ring buffer
    2. Batches them up to batch_size
    3. Writes batches to the underlying sink
    4. Auto-flushes every flush_interval seconds

    The background fiber runs until the switch is cancelled or
    drain is called to flush remaining records.

    @param sw Eio switch for fiber lifecycle
    @param env Eio environment for clock access
    @param config Async sink configuration
    @param underlying The underlying sink to write to
    @return Async sink instance
*)
val create :
  sw:Eio.Switch.t ->
  env:< clock : [> float Eio.Time.clock_ty ] Eio.Resource.t ; .. > ->
  config:config ->
  underlying:Flo_sink_file.rotating_sink ->
  t

(** Write a log record to the async sink.

    This operation is non-blocking. The record is added to the ring buffer
    and returns immediately. If the buffer is full, the record is dropped
    (this is a design choice to maintain non-blocking behavior).

    @param sink The async sink
    @param record The log record to write
*)
val write : t -> Record.t -> unit

(** Flush any pending batched records immediately.

    This signals the background fiber to flush its current batch,
    but does not wait for completion. Use drain for synchronous flushing.

    @param sink The async sink
*)
val flush : t -> unit

(** Check if sink accepts a record based on level filtering.

    @param sink The async sink
    @param record The log record
    @return true if the record should be logged
*)
val permits : t -> Record.t -> bool

(** Drain all pending records and wait for completion.

    This blocks until all queued records have been written to the
    underlying sink. Should be called before application shutdown
    to ensure no log data is lost.

    @param sink The async sink
*)
val drain : t -> unit

(** Get statistics about the async sink.

    @param sink The async sink
    @return (queued_count, total_written, total_dropped)
*)
val stats : t -> int * int64 * int64
