(** Async sink with background processing *)

type config = {
  buffer_capacity : int;
  batch_size : int;
  flush_interval : float;
  level : Severity.t;
}

type t = {
  config : config;
  stream : Record.t Eio.Stream.t;
  underlying : Flo_sink_file.rotating_sink;
  mutable total_written : int64;
  mutable total_dropped : int64;
  mutable running : bool;
}

(** Background fiber that processes queued records *)
let process_fiber sink clock =
  let rec collect_batch acc count =
    if count >= sink.config.batch_size then
      List.rev acc
    else
      match Eio.Stream.take_nonblocking sink.stream with
      | Some record -> collect_batch (record :: acc) (count + 1)
      | None -> List.rev acc
  in

  let last_flush = ref (Ptime_clock.now ()) in

  (* Main processing loop *)
  let rec loop () =
    if not sink.running then begin
      (* Stopped, drain and exit *)
      let rec drain_all () =
        match Eio.Stream.take_nonblocking sink.stream with
        | Some record ->
            Flo_sink_file.write_rotating sink.underlying record;
            sink.total_written <- Int64.succ sink.total_written;
            drain_all ()
        | None ->
            Flo_sink_file.flush_rotating sink.underlying
      in
      drain_all ()
    end else begin
      (* Small sleep to avoid busy-wait *)
      Eio.Time.sleep clock 0.01;  (* 10ms *)

      (* Check if we should flush based on interval *)
      let now = Ptime_clock.now () in
      let should_flush =
        match Ptime.Span.of_float_s sink.config.flush_interval with
        | Some interval ->
            (match Ptime.add_span !last_flush interval with
             | Some next_flush -> Ptime.is_later now ~than:next_flush
             | None -> false)
        | None -> false
      in

      (* Collect and write batch *)
      let batch = collect_batch [] 0 in
      if batch <> [] then begin
        List.iter (fun record ->
          Flo_sink_file.write_rotating sink.underlying record;
          sink.total_written <- Int64.succ sink.total_written
        ) batch;
        Flo_sink_file.flush_rotating sink.underlying;
        last_flush := now
      end else if should_flush then begin
        Flo_sink_file.flush_rotating sink.underlying;
        last_flush := now
      end;

      loop ()
    end
  in
  loop ()

let create ~sw ~env ~config ~underlying =
  let stream = Eio.Stream.create config.buffer_capacity in

  let sink = {
    config;
    stream;
    underlying;
    total_written = 0L;
    total_dropped = 0L;
    running = true;
  } in

  (* Start background processing fiber *)
  let clock = (env :> < clock : _ ; .. >)#clock in
  Eio.Fiber.fork ~sw (fun () ->
    try
      process_fiber sink clock
    with
    | Eio.Cancel.Cancelled _ ->
        (* Mark as not running and drain *)
        sink.running <- false;
        let rec drain_all () =
          match Eio.Stream.take_nonblocking sink.stream with
          | Some record ->
              Flo_sink_file.write_rotating sink.underlying record;
              sink.total_written <- Int64.succ sink.total_written;
              drain_all ()
          | None ->
              Flo_sink_file.flush_rotating sink.underlying
        in
        drain_all ()
    | exn ->
        sink.running <- false;
        raise exn
  );

  sink

let write sink record =
  if Severity.compare record.Record.severity sink.config.level >= 0 then
    try
      Eio.Stream.add sink.stream record
    with
    | _ ->
        (* Buffer full or other error, drop the record *)
        sink.total_dropped <- Int64.succ sink.total_dropped

let flush _sink =
  (* The background fiber handles flushing automatically *)
  ()

let permits sink record =
  Severity.compare record.Record.severity sink.config.level >= 0

let drain sink =
  (* Stop the background processing *)
  sink.running <- false;

  (* Wait longer for background fiber to finish processing *)
  Unix.sleepf 2.0;

  (* Drain any remaining records that weren't processed *)
  let rec drain_remaining () =
    match Eio.Stream.take_nonblocking sink.stream with
    | Some record ->
        Flo_sink_file.write_rotating sink.underlying record;
        sink.total_written <- Int64.succ sink.total_written;
        drain_remaining ()
    | None ->
        Flo_sink_file.flush_rotating sink.underlying
  in
  drain_remaining ()

let stats sink =
  let queued = Eio.Stream.length sink.stream in
  (queued, sink.total_written, sink.total_dropped)
