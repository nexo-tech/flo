type t = {
  file : string;
  line : int;
  column : int;
  module_name : string;
  function_name : string option;
}

let unknown = {
  file = "";
  line = 0;
  column = 0;
  module_name = "";
  function_name = None;
}

let to_string t =
  if t = unknown then
    "<unknown>"
  else if t.file <> "" && t.line > 0 then
    (* File-based location: "file.ml:123:45" or "file.ml:123" *)
    if t.column > 0 then
      Printf.sprintf "%s:%d:%d" t.file t.line t.column
    else
      Printf.sprintf "%s:%d" t.file t.line
  else if t.module_name <> "" then
    (* Module-based location: "Module.function" or "Module" *)
    match t.function_name with
    | Some fn -> Printf.sprintf "%s.%s" t.module_name fn
    | None -> t.module_name
  else
    "<unknown>"

let make ~file ~line = {
  file;
  line;
  column = 0;
  module_name = "";
  function_name = None;
}

let make_full ~file ~line ~column ~module_name ?function_name () = {
  file;
  line;
  column;
  module_name;
  function_name;
}
