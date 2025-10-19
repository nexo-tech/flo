(* Pretty Console Output Examples
 *
 * This example demonstrates beautiful terminal output with colors,
 * formatting options, and human-readable log display.
 *)

(* Example 1: Colored Console Output (Default) *)
let example_colored_default () =
  Eio.traceln "\n=== Colored Console Output (Default) ===\n";

  (* Create logs with different severity levels - colors auto-applied *)
  let records = [
    (Severity.Trace, "Fine-grained trace information");
    (Severity.Debug, "Debug information for developers");
    (Severity.Info, "General informational message");
    (Severity.Success, "Operation completed successfully!");
    (Severity.Warn, "Warning: approaching rate limit");
    (Severity.Error, "Error: failed to connect to database");
    (Severity.Fatal, "Fatal: out of memory, shutting down");
  ] in

  List.iter (fun (severity, msg) ->
    let record = Record.make ~severity ~message:msg in
    Eio.traceln "%s" (Flo_format_pretty.format record)
  ) records;

  Eio.traceln "\nColor scheme:";
  Eio.traceln "  TRACE   - Gray (dim)";
  Eio.traceln "  DEBUG   - Cyan";
  Eio.traceln "  INFO    - Blue";
  Eio.traceln "  SUCCESS - Green (Loguru-style)";
  Eio.traceln "  WARN    - Yellow";
  Eio.traceln "  ERROR   - Red";
  Eio.traceln "  FATAL   - Bold Red"

(* Example 2: No-Color Mode for CI/CD *)
let example_no_color () =
  Eio.traceln "\n=== No-Color Mode (CI/CD) ===\n";

  let record = Record.make ~severity:Severity.Success ~message:"Build completed" in
  let record = Record.with_attributes [
    ("duration_s", Value.Float 45.2);
    ("tests_passed", Value.Int 150L);
  ] record in

  (* Colored output *)
  Eio.traceln "Colored (terminal):";
  Eio.traceln "%s" (Flo_format_pretty.format record);

  (* Strip colors for CI/CD *)
  Eio.traceln "\nNo-color (CI/CD):";
  let plain = Flo_format_pretty.format record in
  let no_ansi = Str.global_replace (Str.regexp "\027\\[[0-9;]*m") "" plain in
  Eio.traceln "%s" no_ansi;

  Eio.traceln "\nUse NO_COLOR=1 environment variable for automatic detection"

(* Example 3: Custom Color Schemes per Severity *)
let example_custom_colors () =
  Eio.traceln "\n=== Custom Color Schemes ===\n";

  (* Create a solarized-style color scheme *)
  let module Solarized : Flo_format_pretty.FORMATTER = struct
    let format record =
      let color = match record.Record.severity with
        | Severity.Trace -> "\027[38;5;241m"    (* base01 *)
        | Severity.Debug -> "\027[38;5;33m"     (* blue *)
        | Severity.Info -> "\027[38;5;37m"      (* cyan *)
        | Severity.Success -> "\027[38;5;64m"   (* green *)
        | Severity.Warn -> "\027[38;5;136m"     (* yellow *)
        | Severity.Error -> "\027[38;5;160m"    (* orange *)
        | Severity.Fatal -> "\027[1;38;5;124m"  (* bold red *)
      in

      let ts = Ptime.to_rfc3339 ~frac_s:3 (Record.get_timestamp record) in
      let level = String.uppercase_ascii (Severity.to_string record.Record.severity) in
      let reset = "\027[0m" in

      Printf.sprintf "[%s] %s%-7s%s %s"
        ts color level reset record.Record.message

    let parse _s = Error "Not implemented"
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Solarized info";
    Record.make ~severity:Severity.Success ~message:"Solarized success";
    Record.make ~severity:Severity.Error ~message:"Solarized error";
  ] in

  List.iter (fun r -> Eio.traceln "%s" (Solarized.format r)) records

(* Example 4: Compact vs Verbose Pretty Format *)
let example_compact_vs_verbose () =
  Eio.traceln "\n=== Compact vs Verbose Format ===\n";

  let record = Record.make ~severity:Severity.Info ~message:"HTTP request" in
  let loc = Location.make_full ~file:"api.ml" ~line:42 ~column:10 ~module_name:"Api" () in
  let record = Record.with_location loc record in
  let record = Record.with_attributes [
    ("method", Value.String "POST");
    ("path", Value.String "/api/orders");
    ("status", Value.Int 201L);
    ("duration_ms", Value.Float 42.5);
  ] record in

  (* Compact format - default *)
  Eio.traceln "Compact (default):";
  Eio.traceln "%s" (Flo_format_pretty.format record);

  (* Verbose format - all fields *)
  Eio.traceln "\nVerbose (all fields):";
  let module Verbose : Flo_format_pretty.FORMATTER = struct
    let format r =
      let buf = Buffer.create 256 in
      Printf.bprintf buf "[%s] " (Ptime.to_rfc3339 (Record.get_timestamp r));
      Printf.bprintf buf "[%s] " (Severity.to_string r.Record.severity);
      Printf.bprintf buf "%s" r.Record.message;
      (match r.Record.location with
       | Some loc -> Printf.bprintf buf " @ %s" (Location.to_string loc)
       | None -> ());
      if r.Record.attributes <> [] then
        Printf.bprintf buf "\n  Fields: %s"
          (String.concat ", " (List.map (fun (k, v) ->
            Printf.sprintf "%s=%s" k (Value.to_string v)
          ) r.Record.attributes));
      Buffer.contents buf

    let parse _s = Error "Not implemented"
  end in
  Eio.traceln "%s" (Verbose.format record)

(* Example 5: Pretty Format with Icons *)
let example_icons () =
  Eio.traceln "\n=== Pretty Format with Icons ===\n";

  let module With_Icons : Flo_format_pretty.FORMATTER = struct
    let icon_for_severity = function
      | Severity.Trace -> "🔍"
      | Severity.Debug -> "🐛"
      | Severity.Info -> "ℹ️ "
      | Severity.Success -> "✅"
      | Severity.Warn -> "⚠️ "
      | Severity.Error -> "❌"
      | Severity.Fatal -> "💀"

    let format record =
      let icon = icon_for_severity record.Record.severity in
      let level = String.uppercase_ascii (Severity.to_string record.Record.severity) in
      Printf.sprintf "%s %-7s %s" icon level record.Record.message

    let parse _s = Error "Not implemented"
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Server started";
    Record.make ~severity:Severity.Success ~message:"Request completed";
    Record.make ~severity:Severity.Warn ~message:"High CPU usage";
    Record.make ~severity:Severity.Error ~message:"Connection failed";
  ] in

  List.iter (fun r -> Eio.traceln "%s" (With_Icons.format r)) records

(* Example 6: Minimal Pretty Format *)
let example_minimal () =
  Eio.traceln "\n=== Minimal Pretty Format ===\n";

  let module Minimal : Flo_format_pretty.FORMATTER = struct
    let format record =
      (* Just timestamp + message, nothing else *)
      let ts = Ptime.to_rfc3339 ~frac_s:0 (Record.get_timestamp record) in
      let time_only = String.sub ts 11 8 in  (* Extract HH:MM:SS *)
      Printf.sprintf "%s %s" time_only record.Record.message

    let parse _s = Error "Not implemented"
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"User logged in";
    Record.make ~severity:Severity.Info ~message:"Session created";
    Record.make ~severity:Severity.Info ~message:"Request processed";
  ] in

  List.iter (fun r -> Eio.traceln "%s" (Minimal.format r)) records;
  Eio.traceln "\nUse for: development, quick scanning, minimal clutter"

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║          Flō Pretty Console Output Examples                    ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_colored_default ();
  example_no_color ();
  example_custom_colors ();
  example_compact_vs_verbose ();
  example_icons ();
  example_minimal ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
