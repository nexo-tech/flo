(* Simple application demonstrating Flo's zero-configuration logging *)

open Flo

(* Example data processing function *)
let process_item item_id =
  Flo.debugf "Processing item: %s" item_id;
  (* Simulate some work *)
  let duration = 0.042 in
  duration

(* Example order processing with context *)
let process_order order_id user =
  Flo.with_span "handle_order" (fun () ->
    (* Bind context for this operation *)
    Flo.bind [
      Flo.user_id user;
      ("order_id", Value.string order_id);
    ];

    Flo.info "Processing order";

    (* Process items *)
    let items = ["item1"; "item2"; "item3"] in
    List.iter (fun item ->
      let _duration = process_item item in
      ()
    ) items;

    Flo.successf "Order %s completed" order_id
  )

(* Example risky operation for exception handling *)
let risky_operation () =
  if Random.bool () then
    42
  else
    failwith "Random failure occurred"

(* Main application *)
let main () =
  Eio_main.run @@ fun _env ->
    (* Zero configuration - just use it! *)
    Flo.info "Application started";

    (* Printf-style logging *)
    let count = 100 in
    let duration = 2.5 in
    Flo.successf "Processed %d items in %.2fs" count duration;

    (* Structured logging with semantic conventions *)
    Flo.info_fields "HTTP request" ~fields:[
      Flo.http_method "POST";
      Flo.http_status 201;
      Flo.duration_ms 42.5;
    ];

    (* Context propagation with trace ID *)
    Flo.with_trace_id "trace-abc-123" (fun () ->
      Flo.info "Inside traced context";

      (* Nested span *)
      process_order "ORD-12345" "alice"
    );

    (* Debug and trace logging (filtered by default Info level) *)
    Flo.debug "This is debug info (filtered unless level changed)";
    Flo.trace "This is trace info (filtered unless level changed)";

    (* Warning and error logging *)
    Flo.warn "This is a warning";
    Flo.error "This is an error";

    (* Exception handling with catch decorator *)
    match Flo.catch (fun () ->
      risky_operation ()
    ) with
    | Some result ->
        Flo.successf "Operation succeeded with result: %d" result
    | None ->
        Flo.warn "Operation failed but was caught";

    (* Log an exception directly *)
    let test_exn = Failure "Example exception" in
    Flo.exception_ test_exn;

    (* Context with user *)
    Flo.with_user "bob" (fun () ->
      Flo.info "User-scoped operation";

      (* Multiple levels *)
      Flo.debug "User debug info";
      Flo.success "User operation completed"
    );

    (* Demonstrate level filtering *)
    Flo.info "Current log level can be changed";
    let original_level = Flo.get_level () in
    Flo.infof "Current level: %s" (Severity.to_string original_level);

    (* Change to Debug to see more logs *)
    Flo.set_level Severity.Debug;
    Flo.debug "Now debug logs are visible!";
    Flo.trace "But trace is still filtered";

    (* Change to Trace to see everything *)
    Flo.set_level Severity.Trace;
    Flo.trace "Now even trace logs are visible!";

    (* Restore original level *)
    Flo.set_level original_level;

    Flo.success "Application finished successfully!"

let () =
  (* Enable backtrace for exception logging *)
  Printexc.record_backtrace true;
  main ()
