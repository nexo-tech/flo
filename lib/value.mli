(** Type-safe structured values for log fields *)

(** Structured value type for log attributes and bodies.

    Supports JSON-compatible types for structured logging.
    This type mirrors Yojson.Safe.t but provides a cleaner interface
    for logging use cases.
*)
type t =
  | String of string              (** String value *)
  | Int of int64                  (** Integer value (64-bit) *)
  | Float of float                (** Floating point value *)
  | Bool of bool                  (** Boolean value *)
  | Array of t list               (** Array of values *)
  | Object of (string * t) list   (** Object/map of key-value pairs *)
  | Bytes of bytes                (** Raw bytes (base64 encoded in JSON) *)
  | Null                          (** Null value *)

(** Convert value to Yojson representation.

    - String -> `String
    - Int -> `Int (converted to int if possible, `Intlit otherwise)
    - Float -> `Float
    - Bool -> `Bool
    - Array -> `List
    - Object -> `Assoc
    - Bytes -> `String (hex encoded)
    - Null -> `Null
*)
val to_yojson : t -> Yojson.Safe.t

(** Convert from Yojson representation to value.

    - `String -> String
    - `Int -> Int
    - `Intlit -> Int (parsed from string)
    - `Float -> Float
    - `Bool -> Bool
    - `List -> Array
    - `Assoc -> Object
    - `Null -> Null
*)
val of_yojson : Yojson.Safe.t -> t

(** {1 Convenience Constructors} *)

(** Create a string value. *)
val string : string -> t

(** Create an int value from native int. *)
val int : int -> t

(** Create an int64 value. *)
val int64 : int64 -> t

(** Create a float value. *)
val float : float -> t

(** Create a boolean value. *)
val bool : bool -> t

(** Create an array value. *)
val array : t list -> t

(** Create an object value. *)
val object_ : (string * t) list -> t

(** Create a bytes value. *)
val bytes : bytes -> t

(** Null value singleton. *)
val null : t

(** {1 Utilities} *)

(** Convert value to a pretty-printed string for debugging.

    Not suitable for production logging - use to_yojson for that.
*)
val to_string : t -> string
