(** Application using MyDB library with namespace-based logging configuration

    This demonstrates how applications can control logging verbosity of
    libraries they depend on, using Flo's namespace system.
*)

[@@@flo.namespace "app"]

open Flo

(* Include the library *)
(* In a real app, this would be: open MyDB *)
(* For this example, we'll simulate the library *)

(** {1 Application Code} *)

(** Handle API request *)
let handle_request method_ path =
  with_span "handle_request" (fun () ->
    [%log.info "Request received" ~method_ ~path];

    bind [
      http_method method_;
      ("path", Value.string path);
    ];

    (* Process request *)
    Unix.sleepf 0.1;

    [%log.success "Request completed" ~status_code:200];
    200
  )

(** Background job processor *)
module Background = struct
  (* Auto-generates "app.background" namespace *)

  let process_job job_id =
    [%log.info "Processing background job" ~job_id];

    Unix.sleepf 0.2;

    [%log.success "Job completed" ~job_id]
end

(** {1 Logging Configuration} *)

(** Configure all logging for the application

    This is where you control verbosity of:
    - Your application code
    - Third-party libraries (mydb, dream, cohttp, etc.)
    - Your own internal libraries
*)
let configure_logging () =
  (* === Application Logs === *)

  (* Default for application code *)
  Flo.set_level Severity.Info;

  (* Debug mode for our API handlers *)
  Flo.set_level_for "app.api" Severity.Debug;

  (* Info level for background jobs *)
  Flo.set_level_for "app.background" Severity.Info;

  (* === Third-Party Library Configuration === *)

  (* MyDB library - configure per component *)
  Flo.set_level_for "mydb" Severity.Warn;  (* Default: quiet *)
  Flo.set_level_for "mydb.connection" Severity.Info;  (* Show connections *)
  Flo.set_level_for "mydb.query" Severity.Debug;  (* Debug queries *)
  Flo.set_level_for "mydb.cache" Severity.Warn;  (* Quiet cache *)

  (* Hypothetical other libraries *)
  Flo.set_level_for "dream" Severity.Warn;  (* Web framework *)
  Flo.set_level_for "cohttp.client" Severity.Error;  (* HTTP client *)

  (* Log the configuration *)
  info "Logging configured";

  (* Show active namespaces *)
  let all_levels = Flo.get_all_levels () in
  infof "Configured %d namespaces:" (List.length all_levels);
  List.iter (fun (ns, level) ->
    let effective = Flo.get_effective_level ns in
    infof "  %-30s configured=%-7s effective=%s"
      ns
      (Severity.to_string level)
      (Severity.to_string effective)
  ) all_levels

(** {1 Application Entry Point} *)

let main () =
  Eio_main.run @@ fun _env ->
    (* Step 1: Configure logging FIRST *)
    configure_logging ();

    info "=== Application Started ===";
    info "";

    (* Step 2: Use the library with configured logging *)
    info "--- Demonstrating Library Logging Control ---";

    (* The library logs will respect our configuration *)
    (* Since this is an example, we'll inline the library code *)

    (* Simulate MyDB connection *)
    info "Connecting to database...";
    scoped_info "mydb.connection" "Attempting database connection";
    scoped_debug_fields "mydb.connection" "Connection params" ~fields:[
      ("host", Value.string "localhost");
      ("port", Value.int 5432);
    ];

    Unix.sleepf 0.1;

    scoped_success "mydb.connection" "Database connected";

    info "";

    (* Simulate MyDB query with debug enabled *)
    info "Executing query (mydb.query at Debug level - verbose)...";
    scoped_debug_fields "mydb.query" "Executing query" ~fields:[
      ("sql", Value.string "SELECT * FROM users");
    ];

    Unix.sleepf 0.05;

    scoped_debug_fields "mydb.query" "Query completed" ~fields:[
      ("row_count", Value.int 5);
      ("execution_time_ms", Value.float 50.0);
    ];

    info "";

    (* Simulate MyDB cache (warn level - quiet) *)
    info "Cache operations (mydb.cache at Warn level - quiet)...";
    (* These debug/trace logs are filtered *)
    scoped_trace "mydb.cache" "Cache lookup: user_123";  (* Filtered *)
    scoped_debug "mydb.cache" "Cache hit: user_123";  (* Filtered *)

    info "(Cache debug logs filtered - you don't see them)";
    info "";

    (* Step 3: Application code with namespaces *)
    info "--- Application Code with Namespaces ---";

    (* Application API (debug enabled) *)
    with_namespace "app.api" (fun () ->
      info "Handling API request";
      debug "Request validation passed";  (* Visible - app.api at Debug *)

      let _status = handle_request "POST" "/api/users" in
      ()
    );

    info "";

    (* Background jobs (info level) *)
    Background.process_job "job-123";

    info "";

    (* Step 4: Dynamic level adjustment *)
    info "--- Dynamic Level Adjustment ---";

    info "Current cache level:";
    let cache_level = Flo.get_effective_level "mydb.cache" in
    infof "  mydb.cache: %s" (Severity.to_string cache_level);

    info "Enabling debug for cache...";
    Flo.set_level_for "mydb.cache" Severity.Debug;

    (* Now cache logs are visible *)
    scoped_debug "mydb.cache" "Cache operations now visible!";

    info "";

    (* Step 5: Summary *)
    success "=== Application Finished ===";
    info "";
    info "Key Takeaways:";
    info "  1. Libraries use namespaces for their logs";
    info "  2. Applications configure verbosity per namespace";
    info "  3. Hierarchical namespaces inherit parent levels";
    info "  4. Levels can be changed dynamically at runtime";
    info "  5. No changes needed to library code!";
    info "";

    success "Namespace-based logging provides fine-grained control!"

let () =
  Printexc.record_backtrace true;
  main ()
