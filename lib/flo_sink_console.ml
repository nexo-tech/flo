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
      (* Use standard OCaml output functions for console *)
      match sink.output_type with
      | `Stderr ->
          output_string stderr formatted;
          output_char stderr '\n';
          flush stderr
      | `Stdout ->
          output_string stdout formatted;
          output_char stdout '\n';
          flush stdout
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
