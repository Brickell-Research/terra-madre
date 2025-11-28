//// HCL Expression and Block Types
////
//// This module defines the core HCL (HashiCorp Configuration Language) types
//// used as the foundation for Terraform configurations.
////
//// ## References
//// - [HCL Native Syntax Specification](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md)
//// - [Terraform Expressions](https://developer.hashicorp.com/terraform/language/expressions)
//// - [Terraform Configuration Syntax](https://developer.hashicorp.com/terraform/language/syntax/configuration)

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option}
import gleam/string

// ============================================================================
// EXPRESSIONS
// ============================================================================

/// Represents all HCL expression types.
///
/// ## Examples
/// ```gleam
/// // String literal: "hello"
/// StringLiteral("hello")
///
/// // Integer: 42
/// IntLiteral(42)
///
/// // Reference: var.region
/// GetAttr(Identifier("var"), "region")
///
/// // Function call: file("path/to/file")
/// FunctionCall("file", [StringLiteral("path/to/file")], False)
///
/// // Conditional: var.enabled ? "yes" : "no"
/// Conditional(
///   GetAttr(Identifier("var"), "enabled"),
///   StringLiteral("yes"),
///   StringLiteral("no"),
/// )
/// ```
pub type Expr {
  /// String literal: `"us-west-2"`
  StringLiteral(String)

  /// Integer literal: `8080`
  IntLiteral(Int)

  /// Floating-point literal: `3.14`
  FloatLiteral(Float)

  /// Boolean literal: `true` / `false`
  BoolLiteral(Bool)

  /// Null literal: `null`
  NullLiteral

  /// Bare identifier - root of attribute access chains: `var`, `local`, `aws_instance`
  Identifier(String)

  /// Attribute access: `var.region`, `aws_instance.web.id`
  GetAttr(Expr, String)

  /// Index access: `var.list[0]`, `var.map["key"]`
  Index(Expr, Expr)

  /// List/tuple: `["a", "b", "c"]`
  ListExpr(List(Expr))

  /// Map/object: `{ name = "example", port = 8080 }`
  MapExpr(List(#(MapKey, Expr)))

  /// Template string with interpolations: `"Hello, ${var.name}!"`
  TemplateExpr(List(TemplatePart))

  /// Heredoc: `<<EOF ... EOF`
  Heredoc(marker: String, indent_strip: Bool, content: List(TemplatePart))

  /// Function call: `file("config.json")`, `max(1, 2, 3)`
  /// Set expand_final=True for trailing `...`: `concat(list1, list2...)`
  FunctionCall(name: String, args: List(Expr), expand_final: Bool)

  /// Unary operation: `-5`, `!var.enabled`
  UnaryOp(UnaryOperator, Expr)

  /// Binary operation: `1 + 2`, `var.count > 0`, `var.a && var.b`
  BinaryOp(left: Expr, op: BinaryOperator, right: Expr)

  /// Conditional (ternary): `var.enabled ? "on" : "off"`
  Conditional(condition: Expr, true_result: Expr, false_result: Expr)

  /// For expression: `[for s in var.list : upper(s)]`
  ForExpr(ForClause)

  /// Splat expression: `aws_instance.example[*].id`
  Splat(Expr, SplatType)
}

/// Key in a map expression - can be identifier or computed.
/// ```hcl
/// { name = "static", (var.key) = "dynamic" }
/// ```
pub type MapKey {
  IdentKey(String)
  ExprKey(Expr)
}

/// Part of a template expression.
pub type TemplatePart {
  LiteralPart(String)
  Interpolation(Expr)
  Directive(TemplateDirective)
}

/// Template directives for control flow within strings.
/// ```hcl
/// "Hello, %{ if var.name != "" }${var.name}%{ else }World%{ endif }!"
/// ```
pub type TemplateDirective {
  IfDirective(
    condition: Expr,
    true_branch: List(TemplatePart),
    false_branch: List(TemplatePart),
  )
  ForDirective(
    key_var: Option(String),
    value_var: String,
    collection: Expr,
    body: List(TemplatePart),
  )
}

/// Unary operators.
/// Reference: https://developer.hashicorp.com/terraform/language/expressions/operators
pub type UnaryOperator {
  Negate
  Not
}

/// Binary operators.
/// Reference: https://developer.hashicorp.com/terraform/language/expressions/operators
pub type BinaryOperator {
  // Arithmetic
  Add
  Subtract
  Multiply
  Divide
  Modulo
  // Comparison
  Equal
  NotEqual
  LessThan
  LessEq
  GreaterThan
  GreaterEq
  // Logical
  And
  Or
}

/// Splat expression type.
/// Reference: https://developer.hashicorp.com/terraform/language/expressions/splat
pub type SplatType {
  FullSplat
  AttrSplat
}

/// For expression clause.
/// Reference: https://developer.hashicorp.com/terraform/language/expressions/for
pub type ForClause {
  /// `[for v in coll : result]` or `[for k, v in coll : result if cond]`
  ForList(
    key_var: Option(String),
    value_var: String,
    collection: Expr,
    result: Expr,
    condition: Option(Expr),
  )
  /// `{for v in coll : k => v}` or `{for k, v in coll : k => v...}`
  ForMap(
    key_var: Option(String),
    value_var: String,
    collection: Expr,
    key_result: Expr,
    value_result: Expr,
    condition: Option(Expr),
    grouping: Bool,
  )
}

// ============================================================================
// BLOCKS
// ============================================================================

/// Generic HCL block - the fundamental structural element.
///
/// ## Example
/// ```hcl
/// resource "aws_instance" "web" {
///   ami           = "ami-12345"
///   instance_type = "t2.micro"
///
///   ebs_block_device {
///     device_name = "/dev/sda1"
///   }
/// }
/// ```
/// ```gleam
/// Block(
///   type_: "resource",
///   labels: ["aws_instance", "web"],
///   attributes: dict.from_list([
///     #("ami", StringLiteral("ami-12345")),
///     #("instance_type", StringLiteral("t2.micro")),
///   ]),
///   blocks: [
///     Block(
///       type_: "ebs_block_device",
///       labels: [],
///       attributes: dict.from_list([
///         #("device_name", StringLiteral("/dev/sda1")),
///       ]),
///       blocks: [],
///     ),
///   ],
/// )
/// ```
pub type Block {
  Block(
    type_: String,
    labels: List(String),
    attributes: Dict(String, Expr),
    blocks: List(Block),
  )
}

/// Meta-arguments shared by resource, data, and module blocks.
/// Reference: https://developer.hashicorp.com/terraform/language/meta-arguments/count
pub type MetaArguments {
  MetaArguments(
    count: Option(Expr),
    for_each: Option(Expr),
    provider: Option(Expr),
    depends_on: Option(List(Expr)),
  )
}

/// Lifecycle configuration for resources.
/// Reference: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
pub type Lifecycle {
  Lifecycle(
    create_before_destroy: Option(Bool),
    prevent_destroy: Option(Bool),
    ignore_changes: Option(IgnoreChanges),
    replace_triggered_by: Option(List(Expr)),
    precondition: List(Condition),
    postcondition: List(Condition),
  )
}

/// Specifies which attributes to ignore during updates.
pub type IgnoreChanges {
  IgnoreAll
  IgnoreList(List(Expr))
}

/// Condition block for precondition/postcondition and variable validation.
pub type Condition {
  Condition(condition: Expr, error_message: String)
}

// ============================================================================
// HELPERS
// ============================================================================

/// Create empty meta-arguments.
pub fn empty_meta() -> MetaArguments {
  MetaArguments(
    count: option.None,
    for_each: option.None,
    provider: option.None,
    depends_on: option.None,
  )
}

/// Create empty lifecycle configuration.
pub fn empty_lifecycle() -> Lifecycle {
  Lifecycle(
    create_before_destroy: option.None,
    prevent_destroy: option.None,
    ignore_changes: option.None,
    replace_triggered_by: option.None,
    precondition: [],
    postcondition: [],
  )
}

/// Create a simple block with no labels or nested blocks.
/// ```gleam
/// simple_block("versioning", [#("enabled", BoolLiteral(True))])
/// ```
pub fn simple_block(type_: String, attributes: List(#(String, Expr))) -> Block {
  Block(
    type_: type_,
    labels: [],
    attributes: dict.from_list(attributes),
    blocks: [],
  )
}

/// Create a block with attributes but no nested blocks.
/// ```gleam
/// block_with_attrs("provider", ["aws"], [#("region", StringLiteral("us-west-2"))])
/// ```
pub fn block_with_attrs(
  type_: String,
  labels: List(String),
  attributes: List(#(String, Expr)),
) -> Block {
  Block(
    type_: type_,
    labels: labels,
    attributes: dict.from_list(attributes),
    blocks: [],
  )
}

/// Build a reference chain from dot-notation: `"var.region"` -> `GetAttr(Identifier("var"), "region")`
/// ```gleam
/// ref("var.region")
/// // => GetAttr(Identifier("var"), "region")
///
/// ref("aws_instance.web.public_ip")
/// // => GetAttr(GetAttr(Identifier("aws_instance"), "web"), "public_ip")
/// ```
pub fn ref(path: String) -> Expr {
  case string.split(path, ".") {
    [] -> Identifier("")
    [single] -> Identifier(single)
    [first, ..rest] -> list.fold(rest, Identifier(first), fn(acc, part) {
      GetAttr(acc, part)
    })
  }
}
