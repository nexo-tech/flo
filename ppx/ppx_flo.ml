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

(* Extract location information from Ppxlib location *)
let location_expr ~loc =
  let file = loc.loc_start.pos_fname in
  let line = loc.loc_start.pos_lnum in
  let column = loc.loc_start.pos_cnum - loc.loc_start.pos_bol in
  [%expr
    Location.make
      ~file:[%e Ast_builder.Default.estring ~loc file]
      ~line:[%e Ast_builder.Default.eint ~loc line]
      ~column:[%e Ast_builder.Default.eint ~loc column]
      ()
  ]

(* Convert OCaml expression to Value.t based on type inference *)
let value_of_expr ~loc expr =
  match expr.pexp_desc with
  | Pexp_constant (Pconst_string (s, _, _)) ->
      [%expr Value.String [%e Ast_builder.Default.estring ~loc s]]
  | Pexp_constant (Pconst_integer (i, _)) ->
      [%expr Value.Int (Int64.of_int [%e Ast_builder.Default.eint ~loc (int_of_string i)])]
  | Pexp_constant (Pconst_float (f, _)) ->
      [%expr Value.Float [%e Ast_builder.Default.efloat ~loc f]]
  | Pexp_construct ({ txt = Lident "true"; _ }, _) ->
      [%expr Value.Bool true]
  | Pexp_construct ({ txt = Lident "false"; _ }, _) ->
      [%expr Value.Bool false]
  | Pexp_construct ({ txt = Lident "[]"; _ }, _) ->
      [%expr Value.Array []]
  | _ ->
      (* For complex expressions, wrap in a runtime conversion *)
      expr

(* ========================================================================
   Feature 1: Automatic Location Capture
   let%log.info "message" -> Flo.info ~location:... "message"
   ======================================================================== *)

let expand_log_extension ~ctxt payload =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in

  match payload with
  | PStr [{ pstr_desc = Pstr_eval (expr, _); _ }] -> begin
      match expr.pexp_desc with
      | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident level; _ }; _ }, args) ->
          (* Build the location expression *)
          let loc_expr = location_expr ~loc in

          (* Reconstruct the call with location parameter *)
          let flo_func =
            Ast_builder.Default.pexp_ident ~loc
              (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", level)))
          in

          (* Add ~location parameter to arguments *)
          let new_args = args @ [(Labelled "location", loc_expr)] in
          Ast_builder.Default.pexp_apply ~loc flo_func new_args

      | _ ->
          Location.raise_errorf ~loc
            "ppx_flo: let%%log extension expects a logging function call"
    end
  | _ ->
      Location.raise_errorf ~loc
        "ppx_flo: let%%log extension expects an expression"

(* ========================================================================
   Feature 2: Structured Logging Syntax
   [%log.info "msg" ~field:value] -> Flo.info_fields "msg" ~fields:[...]
   ======================================================================== *)

let expand_structured_log ~ctxt level message labeled_args =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in

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

  (* Build the call to Flo.<level>_fields *)
  let func_name = level ^ "_fields" in
  let func_ident =
    Ast_builder.Default.pexp_ident ~loc
      (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", func_name)))
  in
  Ast_builder.Default.pexp_apply ~loc func_ident [
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

(* Register extension for [%log.info ...] style *)
let structured_log_extension level =
  Extension.V3.declare
    ("log." ^ level)
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    (fun ~ctxt expr ->
      match expr.pexp_desc with
      | Pexp_apply (message, labeled_args) when List.length labeled_args > 0 ->
          expand_structured_log ~ctxt level message labeled_args
      | _ ->
          (* Fallback: simple message without structured fields *)
          let loc = Expansion_context.Extension.extension_point_loc ctxt in
          let func_ident =
            Ast_builder.Default.pexp_ident ~loc
              (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", level)))
          in
          Ast_builder.Default.pexp_apply ~loc func_ident [(Nolabel, expr)]
    )

(* Register all log level extensions *)
let log_extensions =
  List.map structured_log_extension
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
