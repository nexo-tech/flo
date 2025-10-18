(** File sinks with rotation and retention *)

(** Rotation strategies *)
type rotation =
  | Size of int64
  | Daily of int * int
  | Interval of float

(** Retention policies *)
type retention =
  | Keep_last of int
  | Keep_duration of float
  | Custom of (Eio.Fs.dir_ty Eio.Path.t list -> Eio.Fs.dir_ty Eio.Path.t list)

(** {1 Basic File Sink} *)

type basic_config = {
  path : Eio.Fs.dir_ty Eio.Path.t;
  format : [ `Json | `Logfmt ];
  level : Severity.t;
  buffer_size : int;
  create_dirs : bool;
}

type basic_sink = {
  config : basic_config;
  buffer : Buffer.t;
  mutex : Eio.Mutex.t;
}

let create_basic ~sw:_ config =
  (* Create parent directories if needed *)
  if config.create_dirs then begin
    let (dir, filename) = config.path in
    (* Extract directory parts from filename *)
    let parts = String.split_on_char '/' filename in
    if List.length parts > 1 then begin
      let dir_parts = List.rev (List.tl (List.rev parts)) in
      let dir_path = String.concat "/" dir_parts in
      if dir_path <> "" then
        try
          Eio.Path.mkdirs (dir, dir_path) ~perm:0o755
        with _ -> ()
    end
  end;

  let buffer_size = if config.buffer_size > 0 then config.buffer_size else 1024 in

  {
    config;
    buffer = Buffer.create buffer_size;
    mutex = Eio.Mutex.create ();
  }

let write_basic sink record =
  if Severity.compare record.Record.severity sink.config.level >= 0 then
    Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
      (* Format the record *)
      let formatted = match sink.config.format with
        | `Json -> Flo_format_json.format record
        | `Logfmt -> Flo_format_logfmt.format record
      in
      let line = formatted ^ "\n" in

      (* Add to buffer *)
      Buffer.add_string sink.buffer line;

      (* Flush if buffer is full or unbuffered mode *)
      if Buffer.length sink.buffer >= sink.config.buffer_size then begin
        Eio.Path.save ~append:true ~create:(`Or_truncate 0o644)
          sink.config.path (Buffer.contents sink.buffer);
        Buffer.clear sink.buffer
      end
    )

let flush_basic sink =
  Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
    if Buffer.length sink.buffer > 0 then begin
      Eio.Path.save ~append:true ~create:(`Or_truncate 0o644)
        sink.config.path (Buffer.contents sink.buffer);
      Buffer.clear sink.buffer
    end
  )

let permits_basic sink record =
  Severity.compare record.Record.severity sink.config.level >= 0

(** {1 Rotating File Sink} *)

type rotating_config = {
  path : Eio.Fs.dir_ty Eio.Path.t;
  format : [ `Json | `Logfmt ];
  rotation : rotation;
  retention : retention option;
  level : Severity.t;
  buffer_size : int;
  create_dirs : bool;
}

type rotating_sink = {
  config : rotating_config;
  _sw : Eio.Switch.t;
  mutable current_size : int64;
  mutable last_rotation : Ptime.t;
  buffer : Buffer.t;
  mutex : Eio.Mutex.t;
}

(** Get file size *)
let file_size _fs path =
  try
    let stat = Eio.Path.stat ~follow:true path in
    Optint.Int63.to_int64 stat.Eio.File.Stat.size
  with _ -> 0L

(** Generate rotated filename with timestamp *)
let rotated_filename base_path timestamp =
  let ts_str = Ptime.to_rfc3339 ~tz_offset_s:0 timestamp in
  (* Replace colons with hyphens for filesystem compatibility *)
  let ts_str = String.map (fun c -> if c = ':' then '-' else c) ts_str in
  Printf.sprintf "%s.%s" base_path ts_str

(** Apply retention policy to delete old files *)
let apply_retention config =
  match config.retention with
  | None -> ()
  | Some retention_policy ->
      try
        (* Get list of rotated log files *)
        let (dir_path, base) = config.path in
        let entries = Eio.Path.read_dir (dir_path, ".") in

        (* Filter to only files matching our base name pattern *)
        let log_files = List.filter (fun name ->
          String.starts_with ~prefix:base name && name <> base
        ) entries in

        (* Sort by modification time (newest first) *)
        let sorted_files = List.sort (fun a b ->
          let stat_a = Eio.Path.stat ~follow:true (dir_path, a) in
          let stat_b = Eio.Path.stat ~follow:true (dir_path, b) in
          Float.compare stat_b.Eio.File.Stat.mtime stat_a.Eio.File.Stat.mtime
        ) log_files in

        (* Apply retention policy *)
        let files_to_delete = match retention_policy with
          | Keep_last n ->
              (* Keep first n files, delete the rest *)
              if List.length sorted_files > n then
                List.filteri (fun i _ -> i >= n) sorted_files
              else
                []
          | Keep_duration seconds ->
              (* Keep files within duration, delete older *)
              let now = Ptime_clock.now () in
              let cutoff = Ptime.Span.of_float_s seconds |> Option.get in
              List.filter (fun name ->
                let stat = Eio.Path.stat ~follow:true (dir_path, name) in
                let file_time = Ptime.of_float_s stat.Eio.File.Stat.mtime |> Option.get in
                match Ptime.sub_span now cutoff with
                | Some cutoff_time -> Ptime.is_earlier file_time ~than:cutoff_time
                | None -> false
              ) sorted_files
          | Custom filter_fn ->
              let paths = List.map (fun name -> (dir_path, name)) sorted_files in
              let to_keep = filter_fn paths in
              List.filter (fun name ->
                not (List.mem (dir_path, name) to_keep)
              ) sorted_files
        in

        (* Delete files *)
        List.iter (fun name ->
          try
            Eio.Path.unlink (dir_path, name)
          with _ -> ()
        ) files_to_delete
      with _ -> ()

(** Perform file rotation *)
let do_rotation sink =
  (* Flush any buffered data *)
  if Buffer.length sink.buffer > 0 then begin
    Eio.Path.save ~append:true ~create:(`Or_truncate 0o644)
      sink.config.path (Buffer.contents sink.buffer);
    Buffer.clear sink.buffer
  end;

  (* Generate new filename with timestamp *)
  let (dir, base) = sink.config.path in
  let now = Ptime_clock.now () in
  let rotated_name = rotated_filename base now in

  (* Rename current file to rotated name *)
  (try
     Eio.Path.rename sink.config.path (dir, rotated_name)
   with _ -> ());

  (* Apply retention policy *)
  apply_retention sink.config;

  (* Reset size and update last rotation time *)
  sink.current_size <- 0L;
  sink.last_rotation <- now

(** Check if rotation is needed *)
let needs_rotation sink =
  match sink.config.rotation with
  | Size max_size ->
      sink.current_size >= max_size
  | Daily (hour, minute) ->
      let now = Ptime_clock.now () in
      let ((year, month, day), _) = Ptime.to_date_time now in
      let today_rotation = Ptime.of_date_time ((year, month, day), ((hour, minute, 0), 0)) in
      (match today_rotation with
       | Some rotation_time ->
           Ptime.is_later now ~than:rotation_time &&
           Ptime.is_earlier sink.last_rotation ~than:rotation_time
       | None -> false)
  | Interval seconds ->
      let now = Ptime_clock.now () in
      match Ptime.Span.of_float_s seconds with
      | Some interval ->
          (match Ptime.add_span sink.last_rotation interval with
           | Some next_rotation -> Ptime.is_later now ~than:next_rotation
           | None -> false)
      | None -> false

let create_rotating ~sw config =
  (* Create parent directories if needed *)
  if config.create_dirs then begin
    let (dir, filename) = config.path in
    let parts = String.split_on_char '/' filename in
    if List.length parts > 1 then begin
      let dir_parts = List.rev (List.tl (List.rev parts)) in
      let dir_path = String.concat "/" dir_parts in
      if dir_path <> "" then
        try
          Eio.Path.mkdirs (dir, dir_path) ~perm:0o755
        with _ -> ()
    end
  end;

  (* Get current file size *)
  let current_size = file_size (fst config.path) config.path in

  (* Create buffer *)
  let buffer_size = if config.buffer_size > 0 then config.buffer_size else 1024 in

  {
    config;
    _sw = sw;
    current_size;
    last_rotation = Ptime_clock.now ();
    buffer = Buffer.create buffer_size;
    mutex = Eio.Mutex.create ();
  }

let write_rotating sink record =
  if Severity.compare record.Record.severity sink.config.level >= 0 then
    Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
      (* Check if rotation is needed *)
      if needs_rotation sink then
        do_rotation sink;

      (* Format the record *)
      let formatted = match sink.config.format with
        | `Json -> Flo_format_json.format record
        | `Logfmt -> Flo_format_logfmt.format record
      in
      let line = formatted ^ "\n" in
      let line_size = Int64.of_int (String.length line) in

      (* Add to buffer *)
      Buffer.add_string sink.buffer line;
      sink.current_size <- Int64.add sink.current_size line_size;

      (* Flush if buffer is full *)
      if Buffer.length sink.buffer >= sink.config.buffer_size then begin
        Eio.Path.save ~append:true ~create:(`Or_truncate 0o644)
          sink.config.path (Buffer.contents sink.buffer);
        Buffer.clear sink.buffer
      end
    )

let flush_rotating sink =
  Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
    if Buffer.length sink.buffer > 0 then begin
      Eio.Path.save ~append:true ~create:(`Or_truncate 0o644)
        sink.config.path (Buffer.contents sink.buffer);
      Buffer.clear sink.buffer
    end
  )

let permits_rotating sink record =
  Severity.compare record.Record.severity sink.config.level >= 0

let rotate sink =
  Eio.Mutex.use_rw ~protect:true sink.mutex (fun () ->
    do_rotation sink
  )
