(** Composable logging primitives using contravariant functors

    This module provides a functional, compositional approach to logging
    inspired by Haskell's co-log library. Loggers are contravariant functors
    that can be composed as monoids.
*)

(** {1 Log Actions - Contravariant Functors} *)

(** A log action transforms messages into effects.

    The type [('m, 'msg) t] represents a logger that:
    - Takes a message of type ['msg]
    - Produces an effect of type ['m]

    The type variable ['m] is typically [unit] for side-effecting loggers.

    This is a contravariant functor in ['msg]: you can transform the input
    message type with {!contramap}.
*)
type ('m, 'msg) t = 'msg -> 'm

(** {1 Construction} *)

(** Create a logger from a function.

    @param f The logging function
    @return A logger that applies f to messages
*)
val make : ('msg -> 'm) -> ('m, 'msg) t

(** No-op logger that discards all messages.

    Produces the unit effect [()] for any message.
*)
val noop : (unit, 'msg) t

(** {1 Contravariant Operations} *)

(** Transform the input message type (contravariant map).

    Given a function [f : 'a -> 'b] and a logger for ['b] messages,
    creates a logger for ['a] messages by applying [f] first.

    This is the contravariant functor operation: the function goes
    in the opposite direction of the type parameter.

    Example:
    {[
      let record_logger : (unit, Record.t) t = ...
      let string_to_record : string -> Record.t = ...
      let string_logger : (unit, string) t =
        contramap string_to_record record_logger
    ]}

    @param f Function to transform ['a] to ['b]
    @param logger Logger for ['b] messages
    @return Logger for ['a] messages
*)
val contramap : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t

(** Infix operator for {!contramap}.

    Usage: [f >$< logger]

    The direction of the operator [>$<] suggests that data flows
    from left (input) through the function to the logger on right.
*)
val (>$<) : ('a -> 'b) -> ('m, 'b) t -> ('m, 'a) t

(** {1 Composition} *)

(** Combine two loggers into one (monoid operation).

    The combined logger sends each message to both loggers.
    Effects are executed left-to-right.

    This forms a monoid with {!noop} as identity:
    - [combine noop logger = logger]
    - [combine logger noop = logger]
    - [combine (combine l1 l2) l3 = combine l1 (combine l2 l3)]

    @param logger1 First logger
    @param logger2 Second logger
    @return Combined logger
*)
val combine : (unit, 'msg) t -> (unit, 'msg) t -> (unit, 'msg) t

(** Infix operator for {!combine}.

    Usage: [logger1 <> logger2]

    Note: Uses OCaml's standard [<>] operator for monoid append.
*)
val (<>) : (unit, 'msg) t -> (unit, 'msg) t -> (unit, 'msg) t

(** Combine a list of loggers into one.

    Equivalent to folding {!combine} over the list with {!noop} as identity.

    @param loggers List of loggers to combine
    @return Combined logger
*)
val combine_all : (unit, 'msg) t list -> (unit, 'msg) t

(** {1 Filtering} *)

(** Filter messages based on a predicate.

    Messages for which the predicate returns [false] are discarded.
    Messages for which the predicate returns [true] are passed to the logger.

    @param predicate Function to test messages
    @param logger Logger to filter
    @return Filtered logger
*)
val filter : ('msg -> bool) -> (unit, 'msg) t -> (unit, 'msg) t

(** Filter log records based on severity level.

    Only records with severity >= the specified level are logged.

    Example:
    {[
      let logger = level_filter Severity.Info base_logger
      (* Only Info, Success, Warn, Error, Fatal are logged *)
    ]}

    @param min_level Minimum severity level
    @param logger Logger for records
    @return Filtered logger
*)
val level_filter : Severity.t -> (unit, Record.t) t -> (unit, Record.t) t

(** {1 Application} *)

(** Apply a logger to a message.

    This is function application: [log logger msg = logger msg]

    @param logger The logger
    @param msg The message
    @return The effect produced by the logger
*)
val log : ('m, 'msg) t -> 'msg -> 'm

(** Infix operator for {!log}.

    Usage: [logger <& message]

    The operator [<&] suggests that the message is fed into the logger.
*)
val (<&) : ('m, 'msg) t -> 'msg -> 'm
