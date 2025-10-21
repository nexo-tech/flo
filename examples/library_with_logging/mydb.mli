(** MyDB - Example database client library with namespace-scoped logging

    This library demonstrates best practices for library logging with Flo:
    - Uses namespace "mydb" for all logs
    - Sub-components use hierarchical namespaces (mydb.cache, mydb.query, etc.)
    - Applications can configure verbosity per component
    - Provides configuration helper function

    {2 Logging Configuration}

    Configure MyDB's log verbosity in your application:
    {[
      (* Set level for entire library *)
      Flo.set_level_for "mydb" Severity.Warn;

      (* Debug specific components *)
      Flo.set_level_for "mydb.connection" Severity.Debug;
      Flo.set_level_for "mydb.query" Severity.Debug;

      (* Quiet the cache (trace/debug filtered) *)
      Flo.set_level_for "mydb.cache" Severity.Info;
    ]}

    Or use the convenience function:
    {[
      MyDB.configure_logging Severity.Info
    ]}
*)

(** Connection type *)
type connection

(** Query result *)
type result = string list

(** {1 Connection Management} *)

module Connection : sig
  (** Establish database connection

      Logs at INFO level for connection events, DEBUG for details.
      Namespace: "mydb.connection"

      @param host Database hostname
      @param port Database port
      @return Connected database handle
  *)
  val connect : host:string -> port:int -> connection

  (** Close database connection

      @param conn Connection to close
  *)
  val close : connection -> unit

  (** Check if connection is active

      @param conn Connection to check
      @return true if connected
  *)
  val is_connected : connection -> bool
end

(** {1 Query Execution} *)

module Query : sig
  (** Execute SQL query

      Logs query execution with SQL and timing info.
      Namespace: "mydb.query"

      @param conn Database connection
      @param sql SQL statement to execute
      @return Query results
      @raise Failure if not connected
  *)
  val execute : connection -> string -> result

  (** Execute query with automatic retry

      Logs each retry attempt and final outcome.
      Namespace: "mydb.query"

      @param conn Database connection
      @param sql SQL statement
      @param max_attempts Maximum retry attempts
      @return Query results
      @raise Failure if all retries exhausted
  *)
  val execute_with_retry : connection -> string -> max_attempts:int -> result
end

(** {1 Transaction Management} *)

module Transaction : sig
  (** Transaction handle *)
  type t

  (** Begin new transaction

      Namespace: "mydb.transaction"

      @param conn Database connection
      @return Transaction handle
  *)
  val begin_txn : connection -> t

  (** Commit transaction

      @param txn Transaction to commit
  *)
  val commit : t -> unit

  (** Rollback transaction

      @param txn Transaction to rollback
  *)
  val rollback : t -> unit
end

(** {1 Cache Layer} *)

module Cache : sig
  (** Cache type *)
  type t

  (** Create query cache

      Namespace: "mydb.cache"
      Logs cache operations at TRACE/DEBUG levels.

      @return New cache instance
  *)
  val create : unit -> t

  (** Get cached query result

      @param cache Cache instance
      @param key Query key
      @return Cached result if present
  *)
  val get : t -> string -> result option

  (** Cache query result

      @param cache Cache instance
      @param key Query key
      @param value Query result to cache
  *)
  val set : t -> string -> result -> unit

  (** Get cache statistics

      @param cache Cache instance
      @return Number of cached entries
  *)
  val stats : t -> int
end

(** {1 Configuration} *)

(** Configure MyDB logging level

    Sets the minimum level for all MyDB logs.
    Individual components can be configured separately using {!Flo.set_level_for}.

    @param level Minimum severity level
*)
val configure_logging : Severity.t -> unit
