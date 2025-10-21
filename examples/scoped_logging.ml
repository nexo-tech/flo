(* Scoped Logging Example

   This example demonstrates how to use Flo's namespace-based logging system
   for fine-grained control over log verbosity per component.

   It shows:
   1. How libraries create scoped loggers using functors
   2. How applications configure namespace levels
   3. Multiple namespaces working together
   4. Integration with context and distributed tracing
*)

open Flo

(* ============================================================================
   PART 1: Library Code with Scoped Loggers
   ============================================================================ *)

(* Simulated "Database Library" using Flo_scoped *)
module Database = struct
  (* Create a scoped logger for this component *)
  module Log = Flo_scoped.Make(struct
    let namespace = "mylib.database"
  end)

  type connection = { host : string; port : int }

  let connect ~host ~port =
    Log.info "Attempting database connection";
    Log.debug_fields "Connection parameters" ~fields:[
      ("host", Value.string host);
      ("port", Value.int port);
    ];

    (* Simulate connection *)
    Unix.sleepf 0.1;

    Log.success "Database connection established";
    { host; port }

  let query conn sql =
    Log.with_span "db_query" (fun () ->
      Log.debug_fields "Executing query" ~fields:[
        ("sql", Value.string sql);
        ("host", Value.string conn.host);
      ];

      (* Simulate query *)
      Unix.sleepf 0.05;

      Log.debugf "Query returned 5 rows in 50ms";
      ["row1"; "row2"; "row3"; "row4"; "row5"]
    )

  let close conn =
    Log.infof "Closing connection to %s:%d" conn.host conn.port;
    Log.debug "Connection closed successfully"
end

(* Simulated "Cache Library" using Flo_scoped *)
module Cache = struct
  (* Create a scoped logger for this component *)
  module Log = Flo_scoped.Make(struct
    let namespace = "mylib.cache"
  end)

  type t = (string, string) Hashtbl.t

  let create () : t =
    Log.info "Creating cache instance";
    Hashtbl.create 128

  let get (cache : t) key =
    Log.tracef "Cache lookup: %s" key;
    match Hashtbl.find_opt cache key with
    | Some value ->
        Log.debugf "Cache hit: %s" key;
        Some value
    | None ->
        Log.debugf "Cache miss: %s" key;
        None

  let set (cache : t) key value =
    Log.tracef "Cache set: %s" key;
    Hashtbl.replace cache key value;
    Log.debugf "Cached %s = %s" key value

  let stats (cache : t) =
    let size = Hashtbl.length cache in
    Log.info_fields "Cache statistics" ~fields:[
      ("size", Value.int size);
      ("capacity", Value.int 128);
    ];
    size
end

(* Simulated "API Handler Library" using Flo_scoped *)
module ApiHandler = struct
  (* Create a scoped logger for this component *)
  module Log = Flo_scoped.Make(struct
    let namespace = "mylib.api"
  end)

  let handle_request method_ path =
    Log.with_span "handle_request" (fun () ->
      Log.info_fields "Request received" ~fields:[
        Flo.http_method method_;
        ("path", Value.string path);
      ];

      (* Bind request-specific context *)
      Log.bind [
        ("request_id", Value.string "req-12345");
      ];

      Log.debug "Processing request";

      (* Simulate processing *)
      Unix.sleepf 0.02;

      Log.info_fields "Request completed" ~fields:[
        Flo.http_status 200;
        Flo.duration_ms 20.0;
      ];

      200
    )
end

(* Simulated "Authentication Library" using runtime logger *)
module Auth = struct
  (* Demonstrate runtime logger creation *)
  let create_logger component =
    Flo_scoped.create ("mylib.auth." ^ component)

  let authenticate username password =
    (* Create logger for this specific auth component *)
    let logger = create_logger "basic" in
    let module Log = (val logger : Flo_scoped.LOGGER) in

    Log.info_fields "Authentication attempt" ~fields:[
      ("username", Value.string username);
      ("method", Value.string "basic");
    ];

    (* Simulate auth check *)
    if username <> "" && password <> "" then begin
      Log.successf "User %s authenticated" username;
      true
    end else begin
      Log.warn_fields "Authentication failed" ~fields:[
        ("username", Value.string username);
        ("reason", Value.string "invalid_credentials");
      ];
      false
    end

  let oauth_authenticate token =
    (* Different component, different logger *)
    let logger = create_logger "oauth" in
    let module Log = (val logger : Flo_scoped.LOGGER) in

    Log.info "OAuth authentication";
    Log.debugf "Token length: %d" (String.length token);

    (* Simulate OAuth validation *)
    if String.length token > 10 then begin
      Log.success "OAuth token validated";
      true
    end else begin
      Log.error "Invalid OAuth token";
      false
    end
end

(* ============================================================================
   PART 2: Application Code Using the Libraries
   ============================================================================ *)

let main () =
  Eio_main.run @@ fun _env ->
    (* Enable backtrace for exception logging *)
    Printexc.record_backtrace true;

    Flo.info "=== Scoped Logging Example ===";
    Flo.info "";

    (* ========================================================================
       CONFIGURATION: Application controls verbosity per namespace
       ======================================================================== *)

    Flo.info "Configuring namespace levels...";

    (* Set global default level *)
    Flo.set_level Severity.Info;

    (* Configure library components independently *)
    Flo.set_level_for "mylib.database" Severity.Debug;   (* Debug for database *)
    Flo.set_level_for "mylib.cache" Severity.Warn;       (* Only warnings for cache *)
    Flo.set_level_for "mylib.api" Severity.Info;         (* Info for API *)
    Flo.set_level_for "mylib.auth.basic" Severity.Debug; (* Debug basic auth *)
    Flo.set_level_for "mylib.auth.oauth" Severity.Info;  (* Info for OAuth *)

    (* Show configured levels *)
    Flo.info "";
    Flo.info "Namespace configuration:";
    let all_levels = Flo.get_all_levels () in
    List.iter (fun (ns, level) ->
      Flo.infof "  %s -> %s" ns (Severity.to_string level)
    ) all_levels;

    Flo.info "";
    Flo.info "Starting demonstration...";
    Flo.info "";

    (* ========================================================================
       DEMO 1: Database with DEBUG level
       ======================================================================== *)

    Flo.info "--- Demo 1: Database Operations (Debug level) ---";

    (* Database logs at Debug - we'll see detailed logs *)
    let db = Database.connect ~host:"localhost" ~port:5432 in
    let _results = Database.query db "SELECT * FROM users WHERE id = 1" in
    Database.close db;

    Flo.info "";

    (* ========================================================================
       DEMO 2: Cache with WARN level (trace/debug filtered)
       ======================================================================== *)

    Flo.info "--- Demo 2: Cache Operations (Warn level - quiet) ---";

    (* Cache logs at Warn - only warnings/errors visible, debug/trace filtered *)
    let cache = Cache.create () in
    Cache.set cache "key1" "value1";
    let _v1 = Cache.get cache "key1" in  (* Debug logs filtered *)
    let _v2 = Cache.get cache "key2" in  (* Debug logs filtered *)
    let _size = Cache.stats cache in

    Flo.info "";

    (* ========================================================================
       DEMO 3: API Handler with INFO level
       ======================================================================== *)

    Flo.info "--- Demo 3: API Handler (Info level) ---";

    (* API logs at Info - info/success/warn/error visible, debug filtered *)
    let _status1 = ApiHandler.handle_request "GET" "/users/123" in
    let _status2 = ApiHandler.handle_request "POST" "/orders" in

    Flo.info "";

    (* ========================================================================
       DEMO 4: Authentication with different levels
       ======================================================================== *)

    Flo.info "--- Demo 4: Authentication (different levels per method) ---";

    (* Basic auth at Debug - detailed logs *)
    Flo.info "Basic authentication (Debug level - verbose):";
    let _auth1 = Auth.authenticate "alice" "secret123" in
    let _auth2 = Auth.authenticate "" "" in  (* Fail *)

    Flo.info "";

    (* OAuth at Info - less verbose *)
    Flo.info "OAuth authentication (Info level - less verbose):";
    let _auth3 = Auth.oauth_authenticate "valid_token_12345" in
    let _auth4 = Auth.oauth_authenticate "short" in  (* Fail *)

    Flo.info "";

    (* ========================================================================
       DEMO 5: Hierarchical namespace inheritance
       ======================================================================== *)

    Flo.info "--- Demo 5: Hierarchical Inheritance ---";

    (* Create sub-component logger *)
    let module SubComponent = Flo_scoped.Make(struct
      let namespace = "mylib.database.pool"
    end) in

    Flo.infof "Effective level for 'mylib.database.pool': %s"
      (Severity.to_string (SubComponent.get_effective_level ()));

    (* Should inherit Debug from mylib.database *)
    SubComponent.debug "This debug log is visible (inherited Debug level)";
    SubComponent.info "Info log from sub-component";

    Flo.info "";

    (* ========================================================================
       DEMO 6: Context-based namespace with global Flo
       ======================================================================== *)

    Flo.info "--- Demo 6: Context-Based Namespace ---";

    (* Use with_namespace for automatic scoping *)
    Flo.with_namespace "app.service" (fun () ->
      Flo.info "Inside app.service namespace";

      (* Nested namespaces *)
      Flo.with_namespace "app.service.worker" (fun () ->
        Flo.info "Inside app.service.worker namespace";

        (* With distributed tracing *)
        Flo.with_span "process_job" (fun () ->
          Flo.info "Processing job with namespace and span";
          (* This log has both namespace and trace context *)
        )
      );

      Flo.info "Back to app.service namespace"
    );

    Flo.info "";

    (* ========================================================================
       DEMO 7: Mixed scoped and global logging
       ======================================================================== *)

    Flo.info "--- Demo 7: Mixed Scoped and Global Logging ---";

    (* Global logs (no namespace) *)
    Flo.info "This is a global log (no namespace)";

    (* Scoped function (explicit namespace) *)
    Flo.scoped_info "app.feature" "This is explicitly scoped";

    (* Context-based namespace *)
    Flo.with_namespace "app.feature" (fun () ->
      Flo.info "This inherits namespace from context";

      (* Scoped function overrides context *)
      Flo.scoped_info "other.namespace" "This overrides the context namespace";
    );

    Flo.info "";

    (* ========================================================================
       DEMO 8: Dynamic namespace configuration
       ======================================================================== *)

    Flo.info "--- Demo 8: Dynamic Level Changes ---";

    (* Show current cache level *)
    let cache_level = Cache.Log.get_effective_level () in
    Flo.infof "Cache current level: %s" (Severity.to_string cache_level);

    (* Change cache level dynamically *)
    Flo.info "Changing cache level to Debug...";
    Cache.Log.set_level Severity.Debug;

    (* Now cache debug logs will be visible *)
    Cache.set cache "key3" "value3";
    let _v3 = Cache.get cache "key3" in

    (* Reset to warn *)
    Cache.Log.set_level Severity.Warn;
    Flo.info "Cache level reset to Warn";

    Flo.info "";

    (* ========================================================================
       DEMO 9: Multiple independent loggers
       ======================================================================== *)

    Flo.info "--- Demo 9: Multiple Independent Loggers ---";

    (* Create multiple loggers for different features *)
    let module Feature1 = Flo_scoped.Make(struct
      let namespace = "app.feature1"
    end) in

    let module Feature2 = Flo_scoped.Make(struct
      let namespace = "app.feature2"
    end) in

    let module Feature3 = Flo_scoped.Make(struct
      let namespace = "app.feature3"
    end) in

    (* Configure each independently *)
    Feature1.set_level Severity.Debug;
    Feature2.set_level Severity.Info;
    Feature3.set_level Severity.Warn;

    (* Each logs according to its level *)
    Feature1.debug "Feature1 debug log (visible)";
    Feature1.info "Feature1 info log";

    Feature2.debug "Feature2 debug log (filtered)";
    Feature2.info "Feature2 info log (visible)";

    Feature3.debug "Feature3 debug log (filtered)";
    Feature3.info "Feature3 info log (filtered)";
    Feature3.warn "Feature3 warn log (visible)";

    Flo.info "";

    (* ========================================================================
       DEMO 10: Summary of namespace capabilities
       ======================================================================== *)

    Flo.success "=== Summary ===";
    Flo.info "";
    Flo.info "Namespace logging enables:";
    Flo.info "  1. Libraries can log without forcing verbosity on applications";
    Flo.info "  2. Applications control log levels per component";
    Flo.info "  3. Hierarchical namespaces with inheritance";
    Flo.info "  4. Integration with distributed tracing";
    Flo.info "  5. Type-safe compile-time loggers via functors";
    Flo.info "  6. Runtime loggers for dynamic configuration";
    Flo.info "";

    (* Show all configured namespaces *)
    Flo.info "Final namespace configuration:";
    let final_levels = Flo.get_all_levels () in
    List.iter (fun (ns, level) ->
      let effective = Flo.get_effective_level ns in
      Flo.infof "  %-25s configured=%-7s effective=%s"
        ns
        (Severity.to_string level)
        (Severity.to_string effective)
    ) final_levels;

    Flo.info "";
    Flo.success "Example completed successfully!"

(* ============================================================================
   Entry Point
   ============================================================================ *)

let () =
  Printexc.record_backtrace true;
  main ()
