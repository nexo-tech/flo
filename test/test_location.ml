open Flo

(* Define testable for Location.t *)
let location_testable =
  let pp fmt t =
    Format.fprintf fmt "{file=%S; line=%d; column=%d; module_name=%S; function_name=%s}"
      t.Location.file t.Location.line t.Location.column t.Location.module_name
      (match t.Location.function_name with
       | None -> "None"
       | Some fn -> Printf.sprintf "Some %S" fn)
  in
  let equal a b =
    a.Location.file = b.Location.file &&
    a.Location.line = b.Location.line &&
    a.Location.column = b.Location.column &&
    a.Location.module_name = b.Location.module_name &&
    a.Location.function_name = b.Location.function_name
  in
  Alcotest.testable pp equal

let test_unknown () =
  let loc = Location.unknown in
  Alcotest.(check string) "Unknown file" "" loc.file;
  Alcotest.(check int) "Unknown line" 0 loc.line;
  Alcotest.(check int) "Unknown column" 0 loc.column;
  Alcotest.(check string) "Unknown module_name" "" loc.module_name;
  Alcotest.(check (option string)) "Unknown function_name" None loc.function_name

let test_unknown_to_string () =
  let s = Location.to_string Location.unknown in
  Alcotest.(check string) "Unknown to_string" "<unknown>" s

let test_make () =
  let loc = Location.make ~file:"src/main.ml" ~line:42 in
  Alcotest.(check string) "make file" "src/main.ml" loc.file;
  Alcotest.(check int) "make line" 42 loc.line;
  Alcotest.(check int) "make column" 0 loc.column;
  Alcotest.(check string) "make module_name" "" loc.module_name;
  Alcotest.(check (option string)) "make function_name" None loc.function_name

let test_make_full () =
  let loc = Location.make_full
    ~file:"lib/flo.ml"
    ~line:100
    ~column:15
    ~module_name:"Flo"
    ~function_name:"info"
    ()
  in
  Alcotest.(check string) "make_full file" "lib/flo.ml" loc.file;
  Alcotest.(check int) "make_full line" 100 loc.line;
  Alcotest.(check int) "make_full column" 15 loc.column;
  Alcotest.(check string) "make_full module_name" "Flo" loc.module_name;
  Alcotest.(check (option string)) "make_full function_name" (Some "info") loc.function_name

let test_make_full_no_function () =
  let loc = Location.make_full
    ~file:"test.ml"
    ~line:10
    ~column:5
    ~module_name:"Test"
    ()
  in
  Alcotest.(check (option string)) "make_full without function" None loc.function_name

let test_to_string_file_with_line_and_column () =
  let loc = Location.make_full
    ~file:"src/main.ml"
    ~line:42
    ~column:10
    ~module_name:""
    ()
  in
  let s = Location.to_string loc in
  Alcotest.(check string) "File with line and column" "src/main.ml:42:10" s

let test_to_string_file_with_line_only () =
  let loc = Location.make ~file:"lib/severity.ml" ~line:25 in
  let s = Location.to_string loc in
  Alcotest.(check string) "File with line only" "lib/severity.ml:25" s

let test_to_string_module_with_function () =
  let loc = {
    Location.file = "";
    line = 0;
    column = 0;
    module_name = "MyModule";
    function_name = Some "process";
  } in
  let s = Location.to_string loc in
  Alcotest.(check string) "Module with function" "MyModule.process" s

let test_to_string_module_only () =
  let loc = {
    Location.file = "";
    line = 0;
    column = 0;
    module_name = "Utils";
    function_name = None;
  } in
  let s = Location.to_string loc in
  Alcotest.(check string) "Module only" "Utils" s

let test_to_string_empty_location () =
  let loc = {
    Location.file = "";
    line = 0;
    column = 0;
    module_name = "";
    function_name = None;
  } in
  let s = Location.to_string loc in
  Alcotest.(check string) "Empty location" "<unknown>" s

let test_to_string_prefers_file_over_module () =
  (* When both file and module are present, file takes precedence *)
  let loc = Location.make_full
    ~file:"src/app.ml"
    ~line:100
    ~column:20
    ~module_name:"App"
    ~function_name:"main"
    ()
  in
  let s = Location.to_string loc in
  Alcotest.(check string) "File takes precedence" "src/app.ml:100:20" s

let test_equality () =
  let loc1 = Location.make ~file:"test.ml" ~line:10 in
  let loc2 = Location.make ~file:"test.ml" ~line:10 in
  let loc3 = Location.make ~file:"test.ml" ~line:11 in

  Alcotest.(check location_testable) "Same locations equal" loc1 loc2;
  Alcotest.(check bool) "Different locations not equal" false
    (loc1.file = loc3.file && loc1.line = loc3.line)

let () =
  let open Alcotest in
  run "Location" [
    "unknown", [
      test_case "Unknown location has empty/zero fields" `Quick test_unknown;
      test_case "Unknown location to_string" `Quick test_unknown_to_string;
    ];
    "constructors", [
      test_case "make creates simple location" `Quick test_make;
      test_case "make_full creates complete location" `Quick test_make_full;
      test_case "make_full without function_name" `Quick test_make_full_no_function;
    ];
    "to_string", [
      test_case "File with line and column" `Quick test_to_string_file_with_line_and_column;
      test_case "File with line only" `Quick test_to_string_file_with_line_only;
      test_case "Module with function" `Quick test_to_string_module_with_function;
      test_case "Module only" `Quick test_to_string_module_only;
      test_case "Empty location" `Quick test_to_string_empty_location;
      test_case "File takes precedence over module" `Quick test_to_string_prefers_file_over_module;
    ];
    "equality", [
      test_case "Location equality" `Quick test_equality;
    ];
  ]
