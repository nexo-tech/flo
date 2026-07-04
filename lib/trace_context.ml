type span_context = {
  trace_id : string;
  span_id : string;
  parent_span_id : string option;
  trace_flags : int;
}

let rng_initialized = lazy (Mirage_crypto_rng_unix.use_default ())

(* Helper: Generate random hex string of given length *)
let random_hex_string len =
  Lazy.force rng_initialized;
  let bytes = Mirage_crypto_rng.generate (len / 2) in
  let buf = Buffer.create len in
  for i = 0 to String.length bytes - 1 do
    Printf.bprintf buf "%02x" (Char.code bytes.[i])
  done;
  Buffer.contents buf

(* Helper: Check if string is all zeros *)
let is_all_zeros s = String.for_all (fun c -> c = '0') s

let generate_trace_id () =
  let rec gen () =
    let id = random_hex_string 32 in
    if is_all_zeros id then gen () else id
  in
  gen ()

let generate_span_id () =
  let rec gen () =
    let id = random_hex_string 16 in
    if is_all_zeros id then gen () else id
  in
  gen ()

let create_child parent =
  {
    trace_id = parent.trace_id;
    span_id = generate_span_id ();
    parent_span_id = Some parent.span_id;
    trace_flags = parent.trace_flags;
  }

(* Validation *)
let is_valid_hex_string s =
  String.for_all
    (fun c ->
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
    s

let is_valid_trace_id trace_id =
  String.length trace_id = 32
  && is_valid_hex_string trace_id
  && not (is_all_zeros trace_id)

let is_valid_span_id span_id =
  String.length span_id = 16
  && is_valid_hex_string span_id
  && not (is_all_zeros span_id)

(* W3C traceparent parsing and formatting *)
let parse_traceparent header =
  match String.split_on_char '-' header with
  | [ version; trace_id; span_id; flags ] ->
      (* Validate version *)
      if version <> "00" then
        Error (Printf.sprintf "Invalid version: %s (expected 00)" version)
        (* Validate trace_id *)
      else if not (is_valid_trace_id trace_id) then
        Error
          (Printf.sprintf
             "Invalid trace_id: %s (must be 32 hex chars, not all zeros)"
             trace_id) (* Validate span_id *)
      else if not (is_valid_span_id span_id) then
        Error
          (Printf.sprintf
             "Invalid span_id: %s (must be 16 hex chars, not all zeros)" span_id)
        (* Validate flags *)
      else if String.length flags <> 2 || not (is_valid_hex_string flags) then
        Error (Printf.sprintf "Invalid flags: %s (must be 2 hex chars)" flags)
      else
        let trace_flags = int_of_string ("0x" ^ flags) in
        Ok
          {
            trace_id = String.lowercase_ascii trace_id;
            span_id = String.lowercase_ascii span_id;
            parent_span_id = None;
            trace_flags;
          }
  | _ ->
      Error
        "Invalid traceparent format (expected: 00-{trace_id}-{span_id}-{flags})"

let format_traceparent ctx =
  Printf.sprintf "00-%s-%s-%02x"
    (String.lowercase_ascii ctx.trace_id)
    (String.lowercase_ascii ctx.span_id)
    ctx.trace_flags

(* Trace flags operations *)
let is_sampled flags = flags land 0x01 <> 0
let set_sampled flags = flags lor 0x01
let clear_sampled flags = flags land lnot 0x01
