(** Fiber-local context for logging

    This module provides fiber-local storage for logging context using Eio.
    Context is automatically propagated to child fibers and can be used to
    track correlation IDs, user IDs, request IDs, and other metadata.
*)

(** Context type.

    A context is a collection of key-value pairs where keys are strings
    and values are {!Value.t}. Contexts are immutable and operations
    return new contexts.
*)
type context

(** Eio fiber key for fiber-local context storage.

    This key is used to store and retrieve context from Eio's fiber-local
    storage. Eio automatically propagates fiber-local values to child fibers.
*)
val context_key : context Eio.Fiber.key

(** {1 Context Operations} *)

(** Empty context with no key-value pairs. *)
val empty : context

(** Add a key-value pair to the context.

    If the key already exists, the new value replaces the old one.
    Returns a new context (immutable operation).

    @param key The context key
    @param value The context value
    @param ctx The context to add to
    @return New context with the key-value pair added
*)
val add : string -> Value.t -> context -> context

(** Get a value from the context by key.

    @param key The context key to lookup
    @param ctx The context to search
    @return Some value if found, None otherwise
*)
val get : string -> context -> Value.t option

(** Merge two contexts.

    When keys conflict, values from the second context take precedence.
    This is useful for combining parent and child contexts.

    Example:
    {[
      let parent = add "request_id" (Value.string "123") empty in
      let child = add "user_id" (Value.string "alice") empty in
      let merged = merge parent child
      (* merged has both request_id and user_id *)
    ]}

    @param ctx1 First context (lower precedence)
    @param ctx2 Second context (higher precedence)
    @return Merged context
*)
val merge : context -> context -> context

(** Get all key-value pairs from the context.

    @param ctx The context
    @return List of (key, value) pairs
*)
val to_list : context -> (string * Value.t) list

(** Create context from a list of key-value pairs.

    @param pairs List of (key, value) pairs
    @return New context
*)
val of_list : (string * Value.t) list -> context

(** {1 Fiber-Local Storage} *)

(** Execute a function with a specific context.

    The context is bound to the current fiber for the duration of the function.
    If a context already exists in the fiber, it is merged with the new context
    (new context takes precedence).

    Child fibers spawned within the function automatically inherit the context.

    Example:
    {[
      with_context (add "request_id" (Value.string "123") empty) (fun () ->
        (* This fiber has request_id in context *)
        Eio.Fiber.fork (fun () ->
          (* Child fiber also has request_id *)
          log_message ()
        )
      )
    ]}

    @param ctx The context to bind
    @param f The function to execute
    @return The result of f
*)
val with_context : context -> (unit -> 'a) -> 'a

(** Get the current fiber's context.

    Returns the context stored in the current fiber's local storage,
    or None if no context has been set.

    @return Some context if set, None otherwise
*)
val get_current : unit -> context option

(** {1 Convenience Functions} *)

(** Add a key-value pair to the current fiber's context.

    If no context exists, creates a new one with the key-value pair.
    If a context exists, adds the key-value pair to it.

    This is a convenience function that modifies the current fiber's context
    in place.

    @param key The context key
    @param value The context value
*)
val bind : string -> Value.t -> unit

(** Add multiple key-value pairs to the current fiber's context.

    @param pairs List of (key, value) pairs
*)
val bind_all : (string * Value.t) list -> unit

(** {1 Namespace Support} *)

(** Reserved key for namespace in context *)
val namespace_key : string

(** Get current namespace from fiber-local context.

    @return Some namespace if set, None otherwise
*)
val get_namespace : unit -> string option

(** Set namespace in current fiber's context.

    @param namespace The namespace to set
*)
val set_namespace : string -> unit

(** Execute function with namespace in context.

    The namespace is available to all logging calls within the function
    and child fibers automatically inherit it.

    Example:
    {[
      Flo_context.with_namespace "mylib.database" (fun () ->
        (* All logs here will have namespace "mylib.database" *)
        Flo.info "Connected";
        Eio.Fiber.fork (fun () ->
          (* Child fiber also has the namespace *)
          Flo.info "Query executed"
        )
      )
    ]}

    @param namespace The namespace to set
    @param f The function to execute
    @return Result of f
*)
val with_namespace : string -> (unit -> 'a) -> 'a
