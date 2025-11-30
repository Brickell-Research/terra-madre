//// HCL Renderer
////
//// Renders HCL AST types to properly formatted HCL text.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import terra_madre/hcl.{
  type BinaryOperator, type Block, type Expr, type ForClause, type MapKey,
  type SplatType, type TemplateDirective, type TemplatePart, type UnaryOperator,
}
import terra_madre/terraform.{
  type Config, type DataSource, type Locals, type Module, type Output,
  type Provider, type ProviderRequirement, type Resource, type TerraformSettings,
  type Variable,
}

// ============================================================================
// EXPRESSION RENDERING
// ============================================================================

/// Render an expression to HCL text.
pub fn render_expr(expr: Expr) -> String {
  case expr {
    hcl.StringLiteral(s) -> render_string(s)
    hcl.IntLiteral(n) -> int.to_string(n)
    hcl.FloatLiteral(f) -> float.to_string(f)
    hcl.BoolLiteral(b) ->
      case b {
        True -> "true"
        False -> "false"
      }
    hcl.NullLiteral -> "null"
    hcl.Identifier(name) -> name
    hcl.GetAttr(base, attr) -> render_expr(base) <> "." <> attr
    hcl.Index(base, index) ->
      render_expr(base) <> "[" <> render_expr(index) <> "]"
    hcl.ListExpr(items) -> render_list(items)
    hcl.MapExpr(pairs) -> render_map(pairs)
    hcl.TemplateExpr(parts) -> render_template(parts)
    hcl.Heredoc(marker, indent_strip, content) ->
      render_heredoc(marker, indent_strip, content)
    hcl.FunctionCall(name, args, expand_final) ->
      render_function_call(name, args, expand_final)
    hcl.UnaryOp(op, operand) -> render_unary(op, operand)
    hcl.BinaryOp(left, op, right) -> render_binary(left, op, right)
    hcl.Conditional(cond, true_expr, false_expr) ->
      render_conditional(cond, true_expr, false_expr)
    hcl.ForExpr(clause) -> render_for_expr(clause)
    hcl.Splat(base, splat_type) -> render_splat(base, splat_type)
  }
}

fn render_string(s: String) -> String {
  "\"" <> escape_string(s) <> "\""
}

fn escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn render_list(items: List(Expr)) -> String {
  case items {
    [] -> "[]"
    _ -> {
      let rendered = list.map(items, render_expr)
      "[" <> string.join(rendered, ", ") <> "]"
    }
  }
}

fn render_map(pairs: List(#(MapKey, Expr))) -> String {
  case pairs {
    [] -> "{}"
    _ -> {
      let rendered =
        list.map(pairs, fn(pair) {
          let #(key, value) = pair
          let key_str = case key {
            hcl.IdentKey(name) -> name
            hcl.ExprKey(expr) -> "(" <> render_expr(expr) <> ")"
          }
          key_str <> " = " <> render_expr(value)
        })
      "{ " <> string.join(rendered, ", ") <> " }"
    }
  }
}

fn render_template(parts: List(TemplatePart)) -> String {
  "\"" <> render_template_parts(parts) <> "\""
}

fn render_template_parts(parts: List(TemplatePart)) -> String {
  list.map(parts, render_template_part) |> string.join("")
}

fn render_template_part(part: TemplatePart) -> String {
  case part {
    hcl.LiteralPart(s) -> escape_template_literal(s)
    hcl.Interpolation(expr) -> "${" <> render_expr(expr) <> "}"
    hcl.Directive(directive) -> render_template_directive(directive)
  }
}

fn escape_template_literal(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
  |> string.replace("${", "$${")
  |> string.replace("%{", "%%{")
}

fn render_template_directive(directive: TemplateDirective) -> String {
  case directive {
    hcl.IfDirective(condition, true_branch, false_branch) -> {
      let if_part = "%{ if " <> render_expr(condition) <> " }"
      let true_part = render_template_parts(true_branch)
      let else_part = case false_branch {
        [] -> ""
        _ -> "%{ else }" <> render_template_parts(false_branch)
      }
      let endif_part = "%{ endif }"
      if_part <> true_part <> else_part <> endif_part
    }
    hcl.ForDirective(key_var, value_var, collection, body) -> {
      let vars = case key_var {
        Some(k) -> k <> ", " <> value_var
        None -> value_var
      }
      let for_part =
        "%{ for " <> vars <> " in " <> render_expr(collection) <> " }"
      let body_part = render_template_parts(body)
      let endfor_part = "%{ endfor }"
      for_part <> body_part <> endfor_part
    }
  }
}

fn render_heredoc(
  marker: String,
  indent_strip: Bool,
  content: List(TemplatePart),
) -> String {
  let opener = case indent_strip {
    True -> "<<-"
    False -> "<<"
  }
  opener <> marker <> "\n" <> render_heredoc_content(content) <> marker
}

fn render_heredoc_content(parts: List(TemplatePart)) -> String {
  list.map(parts, render_heredoc_part) |> string.join("")
}

fn render_heredoc_part(part: TemplatePart) -> String {
  case part {
    hcl.LiteralPart(s) ->
      s
      |> string.replace("${", "$${")
      |> string.replace("%{", "%%{")
    hcl.Interpolation(expr) -> "${" <> render_expr(expr) <> "}"
    hcl.Directive(directive) -> render_template_directive(directive)
  }
}

fn render_function_call(
  name: String,
  args: List(Expr),
  expand_final: Bool,
) -> String {
  case args {
    [] -> name <> "()"
    _ -> {
      let rendered = list.map(args, render_expr)
      let args_str = string.join(rendered, ", ")
      let final_str = case expand_final {
        True -> "..."
        False -> ""
      }
      name <> "(" <> args_str <> final_str <> ")"
    }
  }
}

fn render_unary(op: UnaryOperator, operand: Expr) -> String {
  let op_str = case op {
    hcl.Negate -> "-"
    hcl.Not -> "!"
  }
  let operand_str = case operand {
    hcl.BinaryOp(_, _, _) | hcl.Conditional(_, _, _) ->
      "(" <> render_expr(operand) <> ")"
    _ -> render_expr(operand)
  }
  op_str <> operand_str
}

fn render_binary(left: Expr, op: BinaryOperator, right: Expr) -> String {
  let op_str = case op {
    hcl.Add -> " + "
    hcl.Subtract -> " - "
    hcl.Multiply -> " * "
    hcl.Divide -> " / "
    hcl.Modulo -> " % "
    hcl.Equal -> " == "
    hcl.NotEqual -> " != "
    hcl.LessThan -> " < "
    hcl.LessEq -> " <= "
    hcl.GreaterThan -> " > "
    hcl.GreaterEq -> " >= "
    hcl.And -> " && "
    hcl.Or -> " || "
  }
  let left_str = render_expr_with_parens(left, op, True)
  let right_str = render_expr_with_parens(right, op, False)
  left_str <> op_str <> right_str
}

fn render_expr_with_parens(expr: Expr, parent_op: BinaryOperator, is_left: Bool) -> String {
  case expr {
    hcl.BinaryOp(_, child_op, _) -> {
      let needs_parens = needs_parentheses(child_op, parent_op, is_left)
      case needs_parens {
        True -> "(" <> render_expr(expr) <> ")"
        False -> render_expr(expr)
      }
    }
    hcl.Conditional(_, _, _) -> "(" <> render_expr(expr) <> ")"
    _ -> render_expr(expr)
  }
}

fn precedence(op: BinaryOperator) -> Int {
  case op {
    hcl.Or -> 1
    hcl.And -> 2
    hcl.Equal | hcl.NotEqual -> 3
    hcl.LessThan | hcl.LessEq | hcl.GreaterThan | hcl.GreaterEq -> 4
    hcl.Add | hcl.Subtract -> 5
    hcl.Multiply | hcl.Divide | hcl.Modulo -> 6
  }
}

fn needs_parentheses(child_op: BinaryOperator, parent_op: BinaryOperator, is_left: Bool) -> Bool {
  let child_prec = precedence(child_op)
  let parent_prec = precedence(parent_op)
  case child_prec < parent_prec {
    True -> True
    False ->
      case child_prec == parent_prec && !is_left {
        True -> True
        False -> False
      }
  }
}

fn render_conditional(cond: Expr, true_expr: Expr, false_expr: Expr) -> String {
  let cond_str = case cond {
    hcl.Conditional(_, _, _) -> "(" <> render_expr(cond) <> ")"
    _ -> render_expr(cond)
  }
  cond_str
  <> " ? "
  <> render_expr(true_expr)
  <> " : "
  <> render_expr(false_expr)
}

fn render_for_expr(clause: ForClause) -> String {
  case clause {
    hcl.ForList(key_var, value_var, collection, result, condition) -> {
      let vars = case key_var {
        Some(k) -> k <> ", " <> value_var
        None -> value_var
      }
      let cond_str = case condition {
        Some(c) -> " if " <> render_expr(c)
        None -> ""
      }
      "[for "
      <> vars
      <> " in "
      <> render_expr(collection)
      <> " : "
      <> render_expr(result)
      <> cond_str
      <> "]"
    }
    hcl.ForMap(key_var, value_var, collection, key_result, value_result, condition, grouping) -> {
      let vars = case key_var {
        Some(k) -> k <> ", " <> value_var
        None -> value_var
      }
      let cond_str = case condition {
        Some(c) -> " if " <> render_expr(c)
        None -> ""
      }
      let group_str = case grouping {
        True -> "..."
        False -> ""
      }
      "{for "
      <> vars
      <> " in "
      <> render_expr(collection)
      <> " : "
      <> render_expr(key_result)
      <> " => "
      <> render_expr(value_result)
      <> group_str
      <> cond_str
      <> "}"
    }
  }
}

fn render_splat(base: Expr, splat_type: SplatType) -> String {
  let base_str = render_expr(base)
  case splat_type {
    hcl.FullSplat -> base_str <> "[*]"
    hcl.AttrSplat -> base_str <> ".*"
  }
}

// ============================================================================
// BLOCK RENDERING
// ============================================================================

/// Render a block to HCL text.
pub fn render_block(block: Block) -> String {
  render_block_indented(block, 0)
}

fn render_block_indented(block: Block, indent: Int) -> String {
  let hcl.Block(type_: type_, labels: labels, attributes: attrs, blocks: nested) =
    block
  let indent_str = string.repeat("  ", indent)
  let inner_indent = string.repeat("  ", indent + 1)

  // Block header
  let labels_str = case labels {
    [] -> ""
    _ ->
      " "
      <> string.join(list.map(labels, fn(l) { "\"" <> l <> "\"" }), " ")
  }
  let header = indent_str <> type_ <> labels_str <> " {\n"

  // Attributes
  let attr_lines =
    dict.to_list(attrs)
    |> list.map(fn(pair) {
      let #(key, value) = pair
      inner_indent <> key <> " = " <> render_expr(value)
    })

  // Nested blocks
  let block_lines =
    list.map(nested, fn(b) { render_block_indented(b, indent + 1) })

  // Combine with proper spacing
  let body = case attr_lines, block_lines {
    [], [] -> ""
    attrs, [] -> string.join(attrs, "\n") <> "\n"
    [], blocks -> string.join(blocks, "\n") <> "\n"
    attrs, blocks ->
      string.join(attrs, "\n") <> "\n\n" <> string.join(blocks, "\n") <> "\n"
  }

  let footer = indent_str <> "}"
  header <> body <> footer
}

// ============================================================================
// CONFIG RENDERING
// ============================================================================

/// Render a complete Terraform configuration to HCL text.
pub fn render_config(config: Config) -> String {
  let sections = []

  // Terraform settings
  let sections = case config.terraform {
    Some(settings) -> list.append(sections, [render_terraform_settings(settings)])
    None -> sections
  }

  // Providers
  let sections = case config.providers {
    [] -> sections
    providers ->
      list.append(
        sections,
        list.map(providers, render_provider),
      )
  }

  // Variables
  let sections = case config.variables {
    [] -> sections
    variables ->
      list.append(
        sections,
        list.map(variables, render_variable),
      )
  }

  // Locals
  let sections = case config.locals {
    [] -> sections
    locals_list ->
      list.append(
        sections,
        list.map(locals_list, render_locals),
      )
  }

  // Data sources
  let sections = case config.data_sources {
    [] -> sections
    data_sources ->
      list.append(
        sections,
        list.map(data_sources, render_data_source),
      )
  }

  // Resources
  let sections = case config.resources {
    [] -> sections
    resources ->
      list.append(
        sections,
        list.map(resources, render_resource),
      )
  }

  // Modules
  let sections = case config.modules {
    [] -> sections
    modules ->
      list.append(
        sections,
        list.map(modules, render_module),
      )
  }

  // Outputs
  let sections = case config.outputs {
    [] -> sections
    outputs ->
      list.append(
        sections,
        list.map(outputs, render_output),
      )
  }

  string.join(sections, "\n\n") <> "\n"
}

fn render_terraform_settings(settings: TerraformSettings) -> String {
  let attrs = []

  let attrs = case settings.required_version {
    Some(v) -> list.append(attrs, [#("required_version", hcl.StringLiteral(v))])
    None -> attrs
  }

  let blocks = []

  // required_providers block
  let blocks = case dict.size(settings.required_providers) {
    0 -> blocks
    _ -> {
      let provider_attrs =
        dict.to_list(settings.required_providers)
        |> list.map(fn(pair) {
          let #(name, req) = pair
          #(
            name,
            render_provider_requirement(req),
          )
        })
      list.append(blocks, [
        hcl.Block(
          type_: "required_providers",
          labels: [],
          attributes: dict.from_list(provider_attrs),
          blocks: [],
        ),
      ])
    }
  }

  // Backend block
  let blocks = case settings.backend {
    Some(backend) -> list.append(blocks, [backend])
    None -> blocks
  }

  // Cloud block
  let blocks = case settings.cloud {
    Some(cloud) -> list.append(blocks, [cloud])
    None -> blocks
  }

  render_block(hcl.Block(
    type_: "terraform",
    labels: [],
    attributes: dict.from_list(attrs),
    blocks: blocks,
  ))
}

fn render_provider_requirement(req: ProviderRequirement) -> Expr {
  let attrs = [#(hcl.IdentKey("source"), hcl.StringLiteral(req.source))]
  let attrs = case req.version {
    Some(v) -> list.append(attrs, [#(hcl.IdentKey("version"), hcl.StringLiteral(v))])
    None -> attrs
  }
  hcl.MapExpr(attrs)
}

fn render_provider(provider: Provider) -> String {
  let attrs = dict.to_list(provider.attributes)
  let attrs = case provider.alias {
    Some(a) -> list.prepend(attrs, #("alias", hcl.StringLiteral(a)))
    None -> attrs
  }

  render_block(hcl.Block(
    type_: "provider",
    labels: [provider.name],
    attributes: dict.from_list(attrs),
    blocks: provider.blocks,
  ))
}

fn render_variable(variable: Variable) -> String {
  let attrs = []

  let attrs = case variable.type_constraint {
    Some(t) -> list.append(attrs, [#("type", t)])
    None -> attrs
  }

  let attrs = case variable.default {
    Some(d) -> list.append(attrs, [#("default", d)])
    None -> attrs
  }

  let attrs = case variable.description {
    Some(d) -> list.append(attrs, [#("description", hcl.StringLiteral(d))])
    None -> attrs
  }

  let attrs = case variable.sensitive {
    Some(s) -> list.append(attrs, [#("sensitive", hcl.BoolLiteral(s))])
    None -> attrs
  }

  let attrs = case variable.nullable {
    Some(n) -> list.append(attrs, [#("nullable", hcl.BoolLiteral(n))])
    None -> attrs
  }

  let blocks =
    list.map(variable.validation, fn(v) {
      hcl.Block(
        type_: "validation",
        labels: [],
        attributes: dict.from_list([
          #("condition", v.condition),
          #("error_message", hcl.StringLiteral(v.error_message)),
        ]),
        blocks: [],
      )
    })

  render_block(hcl.Block(
    type_: "variable",
    labels: [variable.name],
    attributes: dict.from_list(attrs),
    blocks: blocks,
  ))
}

fn render_locals(locals: Locals) -> String {
  render_block(hcl.Block(
    type_: "locals",
    labels: [],
    attributes: locals.values,
    blocks: [],
  ))
}

fn render_data_source(data: DataSource) -> String {
  let attrs = dict.to_list(data.attributes)
  let attrs = append_meta_attrs(attrs, data.meta)

  render_block(hcl.Block(
    type_: "data",
    labels: [data.type_, data.name],
    attributes: dict.from_list(attrs),
    blocks: data.blocks,
  ))
}

fn render_resource(resource: Resource) -> String {
  let attrs = dict.to_list(resource.attributes)
  let attrs = append_meta_attrs(attrs, resource.meta)

  let blocks = resource.blocks
  let blocks = case resource.lifecycle {
    Some(lc) -> list.append(blocks, [render_lifecycle_block(lc)])
    None -> blocks
  }

  render_block(hcl.Block(
    type_: "resource",
    labels: [resource.type_, resource.name],
    attributes: dict.from_list(attrs),
    blocks: blocks,
  ))
}

fn render_lifecycle_block(lifecycle: hcl.Lifecycle) -> Block {
  let attrs = []

  let attrs = case lifecycle.create_before_destroy {
    Some(v) -> list.append(attrs, [#("create_before_destroy", hcl.BoolLiteral(v))])
    None -> attrs
  }

  let attrs = case lifecycle.prevent_destroy {
    Some(v) -> list.append(attrs, [#("prevent_destroy", hcl.BoolLiteral(v))])
    None -> attrs
  }

  let attrs = case lifecycle.ignore_changes {
    Some(hcl.IgnoreAll) ->
      list.append(attrs, [#("ignore_changes", hcl.Identifier("all"))])
    Some(hcl.IgnoreList(exprs)) ->
      list.append(attrs, [#("ignore_changes", hcl.ListExpr(exprs))])
    None -> attrs
  }

  let attrs = case lifecycle.replace_triggered_by {
    Some(triggers) ->
      list.append(attrs, [#("replace_triggered_by", hcl.ListExpr(triggers))])
    None -> attrs
  }

  let blocks =
    list.map(lifecycle.precondition, fn(c) {
      hcl.Block(
        type_: "precondition",
        labels: [],
        attributes: dict.from_list([
          #("condition", c.condition),
          #("error_message", hcl.StringLiteral(c.error_message)),
        ]),
        blocks: [],
      )
    })

  let blocks =
    list.append(
      blocks,
      list.map(lifecycle.postcondition, fn(c) {
        hcl.Block(
          type_: "postcondition",
          labels: [],
          attributes: dict.from_list([
            #("condition", c.condition),
            #("error_message", hcl.StringLiteral(c.error_message)),
          ]),
          blocks: [],
        )
      }),
    )

  hcl.Block(
    type_: "lifecycle",
    labels: [],
    attributes: dict.from_list(attrs),
    blocks: blocks,
  )
}

fn render_module(module: Module) -> String {
  let attrs = [#("source", hcl.StringLiteral(module.source))]

  let attrs = case module.version {
    Some(v) -> list.append(attrs, [#("version", hcl.StringLiteral(v))])
    None -> attrs
  }

  let attrs = list.append(attrs, dict.to_list(module.inputs))
  let attrs = append_meta_attrs(attrs, module.meta)

  let attrs = case module.providers {
    Some(providers) ->
      list.append(attrs, [
        #(
          "providers",
          hcl.MapExpr(
            dict.to_list(providers)
            |> list.map(fn(p) { #(hcl.IdentKey(p.0), p.1) }),
          ),
        ),
      ])
    None -> attrs
  }

  render_block(hcl.Block(
    type_: "module",
    labels: [module.name],
    attributes: dict.from_list(attrs),
    blocks: [],
  ))
}

fn render_output(output: Output) -> String {
  let attrs = [#("value", output.value)]

  let attrs = case output.description {
    Some(d) -> list.append(attrs, [#("description", hcl.StringLiteral(d))])
    None -> attrs
  }

  let attrs = case output.sensitive {
    Some(s) -> list.append(attrs, [#("sensitive", hcl.BoolLiteral(s))])
    None -> attrs
  }

  let attrs = case output.depends_on {
    Some(deps) -> list.append(attrs, [#("depends_on", hcl.ListExpr(deps))])
    None -> attrs
  }

  let blocks =
    list.map(output.precondition, fn(c) {
      hcl.Block(
        type_: "precondition",
        labels: [],
        attributes: dict.from_list([
          #("condition", c.condition),
          #("error_message", hcl.StringLiteral(c.error_message)),
        ]),
        blocks: [],
      )
    })

  render_block(hcl.Block(
    type_: "output",
    labels: [output.name],
    attributes: dict.from_list(attrs),
    blocks: blocks,
  ))
}

fn append_meta_attrs(
  attrs: List(#(String, Expr)),
  meta: hcl.MetaArguments,
) -> List(#(String, Expr)) {
  let attrs = case meta.count {
    Some(c) -> list.append(attrs, [#("count", c)])
    None -> attrs
  }

  let attrs = case meta.for_each {
    Some(fe) -> list.append(attrs, [#("for_each", fe)])
    None -> attrs
  }

  let attrs = case meta.provider {
    Some(p) -> list.append(attrs, [#("provider", p)])
    None -> attrs
  }

  case meta.depends_on {
    Some(deps) -> list.append(attrs, [#("depends_on", hcl.ListExpr(deps))])
    None -> attrs
  }
}
