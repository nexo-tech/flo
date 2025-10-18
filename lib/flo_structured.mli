(** Type-safe structured logging with GADT-based context keys.

    This module provides type-safe structured logging capabilities, including:
    - GADT-based context keys for compile-time type safety
    - Span management for distributed tracing
    - Structured event logging with first-class module types
*)

(** {1 Type-Safe Context} *)

(** GADT for type-safe context keys.

    Context keys are typed, ensuring that values retrieved from context
    have the correct type at compile time.

    Example:
    {[
      let my_key : int key = create_key "my_int"

      (* Type-safe operations *)
      add my_key 42;
      let value = get my_key in  (* value : int option *)
    ]}
*)
type 'a key

(** Create a new context key.

    The string parameter is used as the internal key name for serialization
    and debugging. It should be unique within your application.

    @param name The key name
    @return A new typed context key
*)
val create_key : string -> 'a key

(** Get the string name of a key.

    @param key The context key
    @return The key's name
*)
val key_name : 'a key -> string

(** {2 Common Keys} *)

(** Predefined keys for common use cases. *)

val user_id_key : string key
val request_id_key : string key
val trace_id_key : string key
val session_id_key : string key

(** {2 Context Operations} *)

(** Add a typed value to the current fiber's context.

    The value is stored under the key in the fiber-local context.
    If the key already exists, the new value replaces the old one.

    Example:
    {[
      add user_id_key "alice";
      add request_id_key "req-123";
    ]}

    @param key The typed context key
    @param value The value to store
*)
val add : 'a key -> 'a -> unit

(** Retrieve a typed value from the current fiber's context.

    Returns Some value if the key exists, None otherwise.
    The returned value is guaranteed to have the correct type.

    @param key The typed context key
    @return Some value if found, None otherwise
*)
val get : 'a key -> 'a option

(** Execute a function with a typed binding in context.

    The binding is added to the current fiber's context for the duration
    of the function. Nested calls to with_binding will merge contexts,
    with inner bindings taking precedence.

    Example:
    {[
      with_binding user_id_key "alice" (fun () ->
        (* This fiber has user_id = "alice" *)
        process_request ()
      )
    ]}

    @param key The typed context key
    @param value The value to bind
    @param f The function to execute
    @return The result of f
*)
val with_binding : 'a key -> 'a -> (unit -> 'b) -> 'b

(** {1 Span Management} *)

(** A span represents a unit of work in distributed tracing.

    Spans have:
    - A unique span ID
    - A trace ID (shared across related spans)
    - A start time
    - An end time (when ended)
    - Attributes (key-value metadata)
    - A parent span (optional)
*)
type span

(** Get the span's trace ID.

    @param span The span
    @return The trace ID
*)
val span_trace_id : span -> string

(** Get the span's span ID.

    @param span The span
    @return The span ID
*)
val span_id : span -> string

(** Get the span's name.

    @param span The span
    @return The span name
*)
val span_name : span -> string

(** Start a new span.

    Creates and starts a new span with the given name. If a parent span
    is provided, the new span will be linked to it (inheriting trace_id).
    If no parent is provided and there's an active span in the current
    fiber's context, it will be used as the parent.

    The span is NOT automatically added to context. Use {!in_span} for
    automatic context management.

    Example:
    {[
      let span = start_span "database_query"
        ~attributes:[("query", Value.String "SELECT * FROM users")]
        ()
      in
      (* ... do work ... *)
      end_span span
    ]}

    @param name The span name
    @param attributes Optional attributes to attach to the span
    @param parent Optional parent span
    @return A new active span
*)
val start_span :
  string ->
  ?attributes:(string * Value.t) list ->
  ?parent:span ->
  unit ->
  span

(** End a span and log its duration.

    Marks the span as complete and automatically logs an event with
    the span's duration. The log level is Info by default.

    @param span The span to end
*)
val end_span : span -> unit

(** Execute a function within a span scope.

    This is the recommended way to use spans. It:
    1. Starts a new span
    2. Adds it to the current fiber's context
    3. Executes the function
    4. Automatically ends the span (even if an exception occurs)
    5. Returns the function result

    Example:
    {[
      let result = in_span "process_order" (fun span ->
        (* Span is active and in context *)
        let items = fetch_items () in
        process_items items
      )
    ]}

    @param name The span name
    @param f The function to execute with the span
    @return The result of f
*)
val in_span : string -> (span -> 'a) -> 'a

(** Get the current active span from fiber-local context.

    @return Some span if active, None otherwise
*)
val current_span : unit -> span option

(** {1 Structured Log Messages} *)

(** Module type for type-safe structured events.

    Implement this signature to define a structured event type that can
    be logged with full type safety.

    Example:
    {[
      module Order_Created : STRUCTURED = struct
        type t = {
          order_id : string;
          user_id : string;
          items : int;
          total : float;
        }

        let to_value t = Value.Object [
          ("order_id", Value.String t.order_id);
          ("user_id", Value.String t.user_id);
          ("items", Value.Int (Int64.of_int t.items));
          ("total", Value.Float t.total);
        ]

        let event_name = "order.created"
        let severity = Severity.Info
      end
    ]}
*)
module type STRUCTURED = sig
  (** The structured event type *)
  type t

  (** Convert the event to a Value.t for logging *)
  val to_value : t -> Value.t

  (** The event name (used for filtering and querying) *)
  val event_name : string

  (** The severity level for this event type *)
  val severity : Severity.t
end

(** Log a type-safe structured event.

    Takes a first-class module implementing STRUCTURED and an instance
    of its type, and logs it with full type safety.

    The event is logged with:
    - The severity specified in the module
    - The event name specified in the module
    - The structured data converted via to_value
    - The current fiber's context
    - The current span context (if active)

    Example:
    {[
      log_event (module Order_Created) {
        order_id = "12345";
        user_id = "alice";
        items = 3;
        total = 99.99;
      }
    ]}

    @param module The STRUCTURED module (first-class module)
    @param value The event instance
*)
val log_event : (module STRUCTURED with type t = 'a) -> 'a -> unit
