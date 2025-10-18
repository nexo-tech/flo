type ('m, 'msg) t = 'msg -> 'm

(* Construction *)
let make f = f

let noop = fun _ -> ()

(* Contravariant operations *)
let contramap f logger = fun msg -> logger (f msg)

let (>$<) = contramap

(* Composition *)
let combine logger1 logger2 = fun msg ->
  logger1 msg;
  logger2 msg

let (<>) = combine

let combine_all loggers = fun msg ->
  List.iter (fun logger -> logger msg) loggers

(* Filtering *)
let filter predicate logger = fun msg ->
  if predicate msg then logger msg else ()

let level_filter min_level logger = fun record ->
  if Severity.compare record.Record.severity min_level >= 0 then
    logger record
  else
    ()

(* Application *)
let log logger msg = logger msg

let (<&) = log
