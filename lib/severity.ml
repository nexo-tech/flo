type t =
  | Trace
  | Debug
  | Info
  | Success
  | Warn
  | Error
  | Fatal

let to_string = function
  | Trace -> "trace"
  | Debug -> "debug"
  | Info -> "info"
  | Success -> "success"
  | Warn -> "warn"
  | Error -> "error"
  | Fatal -> "fatal"

let to_number = function
  | Trace -> 1    (* TRACE in OpenTelemetry *)
  | Debug -> 5    (* DEBUG in OpenTelemetry *)
  | Info -> 9     (* INFO in OpenTelemetry *)
  | Success -> 10 (* INFO2 in OpenTelemetry - between INFO and WARN *)
  | Warn -> 13    (* WARN in OpenTelemetry *)
  | Error -> 17   (* ERROR in OpenTelemetry *)
  | Fatal -> 21   (* FATAL in OpenTelemetry *)

let of_string s =
  match String.lowercase_ascii s with
  | "trace" -> Ok Trace
  | "debug" -> Ok Debug
  | "info" -> Ok Info
  | "success" -> Ok Success
  | "warn" | "warning" -> Ok Warn
  | "error" -> Ok Error
  | "fatal" | "critical" -> Ok Fatal
  | _ -> Error (Printf.sprintf "Invalid severity level: %s" s)

let compare a b =
  Int.compare (to_number a) (to_number b)
