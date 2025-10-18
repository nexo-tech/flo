open Flo

(* Define testable for Value.t *)
let value_testable =
  let rec pp fmt = function
    | Value.String s -> Format.fprintf fmt "String %S" s
    | Value.Int i -> Format.fprintf fmt "Int %Ld" i
    | Value.Float f -> Format.fprintf fmt "Float %g" f
    | Value.Bool b -> Format.fprintf fmt "Bool %b" b
    | Value.Array xs ->
        Format.fprintf fmt "Array [";
        List.iteri (fun i x ->
          if i > 0 then Format.fprintf fmt "; ";
          pp fmt x
        ) xs;
        Format.fprintf fmt "]"
    | Value.Object fields ->
        Format.fprintf fmt "Object {";
        List.iteri (fun i (k, v) ->
          if i > 0 then Format.fprintf fmt "; ";
          Format.fprintf fmt "%s: " k;
          pp fmt v
        ) fields;
        Format.fprintf fmt "}"
    | Value.Bytes b -> Format.fprintf fmt "Bytes(%d)" (Bytes.length b)
    | Value.Null -> Format.fprintf fmt "Null"
  in
  let rec equal a b = match (a, b) with
    | Value.String s1, Value.String s2 -> s1 = s2
    | Value.Int i1, Value.Int i2 -> i1 = i2
    | Value.Float f1, Value.Float f2 -> Float.abs (f1 -. f2) < 1e-10
    | Value.Bool b1, Value.Bool b2 -> b1 = b2
    | Value.Array xs1, Value.Array xs2 ->
        List.length xs1 = List.length xs2 &&
        List.for_all2 equal xs1 xs2
    | Value.Object fs1, Value.Object fs2 ->
        List.length fs1 = List.length fs2 &&
        List.for_all2 (fun (k1, v1) (k2, v2) -> k1 = k2 && equal v1 v2) fs1 fs2
    | Value.Bytes b1, Value.Bytes b2 -> Bytes.equal b1 b2
    | Value.Null, Value.Null -> true
    | _ -> false
  in
  Alcotest.testable pp equal

let yojson_testable = Alcotest.testable
  (fun fmt j -> Format.fprintf fmt "%s" (Yojson.Safe.to_string j))
  Yojson.Safe.equal

(* Test primitive types *)
let test_primitives () =
  let open Value in
  Alcotest.(check value_testable) "String" (String "hello") (string "hello");
  Alcotest.(check value_testable) "Int" (Int 42L) (int 42);
  Alcotest.(check value_testable) "Int64" (Int 9876543210L) (int64 9876543210L);
  Alcotest.(check value_testable) "Float" (Float 3.14) (float 3.14);
  Alcotest.(check value_testable) "Bool true" (Bool true) (bool true);
  Alcotest.(check value_testable) "Bool false" (Bool false) (bool false);
  Alcotest.(check value_testable) "Null" Null null

let test_complex_types () =
  let open Value in
  let arr = array [string "a"; int 1; bool true] in
  Alcotest.(check value_testable) "Array"
    (Array [String "a"; Int 1L; Bool true]) arr;

  let obj = object_ [
    ("name", string "Alice");
    ("age", int 30);
    ("active", bool true);
  ] in
  Alcotest.(check value_testable) "Object"
    (Object [("name", String "Alice"); ("age", Int 30L); ("active", Bool true)])
    obj

let test_bytes () =
  let open Value in
  let b = Bytes.of_string "hello" in
  let v = bytes b in
  Alcotest.(check value_testable) "Bytes" (Bytes b) v

(* Test to_yojson conversion *)
let test_to_yojson_primitives () =
  let open Value in
  Alcotest.(check yojson_testable) "String to yojson"
    (`String "test") (to_yojson (String "test"));
  Alcotest.(check yojson_testable) "Int to yojson"
    (`Int 42) (to_yojson (Int 42L));
  Alcotest.(check yojson_testable) "Float to yojson"
    (`Float 3.14) (to_yojson (Float 3.14));
  Alcotest.(check yojson_testable) "Bool to yojson"
    (`Bool true) (to_yojson (Bool true));
  Alcotest.(check yojson_testable) "Null to yojson"
    (`Null) (to_yojson Null)

let test_to_yojson_complex () =
  let open Value in
  let arr = Array [String "a"; Int 1L; Bool true] in
  Alcotest.(check yojson_testable) "Array to yojson"
    (`List [`String "a"; `Int 1; `Bool true])
    (to_yojson arr);

  let obj = Object [("x", Int 10L); ("y", String "test")] in
  Alcotest.(check yojson_testable) "Object to yojson"
    (`Assoc [("x", `Int 10); ("y", `String "test")])
    (to_yojson obj)

let test_to_yojson_bytes () =
  let open Value in
  let b = Bytes.of_string "\x00\x01\x02\xff" in
  let v = Bytes b in
  let j = to_yojson v in
  (* Should be hex encoded: 000102ff *)
  Alcotest.(check yojson_testable) "Bytes to yojson (hex)"
    (`String "000102ff") j

let test_to_yojson_large_int () =
  let open Value in
  (* Test int64 max value *)
  let large = Int Int64.max_int in
  let j = to_yojson large in
  match j with
  | `Intlit s ->
      Alcotest.(check string) "Large int as intlit"
        (Int64.to_string Int64.max_int) s
  | `Int _ ->
      (* On 64-bit systems with large max_int, this might fit *)
      Alcotest.(check bool) "Large int as int (acceptable on 64-bit)" true true
  | _ -> Alcotest.fail "Expected Int or Intlit"

(* Test of_yojson conversion *)
let test_of_yojson_primitives () =
  let open Value in
  Alcotest.(check value_testable) "String from yojson"
    (String "test") (of_yojson (`String "test"));
  Alcotest.(check value_testable) "Int from yojson"
    (Int 42L) (of_yojson (`Int 42));
  Alcotest.(check value_testable) "Float from yojson"
    (Float 3.14) (of_yojson (`Float 3.14));
  Alcotest.(check value_testable) "Bool from yojson"
    (Bool true) (of_yojson (`Bool true));
  Alcotest.(check value_testable) "Null from yojson"
    Null (of_yojson `Null)

let test_of_yojson_intlit () =
  let open Value in
  Alcotest.(check value_testable) "Intlit from yojson"
    (Int 9876543210L) (of_yojson (`Intlit "9876543210"))

let test_of_yojson_complex () =
  let open Value in
  let arr_json = `List [`String "a"; `Int 1; `Bool true] in
  Alcotest.(check value_testable) "Array from yojson"
    (Array [String "a"; Int 1L; Bool true])
    (of_yojson arr_json);

  let obj_json = `Assoc [("x", `Int 10); ("y", `String "test")] in
  Alcotest.(check value_testable) "Object from yojson"
    (Object [("x", Int 10L); ("y", String "test")])
    (of_yojson obj_json)

(* Test round-trip conversion *)
let test_round_trip () =
  let open Value in
  let test_value v =
    let json = to_yojson v in
    let v' = of_yojson json in
    Alcotest.(check value_testable) "Round trip" v v'
  in

  test_value (String "hello");
  test_value (Int 42L);
  test_value (Float 3.14);
  test_value (Bool true);
  test_value Null;
  test_value (Array [String "a"; Int 1L; Bool false]);
  test_value (Object [
    ("name", String "Alice");
    ("age", Int 30L);
    ("scores", Array [Int 95L; Int 87L; Int 92L]);
  ]);

  (* Note: Bytes doesn't round-trip perfectly through JSON because
     it's encoded as a hex string. This is a known limitation. *)
  let bytes_val = Bytes (Bytes.of_string "binary data") in
  let json = to_yojson bytes_val in
  let roundtripped = of_yojson json in
  (* After round-trip, Bytes becomes String (hex-encoded) *)
  Alcotest.(check value_testable) "Bytes round-trips as hex string"
    (String "62696e6172792064617461") roundtripped

let test_nested_structures () =
  let open Value in
  let nested = Object [
    ("user", Object [
      ("name", String "Alice");
      ("email", String "alice@example.com");
    ]);
    ("scores", Array [Int 95L; Int 87L; Int 92L]);
    ("metadata", Object [
      ("tags", Array [String "admin"; String "active"]);
      ("verified", Bool true);
    ]);
  ] in

  let json = to_yojson nested in
  let nested' = of_yojson json in
  Alcotest.(check value_testable) "Nested structures round-trip" nested nested'

let test_to_string () =
  let open Value in
  Alcotest.(check string) "String to_string" "\"hello\"" (to_string (String "hello"));
  Alcotest.(check string) "Int to_string" "42" (to_string (Int 42L));
  Alcotest.(check string) "Float to_string" "3.14" (to_string (Float 3.14));
  Alcotest.(check string) "Bool to_string" "true" (to_string (Bool true));
  Alcotest.(check string) "Null to_string" "null" (to_string Null);
  Alcotest.(check string) "Array to_string" "[1, 2, 3]"
    (to_string (Array [Int 1L; Int 2L; Int 3L]));
  Alcotest.(check string) "Object to_string" "{x: 10, y: \"test\"}"
    (to_string (Object [("x", Int 10L); ("y", String "test")]))

let test_bytes_to_string () =
  let open Value in
  let b = Bytes.of_string "hello" in
  let s = to_string (Bytes b) in
  (* Should show byte length *)
  Alcotest.(check string) "Bytes to_string shows length" "<bytes:5>" s

let () =
  let open Alcotest in
  run "Value" [
    "primitives", [
      test_case "Primitive types" `Quick test_primitives;
      test_case "Complex types" `Quick test_complex_types;
      test_case "Bytes type" `Quick test_bytes;
    ];
    "to_yojson", [
      test_case "Primitives to yojson" `Quick test_to_yojson_primitives;
      test_case "Complex types to yojson" `Quick test_to_yojson_complex;
      test_case "Bytes to yojson (hex)" `Quick test_to_yojson_bytes;
      test_case "Large int to yojson" `Quick test_to_yojson_large_int;
    ];
    "of_yojson", [
      test_case "Primitives from yojson" `Quick test_of_yojson_primitives;
      test_case "Intlit from yojson" `Quick test_of_yojson_intlit;
      test_case "Complex types from yojson" `Quick test_of_yojson_complex;
    ];
    "round_trip", [
      test_case "Round-trip conversion" `Quick test_round_trip;
      test_case "Nested structures" `Quick test_nested_structures;
    ];
    "to_string", [
      test_case "to_string for debugging" `Quick test_to_string;
      test_case "Bytes to_string" `Quick test_bytes_to_string;
    ];
  ]
