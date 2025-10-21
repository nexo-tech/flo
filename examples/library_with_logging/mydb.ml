(** MyDB - Example database client library with Flo logging

    This demonstrates how a library should integrate Flo logging with namespaces
    to allow applications fine-grained control over log verbosity.
*)

[@@@flo.namespace "mydb"]

open Flo

(** Connection type *)
type connection = {
  host : string;
  port : int;
  mutable connected : bool;
}

(** Query result *)
type result = string list

(** Create a scoped logger for the library *)
module Log = Flo_scoped.Make(struct
  let namespace = "mydb"
end)

(** {1 Connection Management} *)

module Connection = struct
  (** Establish database connection

      This function logs connection attempts and results.
      Configure verbosity: [Flo.set_level_for "mydb.connection" Severity.Debug]
  *)
  let connect ~host ~port =
    Log.with_span "connect" (fun () ->
      Log.info_fields "Attempting database connection" ~fields:[
        ("host", Value.string host);
        ("port", Value.int port);
      ];

      (* Simulate connection *)
      Unix.sleepf 0.1;

      let conn = { host; port; connected = true } in

      Log.success_fields "Database connected" ~fields:[
        ("host", Value.string host);
        ("connection_time_ms", Value.float 100.0);
      ];

      conn
    )

  (** Close connection *)
  let close conn =
    Log.infof "Closing connection to %s:%d" conn.host conn.port;
    conn.connected <- false;
    Log.debug "Connection closed"

  (** Check if connected *)
  let is_connected conn =
    Log.tracef "Connection check: %b" conn.connected;
    conn.connected
end

(** {1 Query Execution} *)

module Query = struct
  (** Execute a SQL query

      Logs query execution with timing information.
      Configure verbosity: [Flo.set_level_for "mydb.query" Severity.Debug]
  *)
  let execute conn sql =
    if not conn.connected then begin
      Log.error "Cannot execute query: not connected";
      failwith "Not connected"
    end;

    Log.with_span "query_execute" (fun () ->
      Log.debug_fields "Executing query" ~fields:[
        ("sql", Value.string sql);
        ("host", Value.string conn.host);
      ];

      (* Simulate query execution *)
      Unix.sleepf 0.05;

      let row_count = 5 in
      let results = List.init row_count (fun i ->
        Printf.sprintf "row_%d" i
      ) in

      Log.debug_fields "Query completed" ~fields:[
        ("row_count", Value.int row_count);
        ("execution_time_ms", Value.float 50.0);
      ];

      results
    )

  (** Execute query with retry logic *)
  let execute_with_retry conn sql ~max_attempts =
    let rec attempt n =
      Log.debugf "Query attempt %d/%d" n max_attempts;

      match Flo.catch ~level:Severity.Warn (fun () ->
        execute conn sql
      ) with
      | Some result ->
          Log.successf "Query succeeded on attempt %d" n;
          result
      | None ->
          if n >= max_attempts then begin
            Log.error_fields "Query failed after retries" ~fields:[
              ("attempts", Value.int n);
              ("sql", Value.string sql);
            ];
            failwith "Query failed"
          end else begin
            Log.warnf "Query failed, retrying (attempt %d/%d)" n max_attempts;
            Unix.sleepf 0.1;
            attempt (n + 1)
          end
    in
    attempt 1
end

(** {1 Transaction Management} *)

module Transaction = struct
  type t = {
    conn : connection;
    id : string;
    mutable committed : bool;
  }
  [@@warning "-69"]  (* Allow unused fields in example code *)

  (** Begin transaction *)
  let begin_txn conn =
    let txn_id = Printf.sprintf "txn_%d" (Random.int 1000000) in

    Log.with_span "begin_transaction" (fun () ->
      Log.info_fields "Starting transaction" ~fields:[
        ("txn_id", Value.string txn_id);
      ];

      { conn; id = txn_id; committed = false }
    )

  (** Commit transaction *)
  let commit txn =
    Log.with_span "commit_transaction" (fun () ->
      Log.info_fields "Committing transaction" ~fields:[
        ("txn_id", Value.string txn.id);
      ];

      Unix.sleepf 0.02;
      txn.committed <- true;

      Log.success_fields "Transaction committed" ~fields:[
        ("txn_id", Value.string txn.id);
      ]
    )

  (** Rollback transaction *)
  let rollback txn =
    Log.warn_fields "Rolling back transaction" ~fields:[
      ("txn_id", Value.string txn.id);
    ];

    txn.committed <- false;

    Log.info "Transaction rolled back"
end

(** {1 Cache Layer} *)

module Cache = struct
  (* Use explicit namespace for cache component *)
  module CacheLog = Flo_scoped.Make(struct
    let namespace = "mydb.cache"
  end)

  type t = (string, string list) Hashtbl.t

  let create () =
    CacheLog.info "Creating query cache";
    Hashtbl.create 64

  let get cache key =
    CacheLog.tracef "Cache lookup: %s" key;

    match Hashtbl.find_opt cache key with
    | Some result ->
        CacheLog.debug_fields "Cache hit" ~fields:[
          ("key", Value.string key);
          ("result_count", Value.int (List.length result));
        ];
        Some result
    | None ->
        CacheLog.debugf "Cache miss: %s" key;
        None

  let set cache key value =
    CacheLog.tracef "Cache set: %s" key;
    Hashtbl.replace cache key value;

    CacheLog.debug_fields "Query cached" ~fields:[
      ("key", Value.string key);
      ("result_count", Value.int (List.length value));
    ]

  let stats cache =
    let size = Hashtbl.length cache in
    CacheLog.info_fields "Cache statistics" ~fields:[
      ("entries", Value.int size);
    ];
    size
end

(** {1 Configuration} *)

(** Configure MyDB logging

    Call this from your application to set verbosity levels.

    Example:
    {[
      (* Quiet by default *)
      MyDB.configure_logging Severity.Warn;

      (* Debug specific components *)
      Flo.set_level_for "mydb.query" Severity.Debug;
      Flo.set_level_for "mydb.cache" Severity.Trace;
    ]}
*)
let configure_logging level =
  Log.set_level level;
  Log.infof "MyDB logging configured to %s" (Severity.to_string level)
