(** Namespace registry implementation using a hash table with mutex protection *)

(* Global registry: namespace -> level mapping *)
let registry : (string, Severity.t) Hashtbl.t = Hashtbl.create 16

(* Mutex for thread-safe access *)
let mutex = Eio.Mutex.create ()

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
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
    Hashtbl.replace registry namespace level
  )

(** Get exact level for a namespace (no hierarchy lookup) *)
let get_level namespace =
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
    Hashtbl.find_opt registry namespace
  )

(** Get effective level with hierarchical lookup *)
let get_effective_level ~namespace ~root_level =
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
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
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
    Hashtbl.remove registry namespace
  )

(** Get all configured levels *)
let get_all_levels () =
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
    Hashtbl.fold (fun ns level acc -> (ns, level) :: acc) registry []
  )

(** Clear all levels *)
let clear_all () =
  Eio.Mutex.use_rw ~protect:true mutex (fun () ->
    Hashtbl.clear registry
  )
