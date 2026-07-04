module type SINK = sig
  type t
  type config

  val create : sw:Eio.Switch.t -> config -> t
  val write : t -> Record.t -> unit
  val flush : t -> unit
  val permits : t -> Record.t -> bool
end

type config = {
  output : [ `Stderr | `Stdout ];
  colorize : bool;
  format : [ `Pretty | `Json | `Logfmt ];
  level : Severity.t;
}

type t = {
  output_type : [ `Stderr | `Stdout ];
  formatter : (module Flo_format_pretty.FORMATTER);
  level : Severity.t;
  mutex : Eio.Mutex.t;
}

let write_line fd line =
  let payload = line ^ "\n" in
  let length = String.length payload in
  let rec write_from offset =
    if offset < length then
      match Unix.write_substring fd payload offset (length - offset) with
      | 0 -> ()
      | written -> write_from (offset + written)
      | exception Unix.Unix_error (Unix.EINTR, _, _) -> write_from offset
  in
  write_from 0

let create ~sw:_ config =
  let formatter = match config.format with
    | `Pretty -> Flo_format_pretty.with_colors config.colorize
    | `Json ->
        (* JSON formatter not yet implemented, use Pretty for now *)
        Flo_format_pretty.with_colors false
    | `Logfmt ->
        (* Logfmt formatter not yet implemented, use Pretty for now *)
        Flo_format_pretty.with_colors false
  in
  let mutex = Eio.Mutex.create () in
  { output_type = config.output; formatter; level = config.level; mutex }

let permits sink record =
  Severity.compare record.Record.severity sink.level >= 0

let write sink record =
  if permits sink record then
    let module F = (val sink.formatter : Flo_format_pretty.FORMATTER) in
    let formatted = F.format record in
    Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
      match sink.output_type with
      | `Stderr -> write_line Unix.stderr formatted
      | `Stdout -> write_line Unix.stdout formatted
    )

let flush _sink =
  (* Console output is unbuffered, no flush needed *)
  ()

let default_config = {
  output = `Stderr;
  colorize = true;
  format = `Pretty;
  level = Severity.Info;
}

let stderr ~sw =
  create ~sw { default_config with output = `Stderr }

let stdout ~sw =
  create ~sw { default_config with output = `Stdout }
