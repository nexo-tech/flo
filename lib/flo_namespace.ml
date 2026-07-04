(** Namespace registry implementation using a hash table with lock protection *)

(* Global registry: namespace -> level mapping *)
let registry : (string, Severity.t) Hashtbl.t = Hashtbl.create 16

let lock = Atomic.make false

let with_lock f =
  let rec acquire () =
    if Atomic.compare_and_set lock false true then ()
    else (
      Domain.cpu_relax ();
      acquire ())
  in
  acquire ();
  Fun.protect ~finally:(fun () -> Atomic.set lock false) f

(** Split namespace into hierarchical components.

    "a.b.c" becomes ["a.b.c"; "a.b"; "a"; ""]
*)
let namespace_hierarchy namespace =
  if namespace = "" then
    [""]
  else
    let parts = String.split_on_char '.' namespace in
    let rec build_hierarchy acc parts =
      match parts with
      | [] -> "" :: acc  (* Add root *)
      | _ ->
          let current = String.concat "." parts in
          build_hierarchy (current :: acc) (List.rev (List.tl (List.rev parts)))
    in
    List.rev (build_hierarchy [] parts)

(** Set level for a namespace *)
let set_level namespace level =
  with_lock (fun () ->
    Hashtbl.replace registry namespace level
  )

(** Get exact level for a namespace (no hierarchy lookup) *)
let get_level namespace =
  with_lock (fun () ->
    Hashtbl.find_opt registry namespace
  )

(** Get effective level with hierarchical lookup *)
let get_effective_level ~namespace ~root_level =
  with_lock (fun () ->
    let hierarchy = namespace_hierarchy namespace in
    let rec find_level = function
      | [] -> root_level
      | "" :: _ -> root_level  (* Reached root *)
      | ns :: rest ->
          match Hashtbl.find_opt registry ns with
          | Some level -> level
          | None -> find_level rest
    in
    find_level hierarchy
  )

(** Clear level for a namespace *)
let clear_level namespace =
  with_lock (fun () ->
    Hashtbl.remove registry namespace
  )

(** Get all configured levels *)
let get_all_levels () =
  with_lock (fun () ->
    Hashtbl.fold (fun ns level acc -> (ns, level) :: acc) registry []
  )

(** Clear all levels *)
let clear_all () =
  with_lock (fun () ->
    Hashtbl.clear registry
  )
