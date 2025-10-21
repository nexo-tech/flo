(** Type-safe scoped loggers via functors

    This module provides functor-based scoped loggers for libraries that want
    type-safe namespace management. Each logger is bound to a specific namespace
    at compile-time or runtime.

    Example:
    {[
      (* In your library *)
      module Log = Flo_scoped.Make(struct
        let namespace = "mylib.database"
      end)

      (* Use like global Flo but automatically scoped *)
      let connect () =
        Log.info "Connecting to database";
        Log.debug_fields "Connection params" ~fields:[
          ("host", Value.string db_host);
          ("port", Value.int db_port);
        ]
    ]}
*)

(** {1 Module Types} *)

(** Signature for namespace specification.

    Used to create compile-time scoped loggers via the Make functor.
*)
module type NAMESPACE = sig
  (** The namespace for this logger (e.g., "mylib.database") *)
  val namespace : string
end

(** Signature for scoped logger.

    Provides the same API as Flo but all logs are automatically tagged
    with the logger's namespace.
*)
module type LOGGER = sig
  (** The namespace for this logger *)
  val namespace : string

  (** {1 Simple Logging API} *)

  (** Log at TRACE level *)
  val trace : ?location:Location.t -> string -> unit

  (** Log at DEBUG level *)
  val debug : ?location:Location.t -> string -> unit

  (** Log at INFO level *)
  val info : ?location:Location.t -> string -> unit

  (** Log at SUCCESS level *)
  val success : ?location:Location.t -> string -> unit

  (** Log at WARN level *)
  val warn : ?location:Location.t -> string -> unit

  (** Log at ERROR level *)
  val error : ?location:Location.t -> string -> unit

  (** Log at FATAL level *)
  val fatal : ?location:Location.t -> string -> unit

  (** {1 Printf-Style Logging} *)

  val tracef : ('a, unit, string, unit) format4 -> 'a
  val debugf : ('a, unit, string, unit) format4 -> 'a
  val infof : ('a, unit, string, unit) format4 -> 'a
  val successf : ('a, unit, string, unit) format4 -> 'a
  val warnf : ('a, unit, string, unit) format4 -> 'a
  val errorf : ('a, unit, string, unit) format4 -> 'a
  val fatalf : ('a, unit, string, unit) format4 -> 'a

  (** {1 Structured Logging} *)

  val trace_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val debug_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val info_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val success_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val warn_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val error_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  val fatal_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  (** {1 Context Propagation} *)

  (** Execute function with span context.

      Creates a span within this logger's namespace.

      @param span_name Name of the span
      @param f Function to execute
      @return Result of f
  *)
  val with_span : string -> (unit -> 'a) -> 'a

  (** Bind additional context for current fiber.

      @param fields Key-value pairs to add to context
  *)
  val bind : (string * Value.t) list -> unit

  (** {1 Configuration} *)

  (** Set minimum log level for this logger's namespace.

      @param level Minimum severity level
  *)
  val set_level : Severity.t -> unit

  (** Get configured level for this logger's namespace.

      @return Some level if explicitly configured, None otherwise
  *)
  val get_level : unit -> Severity.t option

  (** Get effective level for this logger's namespace.

      Includes hierarchy lookup.

      @return The effective level
  *)
  val get_effective_level : unit -> Severity.t
end

(** {1 Logger Creation} *)

(** Create a scoped logger with compile-time namespace.

    The namespace is fixed at compile-time, providing type safety and
    preventing accidental namespace changes.

    Example:
    {[
      module Log = Flo_scoped.Make(struct
        let namespace = "mylib.database"
      end)

      let connect () =
        Log.info "Connecting";  (* Automatically uses "mylib.database" *)
        establish_connection ()
    ]}

    The returned module implements the LOGGER signature with all logging
    functions automatically scoped to the specified namespace.

    @param N Module specifying the namespace
    @return A LOGGER module with the specified namespace
*)
module Make (_ : NAMESPACE) : LOGGER

(** Create scoped logger with runtime namespace.

    Use when the namespace is determined at runtime (e.g., from configuration).
    Returns a first-class module that can be unpacked and used.

    Example:
    {[
      let namespace = get_namespace_from_config () in
      let logger = Flo_scoped.create namespace in
      let module Log = (val logger : Flo_scoped.LOGGER) in
      Log.info "Initialized"
    ]}

    @param namespace The namespace string
    @return First-class module implementing LOGGER
*)
val create : string -> (module LOGGER)
