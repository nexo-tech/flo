(* Context is a reference to an association list for mutability *)
type context = (string * Value.t) list ref

(* Create the Eio fiber key for context storage *)
let context_key : context Eio.Fiber.key = Eio.Fiber.create_key ()

(* Context operations *)
let empty = ref []

let add key value ctx =
  (* Remove existing key if present, then add new one *)
  let pairs = !ctx in
  let pairs' = List.filter (fun (k, _) -> k <> key) pairs in
  ctx := (key, value) :: pairs';
  ctx

let get key ctx =
  List.assoc_opt key !ctx

let merge ctx1 ctx2 =
  (* Start with ctx1, then add all pairs from ctx2 *)
  (* ctx2 takes precedence because add replaces existing keys *)
  let result = ref !ctx1 in
  List.iter (fun (key, value) ->
    let _ = add key value result in ()
  ) !ctx2;
  result

let to_list ctx = !ctx

let of_list pairs = ref pairs

(* Fiber-local storage *)
let with_context ctx f =
  try
    match Eio.Fiber.get context_key with
    | None ->
        (* No parent context, just bind the new context *)
        (* Make a copy to avoid mutation affecting parent *)
        let ctx_copy = ref !ctx in
        Eio.Fiber.with_binding context_key ctx_copy f
    | Some parent_ctx ->
        (* Merge with parent context (new context takes precedence) *)
        let merged = merge parent_ctx ctx in
        Eio.Fiber.with_binding context_key merged f
  with
  | Effect.Unhandled _ ->
      (* No Eio context is running, just execute the function *)
      (* Context features won't work, but at least the app runs *)
      f ()

let get_current () =
  try
    Eio.Fiber.get context_key
  with
  | Effect.Unhandled _ ->
      (* No Eio context is running, return None *)
      None

(* Convenience functions *)
let bind key value =
  (* Mutate the current context in place *)
  match get_current () with
  | None ->
      (* No context exists, create a new one and bind it *)
      (* But we can't bind it without a scope... this is still problematic *)
      (* For now, we'll ignore binds outside of a context *)
      ()
  | Some ctx ->
      (* Context exists as a mutable ref, so we can modify it *)
      let _ = add key value ctx in ()

let bind_all pairs =
  (* Mutate the current context in place *)
  match get_current () with
  | None ->
      ()
  | Some ctx ->
      List.iter (fun (key, value) ->
        let _ = add key value ctx in ()
      ) pairs

(* Namespace support *)
let namespace_key = "__flo_namespace__"

let get_namespace () =
  match get_current () with
  | None -> None
  | Some ctx ->
      match get namespace_key ctx with
      | Some (Value.String ns) -> Some ns
      | _ -> None

let set_namespace namespace =
  bind namespace_key (Value.String namespace)

let with_namespace namespace f =
  let ctx = add namespace_key (Value.String namespace) empty in
  with_context ctx f
