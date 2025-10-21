(** Type-safe scoped loggers via functors *)

(* Module signatures *)
module type NAMESPACE = sig
  val namespace : string
end

module type LOGGER = sig
  val namespace : string

  (* Simple logging API *)
  val trace : ?location:Location.t -> string -> unit
  val debug : ?location:Location.t -> string -> unit
  val info : ?location:Location.t -> string -> unit
  val success : ?location:Location.t -> string -> unit
  val warn : ?location:Location.t -> string -> unit
  val error : ?location:Location.t -> string -> unit
  val fatal : ?location:Location.t -> string -> unit

  (* Printf-style *)
  val tracef : ('a, unit, string, unit) format4 -> 'a
  val debugf : ('a, unit, string, unit) format4 -> 'a
  val infof : ('a, unit, string, unit) format4 -> 'a
  val successf : ('a, unit, string, unit) format4 -> 'a
  val warnf : ('a, unit, string, unit) format4 -> 'a
  val errorf : ('a, unit, string, unit) format4 -> 'a
  val fatalf : ('a, unit, string, unit) format4 -> 'a

  (* Structured logging *)
  val trace_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val debug_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val info_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val success_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val warn_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val error_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit
  val fatal_fields : ?location:Location.t -> string ->
    fields:(string * Value.t) list -> unit

  (* Context propagation *)
  val with_span : string -> (unit -> 'a) -> 'a
  val bind : (string * Value.t) list -> unit

  (* Configuration *)
  val set_level : Severity.t -> unit
  val get_level : unit -> Severity.t option
  val get_effective_level : unit -> Severity.t
end

(* Make functor - creates a scoped logger for a given namespace *)
module Make (N : NAMESPACE) : LOGGER = struct
  let namespace = N.namespace

  (* Simple logging API - forwards to Flo.scoped_* *)
  let trace ?location msg =
    Flo.scoped_trace namespace ?location msg

  let debug ?location msg =
    Flo.scoped_debug namespace ?location msg

  let info ?location msg =
    Flo.scoped_info namespace ?location msg

  let success ?location msg =
    Flo.scoped_success namespace ?location msg

  let warn ?location msg =
    Flo.scoped_warn namespace ?location msg

  let error ?location msg =
    Flo.scoped_error namespace ?location msg

  let fatal ?location msg =
    Flo.scoped_fatal namespace ?location msg

  (* Printf-style logging *)
  let tracef fmt =
    Flo.scoped_tracef namespace fmt

  let debugf fmt =
    Flo.scoped_debugf namespace fmt

  let infof fmt =
    Flo.scoped_infof namespace fmt

  let successf fmt =
    Flo.scoped_successf namespace fmt

  let warnf fmt =
    Flo.scoped_warnf namespace fmt

  let errorf fmt =
    Flo.scoped_errorf namespace fmt

  let fatalf fmt =
    Flo.scoped_fatalf namespace fmt

  (* Structured logging *)
  let trace_fields ?location message ~fields =
    Flo.scoped_trace_fields namespace ?location message ~fields

  let debug_fields ?location message ~fields =
    Flo.scoped_debug_fields namespace ?location message ~fields

  let info_fields ?location message ~fields =
    Flo.scoped_info_fields namespace ?location message ~fields

  let success_fields ?location message ~fields =
    Flo.scoped_success_fields namespace ?location message ~fields

  let warn_fields ?location message ~fields =
    Flo.scoped_warn_fields namespace ?location message ~fields

  let error_fields ?location message ~fields =
    Flo.scoped_error_fields namespace ?location message ~fields

  let fatal_fields ?location message ~fields =
    Flo.scoped_fatal_fields namespace ?location message ~fields

  (* Context propagation - scoped to this namespace *)
  let with_span span_name f =
    (* Set namespace context, then create span *)
    Flo.with_namespace namespace (fun () ->
      Flo.with_span span_name f
    )

  let bind fields =
    (* Bind fields to current context *)
    Flo.bind fields

  (* Configuration - for this namespace *)
  let set_level level =
    Flo.set_level_for namespace level

  let get_level () =
    Flo.get_level_for namespace

  let get_effective_level () =
    Flo.get_effective_level namespace
end

(* Create runtime logger - returns first-class module *)
let create namespace =
  let module Logger = Make(struct let namespace = namespace end) in
  (module Logger : LOGGER)
