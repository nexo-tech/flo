(* PPX Runtime Support - Type-directed conversion helpers
 *
 * This module provides helper functions that enable the PPX to work with
 * variables, not just literals. It uses OCaml's type inference to select
 * the appropriate conversion function.
 *)

(* Type class-style conversion using local module pattern *)
module type TO_VALUE = sig
  type t
  val to_value : t -> Value.t
end

(* Conversion instances for common types *)
let string_to_value : (module TO_VALUE with type t = string) =
  (module struct
    type t = string
    let to_value s = Value.String s
  end)

let int_to_value : (module TO_VALUE with type t = int) =
  (module struct
    type t = int
    let to_value i = Value.Int (Int64.of_int i)
  end)

let int64_to_value : (module TO_VALUE with type t = int64) =
  (module struct
    type t = int64
    let to_value i = Value.Int i
  end)

let float_to_value : (module TO_VALUE with type t = float) =
  (module struct
    type t = float
    let to_value f = Value.Float f
  end)

let bool_to_value : (module TO_VALUE with type t = bool) =
  (module struct
    type t = bool
    let to_value b = Value.Bool b
  end)

let value_to_value : (module TO_VALUE with type t = Value.t) =
  (module struct
    type t = Value.t
    let to_value v = v  (* Identity *)
  end)

(* Simple conversion functions that the PPX can call *)
let of_string (s : string) : Value.t = Value.String s
let of_int (i : int) : Value.t = Value.Int (Int64.of_int i)
let of_int64 (i : int64) : Value.t = Value.Int i
let of_float (f : float) : Value.t = Value.Float f
let of_bool (b : bool) : Value.t = Value.Bool b
let of_value (v : Value.t) : Value.t = v

(* Generic conversion that tries to be smart - uses Obj for runtime typing *)
let auto (type a) (x : a) : Value.t =
  (* This is a fallback that uses runtime type inspection *)
  (* Note: This is not fully type-safe but provides ergonomics *)
  let obj = Obj.repr x in
  if Obj.is_int obj then
    (* It's an integer (or bool, or unit, or variant without args) *)
    let i = (Obj.obj obj : int) in
    (* Check if it's a boolean (0 or 1 in specific range) *)
    if i = 0 then Value.Bool false
    else if i = 1 then Value.Bool true
    else Value.Int (Int64.of_int i)
  else if Obj.is_block obj then
    let tag = Obj.tag obj in
    if tag = Obj.string_tag then
      Value.String (Obj.obj obj : string)
    else if tag = Obj.double_tag then
      Value.Float (Obj.obj obj : float)
    else if tag = Obj.custom_tag then
      (* Could be int64, int32, etc - try int64 *)
      (try
         let i64 : int64 = Obj.obj obj in
         Value.Int i64
       with _ -> Value.Null)
    else
      (* Unknown block type - try to handle as Value.t *)
      (try
         let v : Value.t = Obj.obj obj in
         v
       with _ -> Value.Null)
  else
    Value.Null
