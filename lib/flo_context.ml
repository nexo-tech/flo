(* Context is a simple association list *)
type context = (string * Value.t) list

(* Create the Eio fiber key for context storage *)
let context_key : context Eio.Fiber.key = Eio.Fiber.create_key ()

(* Context operations *)
let empty = []

let add key value ctx =
  (* Remove existing key if present, then add new one *)
  let ctx' = List.filter (fun (k, _) -> k <> key) ctx in
  (key, value) :: ctx'

let get key ctx =
  List.assoc_opt key ctx

let merge ctx1 ctx2 =
  (* Start with ctx1, then add all pairs from ctx2 *)
  (* ctx2 takes precedence because add replaces existing keys *)
  List.fold_left (fun acc (key, value) ->
    add key value acc
  ) ctx1 ctx2

let to_list ctx = ctx

let of_list pairs = pairs

(* Fiber-local storage *)
let with_context ctx f =
  match Eio.Fiber.get context_key with
  | None ->
      (* No parent context, just bind the new context *)
      Eio.Fiber.with_binding context_key ctx f
  | Some parent_ctx ->
      (* Merge with parent context (new context takes precedence) *)
      let merged = merge parent_ctx ctx in
      Eio.Fiber.with_binding context_key merged f

let get_current () =
  Eio.Fiber.get context_key

(* Convenience functions *)
let bind _key _value =
  (* Note: Due to Eio's immutable fiber-local storage, bind cannot modify
     the context in place. This function is provided for API compatibility
     but has no effect. Use with_context to set context. *)
  ()

let bind_all _pairs =
  (* Note: Due to Eio's immutable fiber-local storage, bind_all cannot modify
     the context in place. This function is provided for API compatibility
     but has no effect. Use with_context to set context. *)
  ()
