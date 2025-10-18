open Flo

(* Test empty context *)
let test_empty () =
  let ctx = Flo_context.empty in
  let pairs = Flo_context.to_list ctx in
  Alcotest.(check int) "empty has no pairs" 0 (List.length pairs)

(* Test add and get *)
let test_add_get () =
  let ctx = Flo_context.empty in
  let ctx = Flo_context.add "key1" (Value.string "value1") ctx in
  let ctx = Flo_context.add "key2" (Value.int 42) ctx in

  (match Flo_context.get "key1" ctx with
   | Some v -> Alcotest.(check string) "key1 value" "\"value1\"" (Value.to_string v)
   | None -> Alcotest.fail "key1 not found");

  (match Flo_context.get "key2" ctx with
   | Some v -> Alcotest.(check string) "key2 value" "42" (Value.to_string v)
   | None -> Alcotest.fail "key2 not found");

  (match Flo_context.get "nonexistent" ctx with
   | Some _ -> Alcotest.fail "nonexistent key should not exist"
   | None -> ())

(* Test add replaces existing key *)
let test_add_replaces () =
  let ctx = Flo_context.empty in
  let ctx = Flo_context.add "key" (Value.string "old") ctx in
  let ctx = Flo_context.add "key" (Value.string "new") ctx in

  match Flo_context.get "key" ctx with
  | Some v -> Alcotest.(check string) "key replaced" "\"new\"" (Value.to_string v)
  | None -> Alcotest.fail "key not found"

(* Test merge *)
let test_merge () =
  let ctx1 = Flo_context.empty in
  let ctx1 = Flo_context.add "key1" (Value.string "from_ctx1") ctx1 in
  let ctx1 = Flo_context.add "common" (Value.string "ctx1_value") ctx1 in

  let ctx2 = Flo_context.empty in
  let ctx2 = Flo_context.add "key2" (Value.string "from_ctx2") ctx2 in
  let ctx2 = Flo_context.add "common" (Value.string "ctx2_value") ctx2 in

  let merged = Flo_context.merge ctx1 ctx2 in

  (* ctx2 takes precedence for common key *)
  (match Flo_context.get "common" merged with
   | Some v -> Alcotest.(check string) "common from ctx2" "\"ctx2_value\"" (Value.to_string v)
   | None -> Alcotest.fail "common not found");

  (* Both unique keys should be present *)
  (match Flo_context.get "key1" merged with
   | Some _ -> ()
   | None -> Alcotest.fail "key1 not found");

  (match Flo_context.get "key2" merged with
   | Some _ -> ()
   | None -> Alcotest.fail "key2 not found")

(* Test to_list and of_list *)
let test_to_list_of_list () =
  let pairs = [
    ("key1", Value.string "value1");
    ("key2", Value.int 42);
    ("key3", Value.bool true);
  ] in

  let ctx = Flo_context.of_list pairs in
  let pairs' = Flo_context.to_list ctx in

  Alcotest.(check int) "same length" (List.length pairs) (List.length pairs');

  (* Check all keys are present *)
  List.iter (fun (key, _) ->
    match Flo_context.get key ctx with
    | Some _ -> ()
    | None -> Alcotest.fail (Printf.sprintf "key %s not found" key)
  ) pairs

(* Test with_context sets fiber-local context *)
let test_with_context () =
  Eio_main.run @@ fun _env ->
    let ctx = Flo_context.empty in
    let ctx = Flo_context.add "test_key" (Value.string "test_value") ctx in

    (* Outside with_context, no context *)
    (match Flo_context.get_current () with
     | None -> ()
     | Some _ -> Alcotest.fail "should have no context outside");

    (* Inside with_context, context is set *)
    Flo_context.with_context ctx (fun () ->
      let current_ctx = Flo_context.get_current () in
      Alcotest.(check bool) "has context" true (Option.is_some current_ctx);
      match current_ctx with
      | Some ctx ->
          let v = Flo_context.get "test_key" ctx in
          Alcotest.(check bool) "has test_key" true (Option.is_some v);
          (match v with
           | Some value -> Alcotest.(check string) "context set" "\"test_value\"" (Value.to_string value)
           | None -> ())
      | None -> ()
    );

    (* After with_context, no context again *)
    (match Flo_context.get_current () with
     | None -> ()
     | Some _ -> Alcotest.fail "should have no context after")

(* Test nested with_context merges contexts *)
let test_nested_with_context () =
  Eio_main.run @@ fun _env ->
    let ctx1 = Flo_context.empty in
    let ctx1 = Flo_context.add "outer" (Value.string "outer_value") ctx1 in

    let ctx2 = Flo_context.empty in
    let ctx2 = Flo_context.add "inner" (Value.string "inner_value") ctx2 in

    Flo_context.with_context ctx1 (fun () ->
      (* Outer context *)
      let current = Flo_context.get_current () in
      Alcotest.(check bool) "has outer context" true (Option.is_some current);
      (match current with
       | Some ctx ->
           let has_outer = Option.is_some (Flo_context.get "outer" ctx) in
           Alcotest.(check bool) "has outer key" true has_outer
       | None -> ());

      (* Nested context merges with parent *)
      Flo_context.with_context ctx2 (fun () ->
        let current = Flo_context.get_current () in
        Alcotest.(check bool) "has nested context" true (Option.is_some current);
        (match current with
         | Some ctx ->
             (* Should have both outer and inner *)
             let has_outer = Option.is_some (Flo_context.get "outer" ctx) in
             let has_inner = Option.is_some (Flo_context.get "inner" ctx) in
             Alcotest.(check bool) "has outer in nested" true has_outer;
             Alcotest.(check bool) "has inner in nested" true has_inner
         | None -> ())
      )
    )

(* Test nested with_context precedence *)
let test_nested_context_precedence () =
  Eio_main.run @@ fun _env ->
    let ctx1 = Flo_context.empty in
    let ctx1 = Flo_context.add "key" (Value.string "outer") ctx1 in

    let ctx2 = Flo_context.empty in
    let ctx2 = Flo_context.add "key" (Value.string "inner") ctx2 in

    Flo_context.with_context ctx1 (fun () ->
      Flo_context.with_context ctx2 (fun () ->
        let current = Flo_context.get_current () in
        Alcotest.(check bool) "has context" true (Option.is_some current);
        (match current with
         | Some ctx ->
             (* Inner context takes precedence *)
             let v = Flo_context.get "key" ctx in
             Alcotest.(check bool) "has key" true (Option.is_some v);
             (match v with
              | Some value -> Alcotest.(check string) "inner precedence" "\"inner\"" (Value.to_string value)
              | None -> ())
         | None -> ())
      )
    )

(* Test context propagation to child fibers *)
let test_fiber_propagation () =
  Eio_main.run @@ fun _env ->
    let ctx = Flo_context.empty in
    let ctx = Flo_context.add "parent_key" (Value.string "parent_value") ctx in

    let result = ref None in

    Flo_context.with_context ctx (fun () ->
      (* Spawn child fiber *)
      Eio.Fiber.both
        (fun () ->
          (* Child fiber should inherit parent context *)
          match Flo_context.get_current () with
          | Some child_ctx ->
              (match Flo_context.get "parent_key" child_ctx with
               | Some v -> result := Some (Value.to_string v)
               | None -> result := Some "key_not_found")
          | None -> result := Some "no_context"
        )
        (fun () -> ())
    );

    match !result with
    | Some s -> Alcotest.(check string) "child inherits context" "\"parent_value\"" s
    | None -> Alcotest.fail "result not set"

(* Test multiple concurrent fibers with different contexts *)
let test_concurrent_contexts () =
  Eio_main.run @@ fun env ->
    let result1 = ref None in
    let result2 = ref None in

    Eio.Fiber.both
      (fun () ->
        let ctx = Flo_context.add "id" (Value.string "fiber1") Flo_context.empty in
        Flo_context.with_context ctx (fun () ->
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.001;
          match Flo_context.get_current () with
          | Some c -> result1 := Flo_context.get "id" c
          | None -> ()
        )
      )
      (fun () ->
        let ctx = Flo_context.add "id" (Value.string "fiber2") Flo_context.empty in
        Flo_context.with_context ctx (fun () ->
          Eio.Time.sleep (Eio.Stdenv.clock env) 0.001;
          match Flo_context.get_current () with
          | Some c -> result2 := Flo_context.get "id" c
          | None -> ()
        )
      );

    match (!result1, !result2) with
    | (Some v1, Some v2) ->
        Alcotest.(check string) "fiber1 context" "\"fiber1\"" (Value.to_string v1);
        Alcotest.(check string) "fiber2 context" "\"fiber2\"" (Value.to_string v2)
    | _ -> Alcotest.fail "results not set"

let () =
  let open Alcotest in
  run "Flo_context" [
    "operations", [
      test_case "empty context" `Quick test_empty;
      test_case "add and get" `Quick test_add_get;
      test_case "add replaces existing key" `Quick test_add_replaces;
      test_case "merge contexts" `Quick test_merge;
      test_case "to_list and of_list" `Quick test_to_list_of_list;
    ];
    "fiber_local", [
      test_case "with_context sets fiber-local context" `Quick test_with_context;
      test_case "nested with_context merges" `Quick test_nested_with_context;
      test_case "nested context precedence" `Quick test_nested_context_precedence;
      test_case "context propagates to child fibers" `Quick test_fiber_propagation;
      test_case "concurrent fibers have separate contexts" `Quick test_concurrent_contexts;
    ];
  ]
