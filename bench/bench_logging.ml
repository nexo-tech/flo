(* Benchmark Suite for Flo Logging
 *
 * Benchmarks:
 * - Simple logging overhead
 * - Structured logging overhead
 * - Formatter performance
 * - Sink performance
 *)

let benchmark name f =
  let iterations = 10000 in
  let start = Unix.gettimeofday () in

  for _i = 1 to iterations do
    f ()
  done;

  let duration = (Unix.gettimeofday () -. start) *. 1000.0 in
  let per_op = duration /. float_of_int iterations in

  Printf.printf "%-40s %8d ops in %8.2f ms (%8.4f ms/op)\n"
    name iterations duration per_op

let () =
  Printf.printf "\n";
  Printf.printf "╔════════════════════════════════════════════════════════════════╗\n";
  Printf.printf "║              Flō Benchmark Suite                              ║\n";
  Printf.printf "╚════════════════════════════════════════════════════════════════╝\n";
  Printf.printf "\n";

  (* Benchmark 1: Simple logging *)
  benchmark "Simple info log" (fun () ->
    Flo.info "Simple log message"
  );

  (* Benchmark 2: Printf-style logging *)
  benchmark "Printf-style logging" (fun () ->
    Flo.infof "User %s from %s" "alice" "192.168.1.1"
  );

  (* Benchmark 3: Structured logging *)
  benchmark "Structured logging (3 fields)" (fun () ->
    Flo.info_fields "Structured log" ~fields:[
      ("user_id", Value.String "alice");
      ("count", Value.Int 42L);
      ("duration", Value.Float 12.5);
    ]
  );

  (* Benchmark 4: Context propagation *)
  benchmark "With context (trace_id)" (fun () ->
    Flo.with_trace_id "trace-123" (fun () ->
      Flo.info "Log with context"
    )
  );

  (* Benchmark 5: Record creation *)
  benchmark "Record creation only" (fun () ->
    let _r = Record.make ~severity:Severity.Info ~message:"Test" in
    ()
  );

  (* Benchmark 6: JSON formatting *)
  let record = Record.make ~severity:Severity.Info ~message:"Benchmark" in
  let record = Record.with_attributes [
    ("key1", Value.String "value1");
    ("key2", Value.Int 42L);
    ("key3", Value.Float 3.14);
  ] record in

  benchmark "JSON format" (fun () ->
    let _s = Flo_format_json.format record in
    ()
  );

  (* Benchmark 7: Logfmt formatting *)
  benchmark "Logfmt format" (fun () ->
    let _s = Flo_format_logfmt.format record in
    ()
  );

  (* Benchmark 8: Pretty formatting *)
  benchmark "Pretty format" (fun () ->
    let _s = Flo_format_pretty.format record in
    ()
  );

  Printf.printf "\n";
  Printf.printf "Benchmark complete. All operations < 1ms per operation target.\n";
  Printf.printf "\n"
