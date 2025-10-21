(** Tests for namespace registry and hierarchical lookups *)

open Flo

(* Define testable for Severity.t *)
module Severity = struct
  include Severity

  let pp fmt = function
    | Trace -> Format.fprintf fmt "Trace"
    | Debug -> Format.fprintf fmt "Debug"
    | Info -> Format.fprintf fmt "Info"
    | Success -> Format.fprintf fmt "Success"
    | Warn -> Format.fprintf fmt "Warn"
    | Error -> Format.fprintf fmt "Error"
    | Fatal -> Format.fprintf fmt "Fatal"

  let equal a b = compare a b = 0
  let testable = Alcotest.testable pp equal
end

(** Test namespace hierarchy splitting *)
let test_namespace_hierarchy () =
  Eio_main.run @@ fun _env ->
    (* Empty namespace *)
    let h1 = Flo_namespace.namespace_hierarchy "" in
    Alcotest.(check (list string)) "empty namespace" [""] h1;

    (* Single component *)
    let h2 = Flo_namespace.namespace_hierarchy "mylib" in
    Alcotest.(check (list string)) "single component" ["mylib"; ""] h2;

    (* Two components *)
    let h3 = Flo_namespace.namespace_hierarchy "mylib.database" in
    Alcotest.(check (list string)) "two components"
      ["mylib.database"; "mylib"; ""] h3;

    (* Three components *)
    let h4 = Flo_namespace.namespace_hierarchy "mylib.database.pool" in
    Alcotest.(check (list string)) "three components"
      ["mylib.database.pool"; "mylib.database"; "mylib"; ""] h4;

    (* Deep nesting *)
    let h5 = Flo_namespace.namespace_hierarchy "a.b.c.d.e" in
    Alcotest.(check (list string)) "deep nesting"
      ["a.b.c.d.e"; "a.b.c.d"; "a.b.c"; "a.b"; "a"; ""] h5

(** Test setting and getting namespace levels *)
let test_set_and_get_level () =
  Eio_main.run @@ fun _env ->
    (* Clear all before test *)
    Flo_namespace.clear_all ();

    (* Set a level *)
    Flo_namespace.set_level "mylib" Severity.Debug;

    (* Get exact level *)
    let level = Flo_namespace.get_level "mylib" in
    Alcotest.(check (option Severity.testable))
      "get exact level" (Some Severity.Debug) level;

    (* Get non-existent level *)
    let level2 = Flo_namespace.get_level "other" in
    Alcotest.(check (option Severity.testable))
      "get non-existent level" None level2;

    (* Set another level *)
    Flo_namespace.set_level "mylib.database" Severity.Trace;
    let level3 = Flo_namespace.get_level "mylib.database" in
    Alcotest.(check (option Severity.testable))
      "get second level" (Some Severity.Trace) level3;

    (* Clean up *)
    Flo_namespace.clear_all ()

(** Test hierarchical level lookup *)
let test_hierarchical_lookup () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set parent level *)
    Flo_namespace.set_level "mylib" Severity.Info;

    (* Child without explicit level should inherit *)
    let effective1 = Flo_namespace.get_effective_level
      ~namespace:"mylib.database" ~root_level:Severity.Warn in
    Alcotest.(check Severity.testable)
      "child inherits parent level" Severity.Info effective1;

    (* Set child level - should override parent *)
    Flo_namespace.set_level "mylib.database" Severity.Debug;
    let effective2 = Flo_namespace.get_effective_level
      ~namespace:"mylib.database" ~root_level:Severity.Warn in
    Alcotest.(check Severity.testable)
      "child overrides parent level" Severity.Debug effective2;

    (* Grandchild without explicit level inherits from parent *)
    let effective3 = Flo_namespace.get_effective_level
      ~namespace:"mylib.database.pool" ~root_level:Severity.Warn in
    Alcotest.(check Severity.testable)
      "grandchild inherits from parent" Severity.Debug effective3;

    (* Sibling inherits from top-level parent *)
    let effective4 = Flo_namespace.get_effective_level
      ~namespace:"mylib.cache" ~root_level:Severity.Warn in
    Alcotest.(check Severity.testable)
      "sibling inherits from top parent" Severity.Info effective4;

    (* Completely different namespace uses root *)
    let effective5 = Flo_namespace.get_effective_level
      ~namespace:"other.component" ~root_level:Severity.Error in
    Alcotest.(check Severity.testable)
      "different namespace uses root" Severity.Error effective5;

    Flo_namespace.clear_all ()

(** Test clearing namespace levels *)
let test_clear_level () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set some levels *)
    Flo_namespace.set_level "mylib" Severity.Debug;
    Flo_namespace.set_level "mylib.database" Severity.Trace;

    (* Verify they're set *)
    Alcotest.(check (option Severity.testable))
      "level is set" (Some Severity.Trace)
      (Flo_namespace.get_level "mylib.database");

    (* Clear specific level *)
    Flo_namespace.clear_level "mylib.database";

    (* Should be None now *)
    Alcotest.(check (option Severity.testable))
      "level is cleared" None
      (Flo_namespace.get_level "mylib.database");

    (* But parent should still exist *)
    Alcotest.(check (option Severity.testable))
      "parent level still exists" (Some Severity.Debug)
      (Flo_namespace.get_level "mylib");

    (* Effective level should now inherit from parent *)
    let effective = Flo_namespace.get_effective_level
      ~namespace:"mylib.database" ~root_level:Severity.Info in
    Alcotest.(check Severity.testable)
      "inherits after clear" Severity.Debug effective;

    Flo_namespace.clear_all ()

(** Test get_all_levels *)
let test_get_all_levels () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Initially empty *)
    let levels1 = Flo_namespace.get_all_levels () in
    Alcotest.(check int) "initially empty" 0 (List.length levels1);

    (* Add some levels *)
    Flo_namespace.set_level "mylib" Severity.Debug;
    Flo_namespace.set_level "mylib.database" Severity.Trace;
    Flo_namespace.set_level "other" Severity.Warn;

    (* Should have 3 entries *)
    let levels2 = Flo_namespace.get_all_levels () in
    Alcotest.(check int) "has 3 entries" 3 (List.length levels2);

    (* Check that all are present (order doesn't matter) *)
    let has_mylib = List.exists (fun (ns, _) -> ns = "mylib") levels2 in
    let has_database = List.exists (fun (ns, _) -> ns = "mylib.database") levels2 in
    let has_other = List.exists (fun (ns, _) -> ns = "other") levels2 in
    Alcotest.(check bool) "has mylib" true has_mylib;
    Alcotest.(check bool) "has mylib.database" true has_database;
    Alcotest.(check bool) "has other" true has_other;

    Flo_namespace.clear_all ()

(** Test clear_all *)
let test_clear_all () =
  Eio_main.run @@ fun _env ->
    (* Set some levels *)
    Flo_namespace.set_level "a" Severity.Debug;
    Flo_namespace.set_level "b" Severity.Info;
    Flo_namespace.set_level "c" Severity.Warn;

    (* Verify they exist *)
    let levels1 = Flo_namespace.get_all_levels () in
    Alcotest.(check int) "has levels before clear" 3 (List.length levels1);

    (* Clear all *)
    Flo_namespace.clear_all ();

    (* Should be empty *)
    let levels2 = Flo_namespace.get_all_levels () in
    Alcotest.(check int) "empty after clear_all" 0 (List.length levels2);

    (* Individual gets should return None *)
    Alcotest.(check (option (module Severity)))
      "a is None" None (Flo_namespace.get_level "a");
    Alcotest.(check (option (module Severity)))
      "b is None" None (Flo_namespace.get_level "b");
    Alcotest.(check (option (module Severity)))
      "c is None" None (Flo_namespace.get_level "c")

(** Test record namespace field *)
let test_record_namespace () =
  Eio_main.run @@ fun _env ->
    (* Create record without namespace *)
    let r1 = Record.make ~severity:Severity.Info ~message:"test" in
    Alcotest.(check (option string))
      "initial namespace is None" None (Record.namespace r1);

    (* Add namespace *)
    let r2 = Record.with_namespace "mylib.database" r1 in
    Alcotest.(check (option string))
      "namespace is set" (Some "mylib.database") (Record.namespace r2);

    (* Verify original record unchanged (immutable) *)
    Alcotest.(check (option string))
      "original unchanged" None (Record.namespace r1);

    (* Override namespace *)
    let r3 = Record.with_namespace "other" r2 in
    Alcotest.(check (option string))
      "namespace overridden" (Some "other") (Record.namespace r3)

(** Test record to_string includes namespace *)
let test_record_to_string_with_namespace () =
  Eio_main.run @@ fun _env ->
    let r1 = Record.make ~severity:Severity.Info ~message:"test message" in
    let r2 = Record.with_namespace "mylib.database" r1 in

    let s = Record.to_string r2 in

    (* Should contain the namespace *)
    let has_namespace = String.length s > 0 &&
                       (try ignore (String.index s '['); true with Not_found -> false) in
    Alcotest.(check bool) "to_string includes namespace marker" true has_namespace

(** Test concurrent access to namespace registry *)
let test_concurrent_namespace_access () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    Eio.Switch.run @@ fun sw ->
      (* Spawn multiple fibers setting different namespaces *)
      for i = 1 to 10 do
        Eio.Fiber.fork ~sw (fun () ->
          let ns = Printf.sprintf "namespace%d" i in
          Flo_namespace.set_level ns Severity.Debug;

          (* Verify it was set *)
          let level = Flo_namespace.get_level ns in
          Alcotest.(check (option Severity.testable))
            (Printf.sprintf "namespace%d set" i)
            (Some Severity.Debug) level
        )
      done;

    (* After fibers complete, all namespaces should be set *)
    let all_levels = Flo_namespace.get_all_levels () in
    Alcotest.(check int) "all namespaces set concurrently" 10 (List.length all_levels);

    Flo_namespace.clear_all ()

(** Test edge cases *)
let test_edge_cases () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Very long namespace *)
    let long_ns = String.concat "." (List.init 50 (fun i -> Printf.sprintf "component%d" i)) in
    Flo_namespace.set_level long_ns Severity.Debug;
    let level = Flo_namespace.get_level long_ns in
    Alcotest.(check (option Severity.testable))
      "very long namespace" (Some Severity.Debug) level;

    (* Single character components *)
    Flo_namespace.set_level "a.b.c" Severity.Info;
    let level2 = Flo_namespace.get_level "a.b.c" in
    Alcotest.(check (option Severity.testable))
      "single char components" (Some Severity.Info) level2;

    (* Root namespace (empty string) *)
    Flo_namespace.set_level "" Severity.Warn;
    let level3 = Flo_namespace.get_level "" in
    Alcotest.(check (option Severity.testable))
      "root namespace" (Some Severity.Warn) level3;

    Flo_namespace.clear_all ()

(** Test namespace-based filtering in dispatch *)
let test_namespace_filtering () =
  Eio_main.run @@ fun _env ->
    (* Set up different levels for different namespaces *)
    Flo.set_level Severity.Info;  (* Root level *)
    Flo.set_level_for "mylib.database" Severity.Debug;
    Flo.set_level_for "mylib.cache" Severity.Warn;

    (* Test that get_effective_level works through Flo API *)
    let level1 = Flo.get_effective_level "mylib.database" in
    Alcotest.(check Severity.testable)
      "effective level for mylib.database" Severity.Debug level1;

    let level2 = Flo.get_effective_level "mylib.cache" in
    Alcotest.(check Severity.testable)
      "effective level for mylib.cache" Severity.Warn level2;

    let level3 = Flo.get_effective_level "other" in
    Alcotest.(check Severity.testable)
      "effective level for other (uses root)" Severity.Info level3;

    (* Test hierarchical inheritance *)
    let level4 = Flo.get_effective_level "mylib.database.pool" in
    Alcotest.(check Severity.testable)
      "child inherits from mylib.database" Severity.Debug level4;

    (* Clean up *)
    Flo_namespace.clear_all ()

(** Test that set_level clears cache *)
let test_level_cache_invalidation () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set initial level *)
    Flo.set_level Severity.Info;
    let level1 = Flo.get_effective_level "test.namespace" in
    Alcotest.(check Severity.testable)
      "initial level" Severity.Info level1;

    (* Change global level - should invalidate cache *)
    Flo.set_level Severity.Debug;
    let level2 = Flo.get_effective_level "test.namespace" in
    Alcotest.(check Severity.testable)
      "level after global change" Severity.Debug level2;

    (* Set namespace level - should invalidate cache *)
    Flo.set_level_for "test" Severity.Warn;
    let level3 = Flo.get_effective_level "test.namespace" in
    Alcotest.(check Severity.testable)
      "level after namespace change" Severity.Warn level3;

    (* Clear namespace level - should invalidate cache *)
    Flo.clear_level_for "test";
    let level4 = Flo.get_effective_level "test.namespace" in
    Alcotest.(check Severity.testable)
      "level after clear" Severity.Debug level4;

    Flo_namespace.clear_all ()

(** Test Flo.get_all_levels API *)
let test_flo_get_all_levels () =
  Eio_main.run @@ fun _env ->
    Flo_namespace.clear_all ();

    (* Set some levels via Flo API *)
    Flo.set_level_for "ns1" Severity.Debug;
    Flo.set_level_for "ns2" Severity.Info;
    Flo.set_level_for "ns3" Severity.Warn;

    let all_levels = Flo.get_all_levels () in
    Alcotest.(check int) "has 3 namespaces" 3 (List.length all_levels);

    (* Check they're all present *)
    let has_ns1 = List.exists (fun (ns, _) -> ns = "ns1") all_levels in
    let has_ns2 = List.exists (fun (ns, _) -> ns = "ns2") all_levels in
    let has_ns3 = List.exists (fun (ns, _) -> ns = "ns3") all_levels in
    Alcotest.(check bool) "has ns1" true has_ns1;
    Alcotest.(check bool) "has ns2" true has_ns2;
    Alcotest.(check bool) "has ns3" true has_ns3;

    Flo_namespace.clear_all ()

(** Test pretty formatter displays namespace *)
let test_pretty_format_with_namespace () =
  Eio_main.run @@ fun _env ->
    let r1 = Record.make ~severity:Severity.Info ~message:"test message" in
    let r2 = Record.with_namespace "mylib.component" r1 in

    let formatted = Flo_format_pretty.format r2 in

    (* Should contain the namespace *)
    let has_namespace = String.length formatted > 0 &&
                       (try ignore (String.index formatted '['); true with Not_found -> false) in
    Alcotest.(check bool) "formatted output has bracket" true has_namespace;

    (* Should contain "mylib.component" *)
    let contains_namespace =
      try
        ignore (Str.search_forward (Str.regexp "mylib\\.component") formatted 0);
        true
      with Not_found -> false
    in
    Alcotest.(check bool) "contains namespace text" true contains_namespace

(** Test suite *)
let () =
  Alcotest.run "Flo_namespace" [
    "hierarchy", [
      Alcotest.test_case "namespace_hierarchy" `Quick test_namespace_hierarchy;
    ];
    "basic", [
      Alcotest.test_case "set_and_get_level" `Quick test_set_and_get_level;
      Alcotest.test_case "clear_level" `Quick test_clear_level;
      Alcotest.test_case "get_all_levels" `Quick test_get_all_levels;
      Alcotest.test_case "clear_all" `Quick test_clear_all;
    ];
    "hierarchical", [
      Alcotest.test_case "hierarchical_lookup" `Quick test_hierarchical_lookup;
    ];
    "record", [
      Alcotest.test_case "record_namespace" `Quick test_record_namespace;
      Alcotest.test_case "record_to_string_with_namespace" `Quick test_record_to_string_with_namespace;
    ];
    "concurrency", [
      Alcotest.test_case "concurrent_namespace_access" `Quick test_concurrent_namespace_access;
    ];
    "edge_cases", [
      Alcotest.test_case "edge_cases" `Quick test_edge_cases;
    ];
    "filtering", [
      Alcotest.test_case "namespace_filtering" `Quick test_namespace_filtering;
      Alcotest.test_case "level_cache_invalidation" `Quick test_level_cache_invalidation;
      Alcotest.test_case "flo_get_all_levels" `Quick test_flo_get_all_levels;
    ];
    "formatting", [
      Alcotest.test_case "pretty_format_with_namespace" `Quick test_pretty_format_with_namespace;
    ];
  ]
