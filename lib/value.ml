type t =
  | String of string
  | Int of int64
  | Float of float
  | Bool of bool
  | Array of t list
  | Object of (string * t) list
  | Bytes of bytes
  | Null

let rec to_yojson = function
  | String s -> `String s
  | Int i ->
      (* Try to fit in native int, otherwise use intlit *)
      if i >= Int64.of_int min_int && i <= Int64.of_int max_int then
        `Int (Int64.to_int i)
      else
        `Intlit (Int64.to_string i)
  | Float f -> `Float f
  | Bool b -> `Bool b
  | Array xs -> `List (List.map to_yojson xs)
  | Object fields -> `Assoc (List.map (fun (k, v) -> (k, to_yojson v)) fields)
  | Bytes b ->
      (* Encode bytes as hex string for JSON *)
      let hex_of_bytes b =
        let n = Bytes.length b in
        let buf = Buffer.create (n * 2) in
        for i = 0 to n - 1 do
          Printf.bprintf buf "%02x" (Bytes.get b i |> Char.code)
        done;
        Buffer.contents buf
      in
      `String (hex_of_bytes b)
  | Null -> `Null

let rec of_yojson = function
  | `String s -> String s
  | `Int i -> Int (Int64.of_int i)
  | `Intlit s -> Int (Int64.of_string s)
  | `Float f -> Float f
  | `Bool b -> Bool b
  | `List xs -> Array (List.map of_yojson xs)
  | `Assoc fields -> Object (List.map (fun (k, v) -> (k, of_yojson v)) fields)
  | `Null -> Null

(* Convenience constructors *)
let string s = String s
let int i = Int (Int64.of_int i)
let int64 i = Int i
let float f = Float f
let bool b = Bool b
let array xs = Array xs
let object_ fields = Object fields
let bytes b = Bytes b
let null = Null

(* Utilities *)
let rec to_string = function
  | String s -> Printf.sprintf "%S" s
  | Int i -> Int64.to_string i
  | Float f -> Printf.sprintf "%g" f
  | Bool true -> "true"
  | Bool false -> "false"
  | Array xs ->
      let items = String.concat ", " (List.map to_string xs) in
      Printf.sprintf "[%s]" items
  | Object fields ->
      let pairs = List.map (fun (k, v) ->
        Printf.sprintf "%s: %s" k (to_string v)
      ) fields in
      Printf.sprintf "{%s}" (String.concat ", " pairs)
  | Bytes b ->
      Printf.sprintf "<bytes:%d>" (Bytes.length b)
  | Null -> "null"
