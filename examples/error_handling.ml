(* Error Handling & Exceptions Examples
 *
 * This example demonstrates error handling patterns with Flo:
 * - Exception catching with automatic logging
 * - Backtraces and stack traces
 * - Structured error events
 * - Error context propagation
 *)

open Flo

(* Define structured error event module at top level *)
module Payment_Failed = struct
  type t = {
    payment_id : string;
    user_id : string;
    amount : float;
    currency : string;
    error_code : string;
    error_message : string;
  }

  let to_value t = Value.Object [
    ("payment_id", Value.String t.payment_id);
    ("user_id", Value.String t.user_id);
    ("amount", Value.Float t.amount);
    ("currency", Value.String t.currency);
    ("error_code", Value.String t.error_code);
    ("error_message", Value.String t.error_message);
  ]

  let event_name = "payment.failed"
  let severity = Severity.Error
end

(* Example 1: Exception Decorator (catch) *)
let example_catch_decorator () =
  Eio.traceln "\n=== Exception Decorator (catch) ===\n";

  (* Function that might fail *)
  let risky_operation x =
    if x > 10 then
      x * 2
    else
      failwith "Value too small"
  in

  (* Use catch to automatically log exceptions *)
  Eio.traceln "Test 1: Successful operation";
  (match Flo.catch (fun () -> risky_operation 20) with
   | Some result ->
       Eio.traceln "  Result: %d" result
   | None ->
       Eio.traceln "  Failed (logged automatically)");

  Eio.traceln "\nTest 2: Failing operation";
  (match Flo.catch (fun () -> risky_operation 5) with
   | Some result ->
       Eio.traceln "  Result: %d" result
   | None ->
       Eio.traceln "  Failed (exception logged automatically)");

  Eio.traceln "\nCatch decorator logs exceptions and returns None on failure"

(* Example 2: Logging Exceptions with Backtraces *)
let example_exception_backtraces () =
  Eio.traceln "\n=== Logging Exceptions with Backtraces ===\n";

  (* Enable backtrace recording *)
  Printexc.record_backtrace true;

  let level1 () = failwith "Error at level 1" in
  let level2 () = level1 () in
  let level3 () = level2 () in

  (* Catch and log with backtrace *)
  try
    level3 ()
  with exn ->
    Flo.exception_ exn;
    Eio.traceln "Exception logged with full backtrace";

  Eio.traceln "\nBacktraces help identify error sources in nested calls"

(* Example 3: Error Context Propagation *)
let example_error_context () =
  Eio.traceln "\n=== Error Context Propagation ===\n";

  let process_payment user_id amount =
    Flo.with_user user_id (fun () ->
      Flo.bind [
        ("operation", Value.String "payment");
        ("amount", Value.Float amount);
      ];

      Flo.info "Processing payment";

      (* Simulate payment failure *)
      if amount > 1000.0 then begin
        Flo.error "Payment failed: amount exceeds limit";
        Error "Amount too large"
      end else begin
        Flo.success "Payment processed successfully";
        Ok "payment-123"
      end
    )
  in

  (* Test with success *)
  Eio.traceln "Test 1: Valid payment";
  (match process_payment "alice" 99.99 with
   | Ok payment_id -> Eio.traceln "  Payment ID: %s" payment_id
   | Error msg -> Eio.traceln "  Error: %s" msg);

  (* Test with failure *)
  Eio.traceln "\nTest 2: Invalid payment (too large)";
  (match process_payment "bob" 5000.0 with
   | Ok payment_id -> Eio.traceln "  Payment ID: %s" payment_id
   | Error msg -> Eio.traceln "  Error: %s" msg);

  Eio.traceln "\nError logs include full context (user_id, operation, amount)"

(* Example 4: Structured Error Events *)
let example_structured_errors () =
  Eio.traceln "\n=== Structured Error Events ===\n";

  (* Log structured error event *)
  let open Payment_Failed in
  let error_data = {
    payment_id = "pay-456";
    user_id = "charlie";
    amount = 199.99;
    currency = "USD";
    error_code = "INSUFFICIENT_FUNDS";
    error_message = "User has insufficient balance";
  } in

  Flo_structured.log_event (module Payment_Failed) error_data;

  Eio.traceln "Structured error event logged with all details"

(* Example 5: Error Rate Monitoring *)
let example_error_rate () =
  Eio.traceln "\n=== Error Rate Monitoring ===\n";

  let error_count = ref 0 in
  let total_count = ref 0 in

  let simulate_requests n =
    for i = 1 to n do
      incr total_count;

      (* 20% failure rate *)
      if i mod 5 = 0 then begin
        incr error_count;
        Flo.error (Printf.sprintf "Request %d failed" i);
      end else begin
        Flo.info (Printf.sprintf "Request %d succeeded" i);
      end
    done
  in

  simulate_requests 20;

  let error_rate = (float_of_int !error_count) /. (float_of_int !total_count) *. 100.0 in
  Eio.traceln "\nError rate: %.1f%% (%d errors / %d total)"
    error_rate !error_count !total_count;

  Eio.traceln "Use error logs to calculate error rates and SLOs"

(* Example 6: Panic vs Recoverable Errors *)
let example_panic_vs_recoverable () =
  Eio.traceln "\n=== Panic vs Recoverable Errors ===\n";

  (* Recoverable error - log and continue *)
  let handle_recoverable () =
    Flo.warn "Recoverable error: retry attempt 1 failed";
    Flo.info "Retrying operation";
    Flo.success "Retry succeeded";
    Ok ()
  in

  (* Panic error - log and exit *)
  let handle_panic () =
    Flo.fatal "PANIC: Database connection pool exhausted";
    Flo.fatal "System cannot continue - initiating shutdown";
    Error "PANIC"
  in

  Eio.traceln "Recoverable error handling:";
  (match handle_recoverable () with
   | Ok () -> Eio.traceln "  ✓ Recovered successfully"
   | Error _ -> Eio.traceln "  ✗ Failed to recover");

  Eio.traceln "\nPanic error handling:";
  (match handle_panic () with
   | Ok () -> Eio.traceln "  System continues"
   | Error msg -> Eio.traceln "  ✗ System shutdown: %s" msg);

  Eio.traceln "\nUse FATAL for unrecoverable errors, WARN/ERROR for recoverable"

(* Example 7: Error with Multiple Attributes *)
let example_rich_error_context () =
  Eio.traceln "\n=== Rich Error Context ===\n";

  let handle_api_error endpoint status body =
    let record = Record.make ~severity:Severity.Error
      ~message:"API request failed" in
    let record = Record.with_attributes [
      ("error.type", Value.String "ApiError");
      ("api.endpoint", Value.String endpoint);
      ("http.status", Value.Int (Int64.of_int status));
      ("response.body", Value.String body);
      ("retry.count", Value.Int 3L);
      ("retry.max", Value.Int 5L);
      ("error.recoverable", Value.Bool true);
    ] record in

    (* Format and display *)
    Eio.traceln "%s" (Flo_format_pretty.format record);
    Eio.traceln "\nRich error context includes:";
    Eio.traceln "  - Error classification";
    Eio.traceln "  - API details";
    Eio.traceln "  - Retry information";
    Eio.traceln "  - Recoverability flag"
  in

  handle_api_error "/api/orders" 503 "Service Unavailable"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Error Handling Examples                           ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_catch_decorator ();
  example_exception_backtraces ();
  example_error_context ();
  example_structured_errors ();
  example_error_rate ();
  example_panic_vs_recoverable ();
  example_rich_error_context ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
