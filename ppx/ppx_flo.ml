(* PPX Flo - Compile-time enhancements for Flo logging library
 *
 * This PPX provides:
 * 1. Automatic location capture: let%log.info "msg"
 * 2. Structured logging syntax: [%log.info "msg" ~field:value]
 * 3. Span annotations: let%span "name" func = ...
 * 4. Namespace support: [@flo.namespace "..."] and automatic module path extraction
 *)

open Ppxlib

(* ========================================================================
   Helper Functions
   ======================================================================== *)

(* Global reference to store current module namespace *)
let current_namespace : string option ref = ref None

(* Extract module name from file path *)
let module_name_of_file file =
  let basename = Filename.basename file in
  let without_ext = Filename.chop_extension basename in
  String.capitalize_ascii without_ext

(* Flatten a longident to a list of strings *)
let rec flatten_longident = function
  | Lident s -> [s]
  | Ldot (lid, s) -> flatten_longident lid @ [s]
  | Lapply (l1, l2) -> flatten_longident l1 @ flatten_longident l2

(* Convert module path to namespace string
   E.g., MyLib.Database.Pool -> "mylib.database.pool" *)
let module_path_to_namespace path =
  let parts = flatten_longident path in
  let lowercase_parts = List.map String.lowercase_ascii parts in
  String.concat "." lowercase_parts

(* Extract namespace from attributes *)
let namespace_from_attributes attrs =
  List.find_map (fun attr ->
    match attr.attr_name.txt with
    | "flo.namespace" ->
        (match attr.attr_payload with
         | PStr [{pstr_desc = Pstr_eval ({pexp_desc = Pexp_constant (Pconst_string (ns, _, _)); _}, _); _}] ->
             Some ns
         | _ -> None)
    | _ -> None
  ) attrs

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

  (* All other cases - use runtime auto-conversion *)
  | _ ->
      (* For variables and complex expressions, use the runtime auto converter *)
      [%expr Flo_ppx_runtime.auto [%e expr]]

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

  (* Determine which function to call based on namespace *)
  match !current_namespace with
  | None ->
      (* No namespace - use regular Flo.<level> *)
      let flo_func =
        Ast_builder.Default.pexp_ident ~loc
          (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", level)))
      in
      (* Add location as first labeled argument *)
      Ast_builder.Default.pexp_apply ~loc flo_func [
        (Labelled "location", loc_expr);
        (Nolabel, expr)
      ]
  | Some namespace ->
      (* Has namespace - use Flo.scoped_<level> *)
      let func_name = "scoped_" ^ level in
      let flo_func =
        Ast_builder.Default.pexp_ident ~loc
          (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", func_name)))
      in
      (* Call: Flo.scoped_<level> namespace ~location:... message *)
      Ast_builder.Default.pexp_apply ~loc flo_func [
        (Nolabel, Ast_builder.Default.estring ~loc namespace);
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

  (* Determine which function to call based on namespace *)
  match !current_namespace with
  | None ->
      (* No namespace - use Flo.<level>_fields *)
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
  | Some namespace ->
      (* Has namespace - use Flo.scoped_<level>_fields *)
      let func_name = "scoped_" ^ level ^ "_fields" in
      let func_ident =
        Ast_builder.Default.pexp_ident ~loc
          (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", func_name)))
      in
      Ast_builder.Default.pexp_apply ~loc func_ident [
        (Nolabel, Ast_builder.Default.estring ~loc namespace);
        (Labelled "location", loc_expr);
        (Nolabel, message);
        (Labelled "fields", fields_list)
      ]

(* ========================================================================
   Feature 3: Span Annotation
   let%span "name" func args = body ->
   let func args = Flo_structured.in_span "name" (fun _span -> body)
   ======================================================================== *)

let expand_span_annotation ~ctxt span_name_expr vb =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in

  (* The span name must be a string literal or we derive it from function name *)
  let span_name = match span_name_expr.pexp_desc with
    | Pexp_constant (Pconst_string (s, _, _)) -> s
    | _ ->
        (* If not a string literal, use the function name from the pattern *)
        match vb.pvb_pat.ppat_desc with
        | Ppat_var { txt; _ } -> txt
        | _ -> "unnamed_span"
  in

  (* Simply wrap the entire expression in a span *)
  let wrapped_body = [%expr
    Flo_structured.in_span [%e Ast_builder.Default.estring ~loc span_name]
      (fun _span -> [%e vb.pvb_expr])
  ] in

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

(* For let%span, we'll use a simpler approach with expression extension
   Usage: let%span process_order order_id = ... *)
let span_expression_extension =
  Extension.V3.declare
    "span"
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    (fun ~ctxt expr ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      (* Wrap the expression in a span using the expression itself as name *)
      [%expr
        Flo_structured.in_span "span"
          (fun _span -> [%e expr])
      ]
    )

(* ========================================================================
   Feature 4a: Explicit Scoped Logging Extension
   [%log.scoped "namespace" level "message"]
   ======================================================================== *)

(* Extension for [%log.scoped "namespace" level "message"] *)
let scoped_extension level =
  Extension.V3.declare
    ("log.scoped." ^ level)
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    (fun ~ctxt expr ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      let code_path = Expansion_context.Extension.code_path ctxt in

      (* Parse: should be application with namespace as first arg *)
      match expr.pexp_desc with
      | Pexp_apply (namespace_expr, [(Nolabel, message_expr)]) ->
          (* [%log.scoped.info "namespace" "message"] *)
          let loc_expr = location_expr_full ~loc code_path in
          let func_name = "scoped_" ^ level in
          let func_ident =
            Ast_builder.Default.pexp_ident ~loc
              (Ast_builder.Default.Located.mk ~loc (Ldot (Lident "Flo", func_name)))
          in
          Ast_builder.Default.pexp_apply ~loc func_ident [
            (Nolabel, namespace_expr);
            (Labelled "location", loc_expr);
            (Nolabel, message_expr)
          ]
      | _ ->
          Location.raise_errorf ~loc
            "ppx_flo: [%%log.scoped.%s] expects: [%%log.scoped.%s \"namespace\" \"message\"]"
            level level
    )

let scoped_extensions =
  List.map scoped_extension
    ["trace"; "debug"; "info"; "success"; "warn"; "error"; "fatal"]

(* ========================================================================
   Feature 4b: Namespace Scope Extension
   let%log.namespace "mylib" in expr -> Flo.with_namespace "mylib" (fun () -> expr)
   ======================================================================== *)

let namespace_extension =
  Extension.V3.declare
    "log.namespace"
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    (fun ~ctxt _expr ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in

      (* Note: let%log.namespace requires a different PPX approach
         For now, we recommend using [@@@flo.namespace] attribute instead
         or Flo.with_namespace for runtime scoping *)

      Location.raise_errorf ~loc
        "ppx_flo: let%%log.namespace is not yet fully implemented. Use [@@@flo.namespace] attribute or Flo.with_namespace instead."
    )

(* ========================================================================
   Feature 4: Namespace Attributes and Automatic Extraction
   [@flo.namespace "mylib"] or automatic from module path
   ======================================================================== *)

(* Mapper to handle structure-level namespace attributes and extension expansion *)
let namespace_mapper =
  object(self)
    inherit Ast_traverse.map as super

    method! structure str =
      (* Look for [@@@flo.namespace "..."] attribute at structure level *)
      let namespace_attr =
        List.find_map (fun item ->
          match item.pstr_desc with
          | Pstr_attribute attr ->
              namespace_from_attributes [attr]
          | _ -> None
        ) str
      in

      (* If namespace attribute found, set it for processing *)
      (match namespace_attr with
       | Some ns ->
           let old_ns = !current_namespace in
           current_namespace := Some ns;
           let result = super#structure str in
           current_namespace := old_ns;  (* Restore after processing *)
           result
       | None ->
           super#structure str)

    method! structure_item item =
      (* Check for module-level namespace attributes *)
      match item.pstr_desc with
      | Pstr_module mb ->
          (* Check module binding for [@flo.namespace "..."] *)
          let explicit_ns = namespace_from_attributes mb.pmb_attributes in
          (match explicit_ns with
           | Some ns ->
               (* Explicit namespace attribute found *)
               let old_ns = !current_namespace in
               current_namespace := Some ns;
               let result = super#structure_item item in
               current_namespace := old_ns;
               result
           | None ->
               (* Try automatic namespace from module name *)
               (match mb.pmb_name.txt with
                | Some module_name ->
                    let auto_namespace = match !current_namespace with
                      | Some parent_ns ->
                          (* Append to parent namespace *)
                          parent_ns ^ "." ^ (String.lowercase_ascii module_name)
                      | None ->
                          (* Use module name as namespace *)
                          String.lowercase_ascii module_name
                    in
                    (* Set the namespace for this module's contents *)
                    let old_ns = !current_namespace in
                    current_namespace := Some auto_namespace;
                    let result = super#structure_item item in
                    current_namespace := old_ns;
                    result
                | None ->
                    (* Anonymous module, process normally *)
                    super#structure_item item))
      | _ ->
          super#structure_item item

    (* Also need to handle extension points here to capture namespace context *)
    method! expression expr =
      match expr.pexp_desc with
      | Pexp_extension ({txt = ext_name; loc = ext_loc}, payload) ->
          (* Check if this is a log extension *)
          let log_levels = ["log.trace"; "log.debug"; "log.info"; "log.success";
                           "log.warn"; "log.error"; "log.fatal"] in
          if List.mem ext_name log_levels then
            let level = String.sub ext_name 4 (String.length ext_name - 4) in  (* Remove "log." prefix *)
            (match payload with
             | PStr [{pstr_desc = Pstr_eval ({pexp_desc = Pexp_apply (message, labeled_args); _}, _); _}]
               when List.length labeled_args > 0 ->
                 (* Structured logging with fields *)
                 let fields =
                   List.map (fun (label, field_expr) ->
                     let field_name =
                       match label with
                       | Labelled name | Optional name -> name
                       | Nolabel ->
                           Location.raise_errorf ~loc:(field_expr.pexp_loc)
                             "ppx_flo: fields must be labeled arguments"
                     in
                     let value_expr = value_of_expr ~loc:field_expr.pexp_loc field_expr in
                     let name_expr = Ast_builder.Default.estring ~loc:ext_loc field_name in
                     Ast_builder.Default.pexp_tuple ~loc:ext_loc [name_expr; value_expr]
                   ) labeled_args
                 in
                 let fields_list = Ast_builder.Default.elist ~loc:ext_loc fields in
                 let loc_expr = location_expr ~loc:ext_loc in

                 (match !current_namespace with
                  | None ->
                      (* No namespace - use Flo.<level>_fields *)
                      let func_name = level ^ "_fields" in
                      let func_ident =
                        Ast_builder.Default.pexp_ident ~loc:ext_loc
                          (Ast_builder.Default.Located.mk ~loc:ext_loc (Ldot (Lident "Flo", func_name)))
                      in
                      Ast_builder.Default.pexp_apply ~loc:ext_loc func_ident [
                        (Labelled "location", loc_expr);
                        (Nolabel, self#expression message);
                        (Labelled "fields", fields_list)
                      ]
                  | Some namespace ->
                      (* Has namespace - use Flo.scoped_<level>_fields *)
                      let func_name = "scoped_" ^ level ^ "_fields" in
                      let func_ident =
                        Ast_builder.Default.pexp_ident ~loc:ext_loc
                          (Ast_builder.Default.Located.mk ~loc:ext_loc (Ldot (Lident "Flo", func_name)))
                      in
                      Ast_builder.Default.pexp_apply ~loc:ext_loc func_ident [
                        (Nolabel, Ast_builder.Default.estring ~loc:ext_loc namespace);
                        (Labelled "location", loc_expr);
                        (Nolabel, self#expression message);
                        (Labelled "fields", fields_list)
                      ])

             | PStr [{pstr_desc = Pstr_eval (message_expr, _); _}] ->
                 (* Simple message - Build location expression *)
                 let loc_expr = location_expr ~loc:ext_loc in

                 (* Determine which function to call based on namespace *)
                 (match !current_namespace with
                  | None ->
                      (* No namespace - use regular Flo.<level> *)
                      let flo_func =
                        Ast_builder.Default.pexp_ident ~loc:ext_loc
                          (Ast_builder.Default.Located.mk ~loc:ext_loc (Ldot (Lident "Flo", level)))
                      in
                      Ast_builder.Default.pexp_apply ~loc:ext_loc flo_func [
                        (Labelled "location", loc_expr);
                        (Nolabel, self#expression message_expr)
                      ]
                  | Some namespace ->
                      (* Has namespace - use Flo.scoped_<level> *)
                      let func_name = "scoped_" ^ level in
                      let flo_func =
                        Ast_builder.Default.pexp_ident ~loc:ext_loc
                          (Ast_builder.Default.Located.mk ~loc:ext_loc (Ldot (Lident "Flo", func_name)))
                      in
                      Ast_builder.Default.pexp_apply ~loc:ext_loc flo_func [
                        (Nolabel, Ast_builder.Default.estring ~loc:ext_loc namespace);
                        (Labelled "location", loc_expr);
                        (Nolabel, self#expression message_expr)
                      ])
             | _ ->
                 super#expression expr)
          else
            super#expression expr
      | _ ->
          super#expression expr
  end

(* ========================================================================
   PPX Driver Registration
   ======================================================================== *)

let () =
  Driver.register_transformation
    "ppx_flo"
    (* Register extensions: span, scoped logging, and namespace scope *)
    ~extensions:([span_expression_extension; namespace_extension] @ scoped_extensions)
    (* Impl mapper handles [%log...] extension points with namespace awareness *)
    ~impl:namespace_mapper#structure
