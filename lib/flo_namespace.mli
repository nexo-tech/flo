(** Namespace registry for hierarchical log level management.

    This module provides a registry for managing log levels on a per-namespace
    basis. Namespaces are hierarchical (dot-separated) and level lookup follows
    the hierarchy from most specific to least specific.

    See also:
    - {!Flo.set_level_for} for application-level API
    - {!Flo.get_effective_level} for querying effective levels
    - {!Flo_scoped} for type-safe scoped loggers
    - {!Flo.scoped_info} and related for manual scoped logging

    Example:
    {[
      (* Configure levels *)
      Flo_namespace.set_level "mylib.database" Severity.Debug;
      Flo_namespace.set_level "mylib" Severity.Info;

      (* Lookup effective level - hierarchical search *)
      get_effective_level "mylib.database.pool"  (* Returns Debug - inherits from mylib.database *)
      get_effective_level "mylib.cache"          (* Returns Info - inherits from mylib *)
      get_effective_level "other"                (* Returns root level - no match *)
    ]}

    Typical usage - applications configure at startup:
    {[
      let () =
        Eio_main.run @@ fun env ->
          (* Configure third-party libraries *)
          Flo.set_level_for "dream" Severity.Warn;
          Flo.set_level_for "cohttp.client" Severity.Error;

          (* Configure your library *)
          Flo.set_level_for "mylib.database" Severity.Debug;

          run_application env
    ]}
*)

(** {1 Namespace Configuration} *)

(** Set minimum log level for a specific namespace.

    When a log is emitted with namespace "a.b.c", the effective level
    is determined by searching in order:
    1. Exact match: "a.b.c"
    2. Parent namespaces: "a.b", then "a"
    3. Root: "" (the default level)

    @param namespace Dotted namespace (e.g., "mylib.database")
    @param level Minimum severity level
*)
val set_level : string -> Severity.t -> unit

(** Get configured level for a namespace.

    Returns None if no level is explicitly set for this exact namespace.
    Use {!get_effective_level} to get the level including parent lookup.

    @param namespace The namespace to query
    @return Some level if explicitly configured, None otherwise
*)
val get_level : string -> Severity.t option

(** Get effective level for a namespace (includes hierarchy lookup).

    This resolves the actual level after checking the namespace hierarchy.
    Searches from most specific to least specific namespace, then uses
    the root level if no match is found.

    @param namespace The namespace to query
    @param root_level The root/default level to use if no match
    @return The effective level (never None)
*)
val get_effective_level : namespace:string -> root_level:Severity.t -> Severity.t

(** Clear level for a namespace.

    After clearing, the namespace will use parent or root level.

    @param namespace The namespace to clear
*)
val clear_level : string -> unit

(** List all configured namespace levels.

    Returns all explicitly configured namespaces and their levels.
    Does not include the root level or inherited levels.

    @return List of (namespace, level) pairs
*)
val get_all_levels : unit -> (string * Severity.t) list

(** Clear all namespace levels.

    Resets the registry to empty state. The root level is not affected.
*)
val clear_all : unit -> unit

(** {1 Hierarchical Lookup} *)

(** Split namespace into hierarchy.

    Examples:
    - "a.b.c" → ["a.b.c"; "a.b"; "a"; ""]
    - "mylib" → ["mylib"; ""]
    - "" → [""]

    @param namespace The namespace to split
    @return List of namespaces from most specific to root
*)
val namespace_hierarchy : string -> string list
