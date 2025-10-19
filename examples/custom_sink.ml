(* Custom Sink Implementation Examples
 *
 * This example demonstrates how to create custom sinks for specialized
 * logging destinations (webhooks, databases, message queues, etc.)
 *)

(* Example 1: Simple In-Memory Sink *)
let example_memory_sink () =
  print_endline "\n=== Simple In-Memory Sink ===\n";

  (* Define an in-memory sink module *)
  let module Memory_Sink = struct
    type t = {
      logs : Record.t list ref;
      max_size : int;
    }

    let create max_size = {
      logs = ref [];
      max_size;
    }

    let write sink record =
      (* Add to front, keep only max_size entries *)
      sink.logs := record :: !(sink.logs);
      if List.length !(sink.logs) > sink.max_size then
        sink.logs := List.filteri (fun i _ -> i < sink.max_size) !(sink.logs)

    let get_logs sink = List.rev !(sink.logs)
  end in

  (* Use the sink *)
  let sink = Memory_Sink.create 100 in

  for i = 1 to 5 do
    let record = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "Log message %d" i) in
    Memory_Sink.write sink record
  done;

  let logs = Memory_Sink.get_logs sink in
  Printf.printf "Captured %d logs in memory\n" (List.length logs);
  List.iter (fun r ->
    Printf.printf "  - %s\n" r.Record.message
  ) logs;

  print_endline "\nUse case: Testing, debugging, log aggregation"

(* Example 2: Webhook Sink (HTTP POST) *)
let example_webhook_sink () =
  print_endline "\n=== Webhook Sink (HTTP POST) ===\n";

  let module Webhook_Sink = struct
    type t = {
      endpoint : string;
      min_level : Severity.t;
    }

    let create endpoint min_level = {
      endpoint;
      min_level;
    }

    let write sink record =
      if Severity.compare record.Record.severity sink.min_level >= 0 then begin
        let json = Flo_format_json.format record in
        (* In real implementation: HTTP POST to sink.endpoint *)
        Printf.printf "→ POST %s\n" sink.endpoint;
        Printf.printf "  Body: %s\n" json
      end
  end in

  let sink = Webhook_Sink.create "https://hooks.example.com/logs" Severity.Error in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Normal operation";
    Record.make ~severity:Severity.Error ~message:"Error occurred";
    Record.make ~severity:Severity.Fatal ~message:"Critical failure";
  ] in

  List.iter (Webhook_Sink.write sink) records;

  print_endline "\nUse case: Slack notifications, PagerDuty alerts, webhooks"

(* Example 3: Database Sink (SQL Insert) *)
let example_database_sink () =
  print_endline "\n=== Database Sink (SQL Insert) ===\n";

  let module Database_Sink = struct
    type t = {
      table_name : string;
      batch : Record.t list ref;
      batch_size : int;
    }

    let create table_name batch_size = {
      table_name;
      batch = ref [];
      batch_size;
    }

    let write sink record =
      sink.batch := record :: !(sink.batch);

      (* Flush when batch is full *)
      if List.length !(sink.batch) >= sink.batch_size then begin
        Printf.printf "INSERT INTO %s (%d rows):\n" sink.table_name (List.length !(sink.batch));
        List.iter (fun r ->
          Printf.printf "  ('%s', '%s', '%s')\n"
            (Ptime.to_rfc3339 (Record.get_timestamp r))
            (Severity.to_string r.Record.severity)
            r.Record.message
        ) (List.rev !(sink.batch));
        sink.batch := []
      end

    let flush sink =
      if !(sink.batch) <> [] then begin
        Printf.printf "FLUSH INSERT INTO %s (%d rows)\n"
          sink.table_name (List.length !(sink.batch));
        sink.batch := []
      end
  end in

  let sink = Database_Sink.create "logs" 3 in

  for i = 1 to 7 do
    let record = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "Log %d" i) in
    Database_Sink.write sink record
  done;

  Database_Sink.flush sink;

  print_endline "\nUse case: Centralized log database, queryable logs"

(* Example 4: Filtered Sink (Errors Only) *)
let example_filtered_sink () =
  print_endline "\n=== Filtered Sink (Errors Only) ===\n";

  let module Filtered_Sink = struct
    type t = {
      underlying : Record.t -> unit;
      predicate : Record.t -> bool;
    }

    let create ~predicate ~underlying = {
      underlying;
      predicate;
    }

    let write sink record =
      if sink.predicate record then
        sink.underlying record
  end in

  (* Base sink *)
  let base_sink record =
    Printf.printf "[SINK] %s - %s\n"
      (Severity.to_string record.Record.severity)
      record.Record.message
  in

  (* Filtered to errors only *)
  let error_sink = Filtered_Sink.create
    ~predicate:(fun r -> Severity.compare r.Record.severity Severity.Error >= 0)
    ~underlying:base_sink
  in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Info (filtered)";
    Record.make ~severity:Severity.Error ~message:"Error (passed)";
    Record.make ~severity:Severity.Fatal ~message:"Fatal (passed)";
  ] in

  List.iter (Filtered_Sink.write error_sink) records;

  print_endline "\nUse case: Alert-only logs, error monitoring"

(* Example 5: Rate-Limited Sink *)
let example_rate_limited_sink () =
  print_endline "\n=== Rate-Limited Sink ===\n";

  let module Rate_Limited_Sink = struct
    type t = {
      underlying : Record.t -> unit;
      max_per_second : int;
      mutable count : int;
      mutable last_reset : float;
    }

    let create max_per_second underlying = {
      underlying;
      max_per_second;
      count = 0;
      last_reset = Unix.gettimeofday ();
    }

    let write sink record =
      let now = Unix.gettimeofday () in

      (* Reset counter every second *)
      if now -. sink.last_reset >= 1.0 then begin
        sink.count <- 0;
        sink.last_reset <- now
      end;

      (* Check rate limit *)
      if sink.count < sink.max_per_second then begin
        sink.underlying record;
        sink.count <- sink.count + 1
      end else begin
        (* Drop log - rate limit exceeded *)
        if sink.count = sink.max_per_second then
          Printf.printf "[RATE_LIMIT] Dropping logs (limit: %d/sec)\n"
            sink.max_per_second;
        sink.count <- sink.count + 1
      end
  end in

  let base record =
    Printf.printf "[LOG] %s\n" record.Record.message
  in

  let limited_sink = Rate_Limited_Sink.create 3 base in

  (* Try to log 10 messages rapidly *)
  for i = 1 to 10 do
    let record = Record.make ~severity:Severity.Info
      ~message:(Printf.sprintf "Message %d" i) in
    Rate_Limited_Sink.write limited_sink record
  done;

  print_endline "\nUse case: Prevent log flooding, protect disk I/O"

(* Example 6: Multi-Format Sink (Auto-Select by Severity) *)
let example_multi_format_sink () =
  print_endline "\n=== Multi-Format Sink (Auto-Select) ===\n";

  let module Smart_Format_Sink = struct
    let write record =
      (* Errors in JSON (machine-parseable) *)
      if Severity.compare record.Record.severity Severity.Error >= 0 then begin
        Printf.printf "[JSON] %s\n" (Flo_format_json.format record)
      end
      (* Info/Success in Pretty (human-readable) *)
      else begin
        Printf.printf "[PRETTY] %s\n" (Flo_format_pretty.format record)
      end
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Normal operation";
    Record.make ~severity:Severity.Success ~message:"Task completed";
    Record.make ~severity:Severity.Error ~message:"Error occurred";
  ] in

  List.iter Smart_Format_Sink.write records;

  print_endline "\nUse case: Different formats for different severities"

(* Main *)
let () =
  print_endline "╔════════════════════════════════════════════════════════════════╗";
  print_endline "║              Flō Custom Sink Examples                          ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝";

  example_memory_sink ();
  example_webhook_sink ();
  example_database_sink ();
  example_filtered_sink ();
  example_rate_limited_sink ();
  example_multi_format_sink ();

  print_endline "\n╔════════════════════════════════════════════════════════════════╗";
  print_endline "║                   All Examples Complete!                       ║";
  print_endline "╚════════════════════════════════════════════════════════════════╝"
