(** Source code location information *)

(** Location type representing source code position.

    Contains information about where a log message originated from,
    including file name, line/column position, module, and optionally
    the function name.
*)
type t = {
  file : string;              (** Source file path *)
  line : int;                 (** Line number (1-indexed) *)
  column : int;               (** Column number (1-indexed) *)
  module_name : string;       (** Module name *)
  function_name : string option;  (** Optional function name *)
}

(** Unknown/unspecified location.

    Sentinel value used when location information is not available.
    All fields are set to empty strings or 0.
*)
val unknown : t

(** Convert location to human-readable string.

    Format depends on available information:
    - With line and column: "file.ml:123:45"
    - With line only: "file.ml:123"
    - With function: "Module.function_name"
    - With module only: "Module"
    - Unknown location: "<unknown>"

    Examples:
    - {file="src/main.ml"; line=42; column=10; ...} -> "src/main.ml:42:10"
    - {module_name="MyModule"; function_name=Some "process"; ...} -> "MyModule.process"
    - unknown -> "<unknown>"
*)
val to_string : t -> string

(** Create location from file and line number.

    Convenience constructor for simple location creation.
    Sets column to 0, module_name to "", function_name to None.
*)
val make : file:string -> line:int -> t

(** Create location with all fields. *)
val make_full :
  file:string ->
  line:int ->
  column:int ->
  module_name:string ->
  ?function_name:string ->
  unit ->
  t
