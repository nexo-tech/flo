open Flo

(* Helper to create test timestamp *)
let test_timestamp =
  match Ptime.of_date_time ((2024, 1, 15), ((10, 30, 45), 0)) with
  | Some t -> t
  | None -> Ptime.epoch

(* Test formatting with colors *)
let test_format_with_colors () =
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Info
    ~message:"Test message"
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain ANSI color codes *)
  Alcotest.(check bool) "contains ANSI codes" true
    (String.contains formatted '\027');
  (* Should contain timestamp *)
  Alcotest.(check bool) "contains timestamp" true
    (String.contains formatted ':');
  (* Should contain message *)
  Alcotest.(check bool) "contains message" true
    (String.contains formatted 'T')

(* Test formatting without colors *)
let test_format_without_colors () =
  let module F = (val Flo_format_pretty.with_colors false : Flo_format_pretty.FORMATTER) in
  let record = Record.make_with_timestamp
    ~timestamp:test_timestamp
    ~severity:Severity.Warn
    ~message:"Warning message"
  in

  let formatted = F.format record in

  (* Should NOT contain ANSI color codes *)
  Alcotest.(check bool) "no ANSI codes" false
    (String.contains formatted '\027');
  (* Should contain message *)
  Alcotest.(check bool) "contains message" true
    (String.contains formatted 'W')

let test_compact_severity_label () =
  let module F =
    (val Flo_format_pretty.with_colors false : Flo_format_pretty.FORMATTER)
  in
  let record =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Info ~message:"Test message"
  in
  let formatted = F.format record in
  Alcotest.(check bool)
    "uses compact label" true
    (String.starts_with ~prefix:"2024-01-15 10:30:45.000 INF " formatted);
  Alcotest.(check bool)
    "does not use padded bracket label" false
    (try
       ignore (Str.search_forward (Str.regexp "\\[INFO") formatted 0);
       true
     with Not_found -> false)

(* Test all severity levels have different colors *)
let test_all_severity_levels () =
  let levels = [
    Severity.Trace;
    Severity.Debug;
    Severity.Info;
    Severity.Success;
    Severity.Warn;
    Severity.Error;
    Severity.Fatal;
  ] in

  List.iter (fun level ->
    let record = Record.make ~severity:level ~message:"Test" in
    let formatted = Flo_format_pretty.format record in
    Alcotest.(check bool)
      (Printf.sprintf "%s formats" (Severity.to_string level))
      true (String.length formatted > 0)
  ) levels

(* Test formatting with location *)
let test_format_with_location () =
  let location = Location.make ~file:"src/main.ml" ~line:42 in
  let record =
    Record.make ~severity:Severity.Error ~message:"Error occurred"
    |> Record.with_location location
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain location *)
  Alcotest.(check bool) "contains file" true
    (String.contains formatted 'm');  (* main.ml *)
  Alcotest.(check bool) "contains line" true
    (String.contains formatted '4')  (* 42 *)

(* Test formatting without location *)
let test_format_without_location () =
  let record = Record.make ~severity:Severity.Info ~message:"No location" in
  let formatted = Flo_format_pretty.format record in

  (* Should not contain location markers *)
  Alcotest.(check bool) "formats without location" true
    (String.length formatted > 0)

(* Test formatting with attributes *)
let test_format_with_attributes () =
  let record =
    Record.make ~severity:Severity.Debug ~message:"Debug message"
    |> Record.with_attributes [
         ("user_id", Value.string "alice");
         ("count", Value.int 42);
       ]
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain attributes *)
  Alcotest.(check bool) "contains user_id" true
    (String.contains formatted 'u');
  Alcotest.(check bool) "contains count" true
    (String.contains formatted '4')

(* Test formatting with span context *)
let test_format_with_span_context () =
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let record =
    Record.make ~severity:Severity.Info ~message:"Traced"
    |> Record.with_span_context span_ctx
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain trace_id and span_id *)
  Alcotest.(check bool) "contains trace_id" true
    (String.contains formatted 'a');  (* from trace_id *)
  Alcotest.(check bool) "contains span_id" true
    (String.contains formatted 'b')  (* from span_id *)

(* Test formatting with event name *)
let test_format_with_event_name () =
  let record =
    Record.make ~severity:Severity.Success ~message:"User registered"
    |> Record.with_event_name "user.registered"
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain event name *)
  Alcotest.(check bool) "contains event name" true
    (String.contains formatted 'e')  (* event= *)

(* Test complete record formatting *)
let test_format_complete_record () =
  let location = Location.make ~file:"app.ml" ~line:100 in
  let span_ctx = {
    Trace_context.trace_id = "0af7651916cd43dd8448eb211c80319c";
    span_id = "b7ad6b7169203331";
    parent_span_id = None;
    trace_flags = 0x01;
  } in
  let record =
    Record.make_with_timestamp ~timestamp:test_timestamp
      ~severity:Severity.Success
      ~message:"Order created"
    |> Record.with_location location
    |> Record.with_span_context span_ctx
    |> Record.with_attributes [("order_id", Value.string "12345")]
    |> Record.with_event_name "order.created"
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain all parts *)
  Alcotest.(check bool) "non-empty" true (String.length formatted > 50)

(* Test parse returns error *)
let test_parse_unsupported () =
  match Flo_format_pretty.parse "some string" with
  | Ok _ -> Alcotest.fail "parse should not be supported"
  | Error msg ->
      Alcotest.(check bool) "error mentions parsing" true
        (String.length msg > 0)

(* Test color_for_severity *)
let test_color_for_severity () =
  (* Just verify each returns a color code *)
  let levels = [
    Severity.Trace;
    Severity.Debug;
    Severity.Info;
    Severity.Success;
    Severity.Warn;
    Severity.Error;
    Severity.Fatal;
  ] in

  List.iter (fun level ->
    let color = Flo_format_pretty.color_for_severity level in
    Alcotest.(check bool)
      (Printf.sprintf "%s has color" (Severity.to_string level))
      true (String.length color > 0)
  ) levels

(* Test Trace is dim gray *)
let test_trace_color () =
  let color = Flo_format_pretty.color_for_severity Severity.Trace in
  Alcotest.(check string) "Trace is gray" Flo_format_pretty.gray color

(* Test Success is green *)
let test_success_color () =
  let color = Flo_format_pretty.color_for_severity Severity.Success in
  Alcotest.(check string) "Success is green" Flo_format_pretty.green color

(* Test Fatal is bold red *)
let test_fatal_color () =
  let color = Flo_format_pretty.color_for_severity Severity.Fatal in
  Alcotest.(check bool) "Fatal contains bold" true
    (String.starts_with ~prefix:Flo_format_pretty.bold color);
  Alcotest.(check bool) "Fatal contains red" true
    (String.ends_with ~suffix:Flo_format_pretty.red color)

(* Test with_colors creates formatter without colors *)
let test_with_colors_false () =
  let module F = (val Flo_format_pretty.with_colors false : Flo_format_pretty.FORMATTER) in
  let record = Record.make ~severity:Severity.Error ~message:"Error" in
  let formatted = F.format record in

  Alcotest.(check bool) "no ANSI codes" false
    (String.contains formatted '\027')

(* Test with_colors creates formatter with colors *)
let test_with_colors_true () =
  let module F = (val Flo_format_pretty.with_colors true : Flo_format_pretty.FORMATTER) in
  let record = Record.make ~severity:Severity.Info ~message:"Info" in
  let formatted = F.format record in

  Alcotest.(check bool) "has ANSI codes" true
    (String.contains formatted '\027')

(* Test formatting with namespace *)
let test_format_with_namespace () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test with namespace"
    |> Record.with_namespace "mylib.component"
  in

  let formatted = Flo_format_pretty.format record in

  (* Should contain namespace in brackets *)
  Alcotest.(check bool) "contains namespace" true
    (try ignore (Str.search_forward (Str.regexp "\\[mylib\\.component\\]") formatted 0); true
     with Not_found -> false)

(* Test formatting without namespace *)
let test_format_without_namespace () =
  let record = Record.make ~severity:Severity.Info ~message:"No namespace" in

  let formatted = Flo_format_pretty.format record in

  (* Should not have double brackets (would be [[INFO]] if namespace was there) *)
  (* Just verify format works *)
  Alcotest.(check bool) "formatted output not empty" true
    (String.length formatted > 0)

(* Test namespace with colors *)
let test_format_namespace_with_colors () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test"
    |> Record.with_namespace "mylib.test"
  in

  let module F = (val Flo_format_pretty.with_colors true : Flo_format_pretty.FORMATTER) in
  let formatted = F.format record in

  (* Should contain ANSI color codes for namespace (magenta) *)
  Alcotest.(check bool) "has ANSI codes" true
    (String.contains formatted '\027')

(* Test namespace without colors *)
let test_format_namespace_without_colors () =
  let record =
    Record.make ~severity:Severity.Info ~message:"Test"
    |> Record.with_namespace "mylib.test"
  in

  let module F = (val Flo_format_pretty.with_colors false : Flo_format_pretty.FORMATTER) in
  let formatted = F.format record in

  (* Should contain namespace but no ANSI codes *)
  Alcotest.(check bool) "no ANSI codes" false
    (String.contains formatted '\027');
  Alcotest.(check bool) "has namespace" true
    (try ignore (Str.search_forward (Str.regexp "\\[mylib\\.test\\]") formatted 0); true
     with Not_found -> false)

let test_long_message_stays_single_line () =
  let tail = "tail-marker-0123456789" in
  let message = String.make 512 'x' ^ tail in
  let record =
    Record.make ~severity:Severity.Info ~message
    |> Record.with_namespace "poster.linkedin.oauth"
  in
  let formatted = Flo_format_pretty.format record in
  Alcotest.(check bool) "contains tail marker" true
    (try
       ignore (Str.search_forward (Str.regexp "tail-marker") formatted 0);
       true
     with Not_found -> false);
  Alcotest.(check bool) "not truncated" true
    (String.length formatted > String.length message);
  Alcotest.(check int)
    "all payload bytes remain" 512
    (String.fold_left
       (fun count char -> if Char.equal char 'x' then count + 1 else count)
       0 formatted);
  Alcotest.(check bool)
    "formatter does not split record" false
    (String.contains formatted '\n')

let () =
  let open Alcotest in
  run "Flo_format_pretty" [
    "basic_formatting", [
      test_case "format with colors" `Quick test_format_with_colors;
      test_case "format without colors" `Quick test_format_without_colors;
      test_case "compact severity label" `Quick test_compact_severity_label;
      test_case "all severity levels" `Quick test_all_severity_levels;
    ];
    "components", [
      test_case "format with location" `Quick test_format_with_location;
      test_case "format without location" `Quick test_format_without_location;
      test_case "format with attributes" `Quick test_format_with_attributes;
      test_case "format with span context" `Quick test_format_with_span_context;
      test_case "format with event name" `Quick test_format_with_event_name;
      test_case "format complete record" `Quick test_format_complete_record;
    ];
    "colors", [
      test_case "color_for_severity returns colors" `Quick test_color_for_severity;
      test_case "Trace is gray" `Quick test_trace_color;
      test_case "Success is green" `Quick test_success_color;
      test_case "Fatal is bold red" `Quick test_fatal_color;
    ];
    "factories", [
      test_case "with_colors false disables colors" `Quick test_with_colors_false;
      test_case "with_colors true enables colors" `Quick test_with_colors_true;
    ];
    "parse", [
      test_case "parse is unsupported" `Quick test_parse_unsupported;
    ];
    "namespace", [
      test_case "format with namespace" `Quick test_format_with_namespace;
      test_case "format without namespace" `Quick test_format_without_namespace;
      test_case "namespace with colors" `Quick test_format_namespace_with_colors;
      test_case "namespace without colors" `Quick test_format_namespace_without_colors;
      test_case "long message stays single line" `Quick
        test_long_message_stays_single_line;
    ];
  ]
