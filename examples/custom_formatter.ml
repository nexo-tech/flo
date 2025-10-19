(* Custom Formatter Examples
 *
 * This example demonstrates creating custom formatters for Flo logs.
 * Shows how to customize output format, colors, and field filtering.
 *)

(* Example 1: Custom Pretty Formatter with Custom Colors *)
let example_custom_colors () =
  Eio.traceln "\n=== Custom Color Pretty Formatter ===\n";

  (* Create a custom formatter with custom color scheme *)
  let module Custom_Pretty : Flo_format_pretty.FORMATTER = struct
    (* Override color scheme *)
    let color_for_severity = function
      | Severity.Trace -> "\027[2;35m"      (* dim magenta *)
      | Severity.Debug -> "\027[96m"        (* bright cyan *)
      | Severity.Info -> "\027[94m"         (* bright blue *)
      | Severity.Success -> "\027[1;32m"    (* bold green *)
      | Severity.Warn -> "\027[1;33m"       (* bold yellow *)
      | Severity.Error -> "\027[1;31m"      (* bold red *)
      | Severity.Fatal -> "\027[1;41;37m"   (* white on red background *)

    let format record =
      let ts = Ptime.to_rfc3339 ~frac_s:3 (Record.get_timestamp record) in
      let color = color_for_severity record.Record.severity in
      let severity_text = String.uppercase_ascii (Severity.to_string record.Record.severity) in
      let reset = "\027[0m" in

      Printf.sprintf "[%s] %s%-7s%s %s"
        ts color severity_text reset record.Record.message

    let parse _s = Error "Parsing not implemented"
  end in

  (* Use the custom formatter *)
  let record1 = Record.make ~severity:Severity.Info ~message:"Custom colored info" in
  let record2 = Record.make ~severity:Severity.Success ~message:"Custom colored success" in
  let record3 = Record.make ~severity:Severity.Error ~message:"Custom colored error" in

  Eio.traceln "%s" (Custom_Pretty.format record1);
  Eio.traceln "%s" (Custom_Pretty.format record2);
  Eio.traceln "%s" (Custom_Pretty.format record3)

(* Example 2: Custom JSON Formatter with Field Filtering *)
let example_json_with_filtering () =
  Eio.traceln "\n=== JSON Formatter with Field Filtering ===\n";

  let module Filtered_JSON : Flo_format_pretty.FORMATTER = struct
    (* Filter out sensitive fields before formatting *)
    let filter_sensitive_fields attrs =
      List.filter (fun (key, _) ->
        not (List.mem key ["password"; "secret"; "api_key"; "token"])
      ) attrs

    let format record =
      (* Filter attributes - need to create new record *)
      let filtered_attrs = filter_sensitive_fields record.Record.attributes in
      let filtered_record =
        Record.make ~severity:record.severity ~message:record.message
        |> fun r -> Record.with_attributes filtered_attrs r
        |> fun r -> match record.location with
          | Some loc -> Record.with_location loc r
          | None -> r
      in

      (* Use standard JSON formatter *)
      Flo_format_json.format filtered_record

    let parse s = Flo_format_json.parse s
  end in

  (* Test with sensitive fields *)
  let record = Record.make ~severity:Severity.Info ~message:"Login attempt" in
  let record = Record.with_attributes [
    ("user_id", Value.String "alice");
    ("password", Value.String "secret123");  (* Will be filtered out *)
    ("api_key", Value.String "sk-abc123");   (* Will be filtered out *)
    ("ip_address", Value.String "192.168.1.1");
  ] record in

  Eio.traceln "%s" (Filtered_JSON.format record);
  Eio.traceln "\nNote: password and api_key fields were filtered out"

(* Example 3: Custom Logfmt with Key Transformations *)
let example_logfmt_key_transform () =
  Eio.traceln "\n=== Logfmt with Key Transformations ===\n";

  let module Snake_Case_Logfmt : Flo_format_pretty.FORMATTER = struct
    (* Transform camelCase to snake_case *)
    let to_snake_case s =
      let buf = Buffer.create (String.length s + 5) in
      String.iteri (fun i c ->
        if i > 0 && c >= 'A' && c <= 'Z' then begin
          Buffer.add_char buf '_';
          Buffer.add_char buf (Char.lowercase_ascii c)
        end else
          Buffer.add_char buf c
      ) s;
      Buffer.contents buf

    let format record =
      (* Transform all attribute keys to snake_case *)
      let transformed_attrs = List.map (fun (k, v) ->
        (to_snake_case k, v)
      ) record.Record.attributes in

      let transformed_record =
        Record.make ~severity:record.severity ~message:record.message
        |> fun r -> Record.with_attributes transformed_attrs r
      in

      Flo_format_logfmt.format transformed_record

    let parse s = Flo_format_logfmt.parse s
  end in

  let record = Record.make ~severity:Severity.Info ~message:"Key transform test" in
  let record = Record.with_attributes [
    ("userId", Value.String "alice");
    ("orderCount", Value.Int 42L);
    ("totalAmount", Value.Float 99.99);
  ] record in

  Eio.traceln "Original keys (camelCase):";
  Eio.traceln "%s" (Flo_format_logfmt.format record);
  Eio.traceln "\nTransformed keys (snake_case):";
  Eio.traceln "%s" (Snake_Case_Logfmt.format record)

(* Example 4: Colored vs Non-Colored Output *)
let example_colored_output () =
  Eio.traceln "\n=== Colored vs Non-Colored Output ===\n";

  let record = Record.make ~severity:Severity.Success ~message:"Operation completed" in
  let record = Record.with_attributes [
    ("duration_ms", Value.Float 123.45);
    ("items_processed", Value.Int 1000L);
  ] record in

  Eio.traceln "Colored output (default):";
  Eio.traceln "%s" (Flo_format_pretty.format record);

  Eio.traceln "\nNon-colored output (for logs/CI):";
  (* Create plain formatter by stripping ANSI codes *)
  let plain = Flo_format_pretty.format record in
  let plain = Str.global_replace (Str.regexp "\027\\[[0-9;]*m") "" plain in
  Eio.traceln "%s" plain

(* Example 5: Custom Compact Formatter *)
let example_compact_formatter () =
  Eio.traceln "\n=== Custom Compact Formatter ===\n";

  let module Compact : Flo_format_pretty.FORMATTER = struct
    (* Ultra-compact format: LEVEL MESSAGE *)
    let format record =
      let level = String.uppercase_ascii (Severity.to_string record.Record.severity) in
      Printf.sprintf "%s %s" level record.Record.message

    let parse _s = Error "Parsing not implemented"
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"Server started";
    Record.make ~severity:Severity.Success ~message:"Request processed";
    Record.make ~severity:Severity.Warn ~message:"High memory usage";
  ] in

  List.iter (fun r ->
    Eio.traceln "%s" (Compact.format r)
  ) records

(* Example 6: Custom Detailed Formatter with All Fields *)
let example_detailed_formatter () =
  Eio.traceln "\n=== Custom Detailed Formatter (All Fields) ===\n";

  let module Detailed : Flo_format_pretty.FORMATTER = struct
    let format record =
      let buf = Buffer.create 256 in

      (* Header *)
      Buffer.add_string buf "╔═══════════════════════════════════════╗\n";

      (* Timestamp *)
      let ts = Ptime.to_rfc3339 ~frac_s:3 (Record.get_timestamp record) in
      Printf.bprintf buf "  Time: %s\n" ts;

      (* Severity *)
      Printf.bprintf buf "  Severity: %s (%d)\n"
        (Severity.to_string record.Record.severity)
        (Severity.to_number record.Record.severity);

      (* Message *)
      Printf.bprintf buf "  Message: %s\n" record.Record.message;

      (* Location *)
      (match record.Record.location with
       | Some loc ->
           Printf.bprintf buf "  Location: %s:%d:%d\n"
             loc.file loc.line loc.column;
           if loc.module_name <> "" then
             Printf.bprintf buf "  Module: %s\n" loc.module_name
       | None -> ());

      (* Span context *)
      (match record.Record.span_context with
       | Some ctx ->
           Printf.bprintf buf "  Trace ID: %s\n" ctx.trace_id;
           Printf.bprintf buf "  Span ID: %s\n" ctx.span_id
       | None -> ());

      (* Attributes *)
      if record.Record.attributes <> [] then begin
        Buffer.add_string buf "  Attributes:\n";
        List.iter (fun (k, v) ->
          Printf.bprintf buf "    - %s: %s\n" k (Value.to_string v)
        ) record.Record.attributes
      end;

      Buffer.add_string buf "╚═══════════════════════════════════════╝";
      Buffer.contents buf

    let parse _s = Error "Parsing not implemented"
  end in

  let record = Record.make ~severity:Severity.Info ~message:"Detailed log example" in
  let loc = Location.make_full ~file:"custom_formatter.ml" ~line:42 ~column:10
              ~module_name:"Custom_formatter" () in
  let record = Record.with_location loc record in
  let record = Record.with_attributes [
    ("user_id", Value.String "alice");
    ("action", Value.String "login");
    ("duration_ms", Value.Float 23.5);
  ] record in

  Eio.traceln "%s" (Detailed.format record)

(* Example 7: Custom Minimal Formatter (Errors Only) *)
let example_minimal_formatter () =
  Eio.traceln "\n=== Custom Minimal Formatter (Errors Only) ===\n";

  let module Minimal_Errors : Flo_format_pretty.FORMATTER = struct
    let format record =
      (* Only format errors and above, others are empty *)
      if Severity.compare record.Record.severity Severity.Error >= 0 then
        Printf.sprintf "⚠️  ERROR: %s" record.Record.message
      else
        ""  (* Don't output for lower severity *)

    let parse _s = Error "Parsing not implemented"
  end in

  let records = [
    Record.make ~severity:Severity.Info ~message:"This won't show";
    Record.make ~severity:Severity.Debug ~message:"This won't show either";
    Record.make ~severity:Severity.Error ~message:"This WILL show!";
    Record.make ~severity:Severity.Fatal ~message:"Critical error!";
  ] in

  List.iter (fun r ->
    let formatted = Minimal_Errors.format r in
    if formatted <> "" then Eio.traceln "%s" formatted
  ) records

(* Main *)
let main _env =
  Eio.traceln "╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║              Flō Custom Formatter Examples                     ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝";

  example_custom_colors ();
  example_json_with_filtering ();
  example_logfmt_key_transform ();
  example_colored_output ();
  example_compact_formatter ();
  example_detailed_formatter ();
  example_minimal_formatter ();

  Eio.traceln "\n╔════════════════════════════════════════════════════════════════╗";
  Eio.traceln "║                   All Examples Complete!                       ║";
  Eio.traceln "╚════════════════════════════════════════════════════════════════╝"

let () =
  Eio_main.run @@ fun env ->
    main env
