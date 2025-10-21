module type FORMATTER = sig
  val format : Record.t -> string
  val parse : string -> (Record.t, string) result
end

(* ANSI color codes *)
let reset = "\027[0m"
let bold = "\027[1m"
let dim = "\027[2m"

let black = "\027[30m"
let red = "\027[31m"
let green = "\027[32m"
let yellow = "\027[33m"
let blue = "\027[34m"
let magenta = "\027[35m"
let cyan = "\027[36m"
let white = "\027[37m"
let gray = "\027[2;37m"  (* dim white *)

let bright_red = "\027[91m"
let bright_green = "\027[92m"
let bright_yellow = "\027[93m"
let bright_blue = "\027[94m"
let bright_magenta = "\027[95m"
let bright_cyan = "\027[96m"
let bright_white = "\027[97m"

let color_for_severity = function
  | Severity.Trace -> gray              (* dim gray *)
  | Severity.Debug -> cyan              (* cyan *)
  | Severity.Info -> blue               (* blue *)
  | Severity.Success -> green           (* green - Loguru-style *)
  | Severity.Warn -> yellow             (* yellow *)
  | Severity.Error -> red               (* red *)
  | Severity.Fatal -> bold ^ red        (* bold red *)

(* Format severity with padding *)
let format_severity_colored severity =
  let color = color_for_severity severity in
  let text = String.uppercase_ascii (Severity.to_string severity) in
  let padded = Printf.sprintf "%-7s" text in  (* 7 chars for "SUCCESS" *)
  Printf.sprintf "%s%s%s" color padded reset

let format_severity_plain severity =
  let text = String.uppercase_ascii (Severity.to_string severity) in
  Printf.sprintf "%-7s" text

(* Format timestamp as YYYY-MM-DD HH:MM:SS.mmm *)
let format_timestamp ts =
  let (year, month, day), ((hour, min, sec), _tz_offset) =
    Ptime.to_date_time ts
  in
  (* Get milliseconds from fractional seconds *)
  let span = Ptime.to_span ts in
  let frac = Ptime.Span.to_float_s span in
  let ms = int_of_float (frac *. 1000.0) mod 1000 in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d.%03d"
    year month day hour min sec ms

(* Format location *)
let format_location loc =
  let s = Location.to_string loc in
  if s = "<unknown>" then "" else Printf.sprintf " (%s)" s

(* Format attributes *)
let format_attributes attrs =
  if attrs = [] then ""
  else
    let pairs = List.map (fun (k, v) ->
      Printf.sprintf "%s=%s" k (Value.to_string v)
    ) attrs in
    Printf.sprintf " {%s}" (String.concat ", " pairs)

(* Format span context *)
let format_span_context ctx =
  Printf.sprintf " trace_id=%s span_id=%s"
    ctx.Trace_context.trace_id
    ctx.Trace_context.span_id

(* Format event name *)
let format_event_name name =
  Printf.sprintf " event=%s" name

(* Format namespace *)
let format_namespace_colored namespace =
  Printf.sprintf "%s[%s]%s" magenta namespace reset

let format_namespace_plain namespace =
  Printf.sprintf "[%s]" namespace

(* Main formatter implementation *)
let make_formatter colorize =
  let module F = struct
    let format record =
      let ts_str = format_timestamp (Record.get_timestamp record) in
      let severity_str =
        if colorize then
          format_severity_colored record.severity
        else
          format_severity_plain record.severity
      in
      let namespace_str = match record.namespace with
        | Some ns ->
            if colorize then
              " " ^ format_namespace_colored ns
            else
              " " ^ format_namespace_plain ns
        | None -> ""
      in
      let loc_str = match record.location with
        | Some loc -> format_location loc
        | None -> ""
      in
      let event_str = match record.event_name with
        | Some name -> format_event_name name
        | None -> ""
      in
      let attrs_str = format_attributes record.attributes in
      let trace_str = match record.span_context with
        | Some ctx -> format_span_context ctx
        | None -> ""
      in

      (* Format: [TIMESTAMP] [LEVEL] [namespace] message (location) event=... {attrs...} trace_id=... *)
      Printf.sprintf "[%s] [%s]%s %s%s%s%s%s"
        ts_str severity_str namespace_str record.message loc_str event_str attrs_str trace_str

    let parse _s =
      Error "Parsing is not supported for pretty format (lossy format)"
  end in
  (module F : FORMATTER)

(* Default implementation with colors *)
include (val make_formatter true : FORMATTER)

(* with_colors factory *)
let with_colors colorize = make_formatter colorize
