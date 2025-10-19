(* PPX Flo - Compile-time enhancements for Flo logging library
 *
 * This PPX provides three main features:
 * 1. Automatic location capture: let%log.info "msg"
 * 2. Structured logging syntax: [%log.info "msg" ~field:value]
 * 3. Span annotations: let%span "name" func = ...
 *)

open Ppxlib

(* ========================================================================
   Helper Functions
   ======================================================================== *)

(* Extract module name from file path *)
let module_name_of_file file =
  let basename = Filename.basename file in
  let without_ext = Filename.chop_extension basename in
  String.capitalize_ascii without_ext

(* Extract location information from Ppxlib location and code path *)
let location_expr_full ~loc _code_path =
  let file = loc.loc_start.pos_fname in
  let line = loc.loc_start.pos_lnum in
  let column = loc.loc_start.pos_cnum - loc.loc_start.pos_bol in
  let module_name = module_name_of_file file in

  (* Note: Function name extraction from code_path requires deeper ppxlib integration
     Will be implemented in a future phase if needed *)
  [%expr
    Location.make_full
      ~file:[%e Ast_builder.Default.estring ~loc file]
      ~line:[%e Ast_builder.Default.eint ~loc line]
      ~column:[%e Ast_builder.Default.eint ~loc column]
      ~module_name:[%e Ast_builder.Default.estring ~loc module_name]
      ()
  ]

(* Simple location expression without code path (for backward compat) *)
let location_expr ~loc =
  let file = loc.loc_start.pos_fname in
  let line = loc.loc_start.pos_lnum in
  let column = loc.loc_start.pos_cnum - loc.loc_start.pos_bol in
  let module_name = module_name_of_file file in
  [%expr
    Location.make_full
      ~file:[%e Ast_builder.Default.estring ~loc file]
      ~line:[%e Ast_builder.Default.eint ~loc line]
      ~column:[%e Ast_builder.Default.eint ~loc column]
      ~module_name:[%e Ast_builder.Default.estring ~loc module_name]
      ()
  ]

(* Convert OCaml expression to Value.t based on type inference *)
let rec value_of_expr ~loc expr =
  match expr.pexp_desc with
  (* String literals *)
  | Pexp_constant (Pconst_string (s, _, _)) ->
      [%expr Value.String [%e Ast_builder.Default.estring ~loc s]]

  (* Integer literals *)
  | Pexp_constant (Pconst_integer (i, _)) ->
      [%expr Value.Int (Int64.of_int [%e Ast_builder.Default.eint ~loc (int_of_string i)])]

  (* Float literals *)
  | Pexp_constant (Pconst_float (f, _)) ->
      [%expr Value.Float [%e Ast_builder.Default.efloat ~loc f]]

  (* Boolean true *)
  | Pexp_construct ({ txt = Lident "true"; _ }, _) ->
      [%expr Value.Bool true]

  (* Boolean false *)
  | Pexp_construct ({ txt = Lident "false"; _ }, _) ->
      [%expr Value.Bool false]

  (* Empty list [] *)
  | Pexp_construct ({ txt = Lident "[]"; _ }, _) ->
      [%expr Value.Array []]

  (* List with elements [a; b; c] *)
  | Pexp_construct ({ txt = Lident "::"; _ }, Some { pexp_desc = Pexp_tuple [hd; tl]; _ }) ->
      (* Build list recursively *)
      let hd_value = value_of_expr ~loc:hd.pexp_loc hd in
      let tl_value = value_of_expr ~loc:tl.pexp_loc tl in
      [%expr
        match [%e tl_value] with
        | Value.Array arr -> Value.Array ([%e hd_value] :: arr)
        | _ -> Value.Array [[%e hd_value]]
      ]

  (* List literal using [...] syntax *)
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident "::"; _ }; _ }, _) ->
      (* This handles explicit list construction *)
      expr

  (* Tuple (converts to Object with numeric keys) *)
  | Pexp_tuple elements ->
      let indexed_elements = List.mapi (fun i elem ->
        let key = string_of_int i in
        let value = value_of_expr ~loc:elem.pexp_loc elem in
        [%expr ([%e Ast_builder.Default.estring ~loc key], [%e value])]
      ) elements in
      let obj_list = Ast_builder.Default.elist ~loc indexed_elements in
      [%expr Value.Object [%e obj_list]]

  (* Record literals {field1 = value1; field2 = value2} *)
  | Pexp_record (fields, _) ->
      let field_exprs = List.map (fun (field_lid, field_expr) ->
        let field_name = match field_lid.txt with
          | Lident name -> name
          | Ldot (_, name) -> name
          | Lapply _ -> "unknown"
        in
        let value = value_of_expr ~loc:field_expr.pexp_loc field_expr in
        [%expr ([%e Ast_builder.Default.estring ~loc field_name], [%e value])]
      ) fields in
      let obj_list = Ast_builder.Default.elist ~loc field_exprs in
      [%expr Value.Object [%e obj_list]]

  (* All other cases - pass through unchanged for runtime evaluation *)
  | _ -> expr

(* ========================================================================
   Feature 1: Automatic Location Capture
   let%log.info "message" -> Flo.info ~location:... "message"
   ======================================================================== *)

(* Extension for let%log.<level> style - captures location automatically *)
let expand_let_log_extension level ~ctxt expr =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let code_path = Expansion_context.Extension.code_path ctxt in

  (* Build the location expression with full context *)
  let loc_expr = location_expr_full ~loc code_path in

  (* Build call to Flo.<level> ~location:... message *)
  let flo_func =
    Ast_builder.Default.pexp_ident ~loc
      (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", level)))
  in

  (* Add location as first labeled argument *)
  Ast_builder.Default.pexp_apply ~loc flo_func [
    (Labelled "location", loc_expr);
    (Nolabel, expr)
  ]

(* ========================================================================
   Feature 2: Structured Logging Syntax
   [%log.info "msg" ~field:value] -> Flo.info_fields "msg" ~fields:[...]
   ======================================================================== *)

let expand_structured_log ~ctxt level message labeled_args =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let code_path = Expansion_context.Extension.code_path ctxt in

  (* Convert labeled arguments to field list *)
  let fields =
    List.map (fun (label, expr) ->
      let field_name =
        match label with
        | Labelled name | Optional name -> name
        | Nolabel ->
            Location.raise_errorf ~loc:(expr.pexp_loc)
              "ppx_flo: fields must be labeled arguments"
      in
      let value_expr = value_of_expr ~loc:expr.pexp_loc expr in
      [%expr ([%e Ast_builder.Default.estring ~loc field_name], [%e value_expr])]
    ) labeled_args
  in

  let fields_list =
    Ast_builder.Default.elist ~loc fields
  in

  (* Build location expression *)
  let loc_expr = location_expr_full ~loc code_path in

  (* Build the call to Flo.<level>_fields with location *)
  let func_name = level ^ "_fields" in
  let func_ident =
    Ast_builder.Default.pexp_ident ~loc
      (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", func_name)))
  in
  Ast_builder.Default.pexp_apply ~loc func_ident [
    (Labelled "location", loc_expr);
    (Nolabel, message);
    (Labelled "fields", fields_list)
  ]

(* ========================================================================
   Feature 3: Span Annotation
   let%span "name" func args = body ->
   let func args = Flo_structured.in_span "name" (fun _span -> body)
   ======================================================================== *)

let expand_span_annotation ~ctxt span_name vb =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in

  (* For now, just wrap the entire expression body in a span *)
  let wrapped_body =
    Ast_builder.Default.pexp_apply ~loc
      (Ast_builder.Default.pexp_ident ~loc
         (Ast_builder.Default.Located.mk ~loc
            (Ldot (Ldot (Lident "Flo_structured", "in_span"), "in_span"))))
      [
        (Nolabel, span_name);
        (Nolabel, [%expr fun _span -> [%e vb.pvb_expr]]);
      ]
  in

  { vb with pvb_expr = wrapped_body }

(* ========================================================================
   PPX Extension Points Registration
   ======================================================================== *)

(* Register extension for [%log.info ...] style - with location capture *)
let bracket_log_extension level =
  Extension.V3.declare
    ("log." ^ level)
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    (fun ~ctxt expr ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      let code_path = Expansion_context.Extension.code_path ctxt in

      match expr.pexp_desc with
      | Pexp_apply (message, labeled_args) when List.length labeled_args > 0 ->
          (* Structured logging with fields *)
          expand_structured_log ~ctxt level message labeled_args
      | _ ->
          (* Simple message with automatic location capture *)
          let loc_expr = location_expr_full ~loc code_path in
          let func_ident =
            Ast_builder.Default.pexp_ident ~loc
              (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", level)))
          in
          Ast_builder.Default.pexp_apply ~loc func_ident [
            (Labelled "location", loc_expr);
            (Nolabel, expr)
          ]
    )

(* Register all [%log.level] and let%log.level extensions
   Note: Both [%...] and let%... use the same extension names, but
   ppxlib handles them differently based on the AST context where they appear *)
let log_extensions =
  List.map bracket_log_extension
    ["trace"; "debug"; "info"; "success"; "warn"; "error"; "fatal"]

(* Note: let%span extension will be implemented in Phase 1.4
   For now, focusing on [%log.level] extensions which are more critical *)

(* ========================================================================
   PPX Driver Registration
   ======================================================================== *)

let () =
  Driver.register_transformation
    "ppx_flo"
    ~extensions:log_extensions
