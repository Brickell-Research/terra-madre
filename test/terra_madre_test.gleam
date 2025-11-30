import gleam/dict
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import terra_madre/hcl
import terra_madre/render
import terra_madre/terraform

pub fn main() {
  gleeunit.main()
}

// ============================================================================
// Expression Tests
// ============================================================================

fn encode_decode_expression(encode: fn(String) -> a, decode: fn(a) -> String) {
  let encode(val) = decode(val)
}

pub fn string_literal_test() {
  let hcl.StringLiteral(val) = hcl.StringLiteral("hello")
  val |> should.equal("hello")
}

pub fn int_literal_test() {
  let hcl.IntLiteral(val) = hcl.IntLiteral(42)
  val |> should.equal(42)
}

pub fn bool_literal_test() {
  let hcl.BoolLiteral(val) = hcl.BoolLiteral(True)
  val |> should.equal(True)
}

pub fn ref_single_test() {
  hcl.ref("var")
  |> should.equal(hcl.Identifier("var"))
}

pub fn ref_two_parts_test() {
  hcl.ref("var.region")
  |> should.equal(hcl.GetAttr(hcl.Identifier("var"), "region"))
}

pub fn ref_three_parts_test() {
  hcl.ref("aws_instance.web.public_ip")
  |> should.equal(
    hcl.GetAttr(hcl.GetAttr(hcl.Identifier("aws_instance"), "web"), "public_ip"),
  )
}

pub fn list_expr_test() {
  let items = [
    hcl.StringLiteral("a"),
    hcl.StringLiteral("b"),
    hcl.StringLiteral("c"),
  ]
  let hcl.ListExpr(result) = hcl.ListExpr(items)
  result |> should.equal(items)
}

pub fn map_expr_test() {
  let pairs = [
    #(hcl.IdentKey("name"), hcl.StringLiteral("test")),
    #(hcl.IdentKey("port"), hcl.IntLiteral(8080)),
  ]
  let hcl.MapExpr(result) = hcl.MapExpr(pairs)
  result |> should.equal(pairs)
}

pub fn function_call_test() {
  let hcl.FunctionCall(name, args, expand) =
    hcl.FunctionCall("file", [hcl.StringLiteral("config.json")], False)
  name |> should.equal("file")
  args |> should.equal([hcl.StringLiteral("config.json")])
  expand |> should.equal(False)
}

pub fn conditional_test() {
  let hcl.Conditional(cond, t, f) =
    hcl.Conditional(
      hcl.ref("var.enabled"),
      hcl.StringLiteral("on"),
      hcl.StringLiteral("off"),
    )
  cond |> should.equal(hcl.ref("var.enabled"))
  t |> should.equal(hcl.StringLiteral("on"))
  f |> should.equal(hcl.StringLiteral("off"))
}

pub fn binary_op_test() {
  let hcl.BinaryOp(left, op, right) =
    hcl.BinaryOp(hcl.ref("var.count"), hcl.GreaterThan, hcl.IntLiteral(0))
  left |> should.equal(hcl.ref("var.count"))
  op |> should.equal(hcl.GreaterThan)
  right |> should.equal(hcl.IntLiteral(0))
}

// ============================================================================
// Block Tests
// ============================================================================

pub fn simple_block_test() {
  let block =
    hcl.simple_block("versioning", [#("enabled", hcl.BoolLiteral(True))])
  block.type_ |> should.equal("versioning")
  block.labels |> should.equal([])
  dict.get(block.attributes, "enabled")
  |> should.equal(Ok(hcl.BoolLiteral(True)))
}

pub fn block_with_attrs_test() {
  let block =
    hcl.block_with_attrs("provider", ["aws"], [
      #("region", hcl.StringLiteral("us-west-2")),
    ])
  block.type_ |> should.equal("provider")
  block.labels |> should.equal(["aws"])
  dict.get(block.attributes, "region")
  |> should.equal(Ok(hcl.StringLiteral("us-west-2")))
}

pub fn nested_block_test() {
  let inner =
    hcl.simple_block("ebs_block_device", [
      #("device_name", hcl.StringLiteral("/dev/sda1")),
    ])
  let outer =
    hcl.Block(
      type_: "resource",
      labels: ["aws_instance", "web"],
      attributes: dict.from_list([
        #("ami", hcl.StringLiteral("ami-12345")),
      ]),
      blocks: [inner],
    )
  outer.type_ |> should.equal("resource")
  outer.labels |> should.equal(["aws_instance", "web"])
  outer.blocks |> should.equal([inner])
}

// ============================================================================
// Terraform Type Tests
// ============================================================================

pub fn simple_provider_test() {
  let provider =
    terraform.simple_provider("aws", [
      #("region", hcl.StringLiteral("us-west-2")),
    ])
  provider.name |> should.equal("aws")
  provider.alias |> should.equal(option.None)
  dict.get(provider.attributes, "region")
  |> should.equal(Ok(hcl.StringLiteral("us-west-2")))
}

pub fn simple_resource_test() {
  let resource =
    terraform.simple_resource("aws_instance", "web", [
      #("ami", hcl.StringLiteral("ami-12345")),
      #("instance_type", hcl.StringLiteral("t2.micro")),
    ])
  resource.type_ |> should.equal("aws_instance")
  resource.name |> should.equal("web")
  dict.get(resource.attributes, "ami")
  |> should.equal(Ok(hcl.StringLiteral("ami-12345")))
}

pub fn simple_variable_test() {
  let var = terraform.simple_variable("region", hcl.StringLiteral("us-west-2"))
  var.name |> should.equal("region")
  var.default |> should.equal(option.Some(hcl.StringLiteral("us-west-2")))
}

pub fn simple_output_test() {
  let output =
    terraform.simple_output("ip", hcl.ref("aws_instance.web.public_ip"))
  output.name |> should.equal("ip")
  output.value |> should.equal(hcl.ref("aws_instance.web.public_ip"))
}

pub fn simple_module_test() {
  let mod =
    terraform.simple_module("vpc", "./modules/vpc", [
      #("cidr", hcl.StringLiteral("10.0.0.0/16")),
    ])
  mod.name |> should.equal("vpc")
  mod.source |> should.equal("./modules/vpc")
  dict.get(mod.inputs, "cidr")
  |> should.equal(Ok(hcl.StringLiteral("10.0.0.0/16")))
}

pub fn empty_config_test() {
  let config = terraform.empty_config()
  config.terraform |> should.equal(option.None)
  config.providers |> should.equal([])
  config.resources |> should.equal([])
}

// ============================================================================
// Render Expression Tests
// ============================================================================

pub fn render_string_literal_test() {
  render.render_expr(hcl.StringLiteral("hello"))
  |> should.equal("\"hello\"")
}

pub fn render_string_escape_test() {
  render.render_expr(hcl.StringLiteral("hello\nworld"))
  |> should.equal("\"hello\\nworld\"")
}

pub fn render_int_literal_test() {
  render.render_expr(hcl.IntLiteral(42))
  |> should.equal("42")
}

pub fn render_float_literal_test() {
  render.render_expr(hcl.FloatLiteral(3.14))
  |> should.equal("3.14")
}

pub fn render_bool_true_test() {
  render.render_expr(hcl.BoolLiteral(True))
  |> should.equal("true")
}

pub fn render_bool_false_test() {
  render.render_expr(hcl.BoolLiteral(False))
  |> should.equal("false")
}

pub fn render_null_test() {
  render.render_expr(hcl.NullLiteral)
  |> should.equal("null")
}

pub fn render_identifier_test() {
  render.render_expr(hcl.Identifier("var"))
  |> should.equal("var")
}

pub fn render_get_attr_test() {
  render.render_expr(hcl.ref("var.region"))
  |> should.equal("var.region")
}

pub fn render_get_attr_chain_test() {
  render.render_expr(hcl.ref("aws_instance.web.public_ip"))
  |> should.equal("aws_instance.web.public_ip")
}

pub fn render_index_test() {
  render.render_expr(hcl.Index(hcl.ref("var.list"), hcl.IntLiteral(0)))
  |> should.equal("var.list[0]")
}

pub fn render_index_string_key_test() {
  render.render_expr(hcl.Index(hcl.ref("var.map"), hcl.StringLiteral("key")))
  |> should.equal("var.map[\"key\"]")
}

pub fn render_empty_list_test() {
  render.render_expr(hcl.ListExpr([]))
  |> should.equal("[]")
}

pub fn render_list_test() {
  render.render_expr(
    hcl.ListExpr([
      hcl.StringLiteral("a"),
      hcl.StringLiteral("b"),
    ]),
  )
  |> should.equal("[\"a\", \"b\"]")
}

pub fn render_empty_map_test() {
  render.render_expr(hcl.MapExpr([]))
  |> should.equal("{}")
}

pub fn render_map_test() {
  render.render_expr(
    hcl.MapExpr([
      #(hcl.IdentKey("name"), hcl.StringLiteral("test")),
      #(hcl.IdentKey("port"), hcl.IntLiteral(8080)),
    ]),
  )
  |> should.equal("{ name = \"test\", port = 8080 }")
}

pub fn render_map_computed_key_test() {
  render.render_expr(
    hcl.MapExpr([
      #(hcl.ExprKey(hcl.ref("var.key")), hcl.StringLiteral("value")),
    ]),
  )
  |> should.equal("{ (var.key) = \"value\" }")
}

pub fn render_template_test() {
  render.render_expr(
    hcl.TemplateExpr([
      hcl.LiteralPart("Hello, "),
      hcl.Interpolation(hcl.ref("var.name")),
      hcl.LiteralPart("!"),
    ]),
  )
  |> should.equal("\"Hello, ${var.name}!\"")
}

pub fn render_template_escape_interpolation_test() {
  render.render_expr(
    hcl.TemplateExpr([
      hcl.LiteralPart("Use ${var} syntax"),
    ]),
  )
  |> should.equal("\"Use $${var} syntax\"")
}

pub fn render_heredoc_test() {
  render.render_expr(hcl.Heredoc("EOF", False, [hcl.LiteralPart("hello\n")]))
  |> should.equal("<<EOF\nhello\nEOF")
}

pub fn render_heredoc_strip_test() {
  render.render_expr(hcl.Heredoc("EOF", True, [hcl.LiteralPart("hello\n")]))
  |> should.equal("<<-EOF\nhello\nEOF")
}

pub fn render_function_call_test() {
  render.render_expr(hcl.FunctionCall(
    "file",
    [hcl.StringLiteral("path")],
    False,
  ))
  |> should.equal("file(\"path\")")
}

pub fn render_function_call_no_args_test() {
  render.render_expr(hcl.FunctionCall("timestamp", [], False))
  |> should.equal("timestamp()")
}

pub fn render_function_call_multiple_args_test() {
  render.render_expr(hcl.FunctionCall(
    "max",
    [
      hcl.IntLiteral(1),
      hcl.IntLiteral(2),
      hcl.IntLiteral(3),
    ],
    False,
  ))
  |> should.equal("max(1, 2, 3)")
}

pub fn render_function_call_expand_test() {
  render.render_expr(hcl.FunctionCall("concat", [hcl.ref("var.list")], True))
  |> should.equal("concat(var.list...)")
}

pub fn render_unary_negate_test() {
  render.render_expr(hcl.UnaryOp(hcl.Negate, hcl.IntLiteral(5)))
  |> should.equal("-5")
}

pub fn render_unary_not_test() {
  render.render_expr(hcl.UnaryOp(hcl.Not, hcl.ref("var.enabled")))
  |> should.equal("!var.enabled")
}

pub fn render_binary_add_test() {
  render.render_expr(hcl.BinaryOp(hcl.IntLiteral(1), hcl.Add, hcl.IntLiteral(2)))
  |> should.equal("1 + 2")
}

pub fn render_binary_comparison_test() {
  render.render_expr(hcl.BinaryOp(
    hcl.ref("var.count"),
    hcl.GreaterThan,
    hcl.IntLiteral(0),
  ))
  |> should.equal("var.count > 0")
}

pub fn render_binary_logical_test() {
  render.render_expr(hcl.BinaryOp(hcl.ref("var.a"), hcl.And, hcl.ref("var.b")))
  |> should.equal("var.a && var.b")
}

pub fn render_binary_precedence_test() {
  // 1 + 2 * 3 should not need parens
  render.render_expr(hcl.BinaryOp(
    hcl.IntLiteral(1),
    hcl.Add,
    hcl.BinaryOp(hcl.IntLiteral(2), hcl.Multiply, hcl.IntLiteral(3)),
  ))
  |> should.equal("1 + 2 * 3")
}

pub fn render_binary_precedence_parens_test() {
  // (1 + 2) * 3 needs parens
  render.render_expr(hcl.BinaryOp(
    hcl.BinaryOp(hcl.IntLiteral(1), hcl.Add, hcl.IntLiteral(2)),
    hcl.Multiply,
    hcl.IntLiteral(3),
  ))
  |> should.equal("(1 + 2) * 3")
}

pub fn render_conditional_test() {
  render.render_expr(hcl.Conditional(
    hcl.ref("var.enabled"),
    hcl.StringLiteral("on"),
    hcl.StringLiteral("off"),
  ))
  |> should.equal("var.enabled ? \"on\" : \"off\"")
}

pub fn render_for_list_test() {
  render.render_expr(
    hcl.ForExpr(hcl.ForList(
      key_var: option.None,
      value_var: "s",
      collection: hcl.ref("var.list"),
      result: hcl.FunctionCall("upper", [hcl.Identifier("s")], False),
      condition: option.None,
    )),
  )
  |> should.equal("[for s in var.list : upper(s)]")
}

pub fn render_for_list_with_key_test() {
  render.render_expr(
    hcl.ForExpr(hcl.ForList(
      key_var: option.Some("i"),
      value_var: "v",
      collection: hcl.ref("var.list"),
      result: hcl.Identifier("v"),
      condition: option.None,
    )),
  )
  |> should.equal("[for i, v in var.list : v]")
}

pub fn render_for_list_with_condition_test() {
  render.render_expr(
    hcl.ForExpr(hcl.ForList(
      key_var: option.None,
      value_var: "s",
      collection: hcl.ref("var.list"),
      result: hcl.Identifier("s"),
      condition: option.Some(hcl.BinaryOp(
        hcl.Identifier("s"),
        hcl.NotEqual,
        hcl.StringLiteral(""),
      )),
    )),
  )
  |> should.equal("[for s in var.list : s if s != \"\"]")
}

pub fn render_for_map_test() {
  render.render_expr(
    hcl.ForExpr(hcl.ForMap(
      key_var: option.Some("k"),
      value_var: "v",
      collection: hcl.ref("var.map"),
      key_result: hcl.Identifier("k"),
      value_result: hcl.FunctionCall("upper", [hcl.Identifier("v")], False),
      condition: option.None,
      grouping: False,
    )),
  )
  |> should.equal("{for k, v in var.map : k => upper(v)}")
}

pub fn render_for_map_grouping_test() {
  render.render_expr(
    hcl.ForExpr(hcl.ForMap(
      key_var: option.None,
      value_var: "v",
      collection: hcl.ref("var.list"),
      key_result: hcl.GetAttr(hcl.Identifier("v"), "group"),
      value_result: hcl.Identifier("v"),
      condition: option.None,
      grouping: True,
    )),
  )
  |> should.equal("{for v in var.list : v.group => v...}")
}

pub fn render_full_splat_test() {
  render.render_expr(hcl.Splat(hcl.ref("aws_instance.example"), hcl.FullSplat))
  |> should.equal("aws_instance.example[*]")
}

pub fn render_attr_splat_test() {
  render.render_expr(hcl.Splat(hcl.ref("aws_instance.example"), hcl.AttrSplat))
  |> should.equal("aws_instance.example.*")
}

pub fn render_template_if_directive_test() {
  render.render_expr(
    hcl.TemplateExpr([
      hcl.LiteralPart("Hello, "),
      hcl.Directive(
        hcl.IfDirective(
          condition: hcl.BinaryOp(
            hcl.ref("var.name"),
            hcl.NotEqual,
            hcl.StringLiteral(""),
          ),
          true_branch: [hcl.Interpolation(hcl.ref("var.name"))],
          false_branch: [hcl.LiteralPart("World")],
        ),
      ),
      hcl.LiteralPart("!"),
    ]),
  )
  |> should.equal(
    "\"Hello, %{ if var.name != \"\" }${var.name}%{ else }World%{ endif }!\"",
  )
}

pub fn render_template_for_directive_test() {
  render.render_expr(
    hcl.TemplateExpr([
      hcl.Directive(
        hcl.ForDirective(
          key_var: option.None,
          value_var: "item",
          collection: hcl.ref("var.items"),
          body: [
            hcl.Interpolation(hcl.Identifier("item")),
            hcl.LiteralPart("\n"),
          ],
        ),
      ),
    ]),
  )
  |> should.equal("\"%{ for item in var.items }${item}\\n%{ endfor }\"")
}

// ============================================================================
// Render Block Tests
// ============================================================================

pub fn render_simple_block_test() {
  let block =
    hcl.simple_block("versioning", [#("enabled", hcl.BoolLiteral(True))])
  render.render_block(block)
  |> should.equal("versioning {\n  enabled = true\n}")
}

pub fn render_block_with_labels_test() {
  let block =
    hcl.block_with_attrs("provider", ["aws"], [
      #("region", hcl.StringLiteral("us-west-2")),
    ])
  render.render_block(block)
  |> should.equal("provider \"aws\" {\n  region = \"us-west-2\"\n}")
}

pub fn render_block_multiple_labels_test() {
  let block =
    hcl.block_with_attrs("resource", ["aws_instance", "web"], [
      #("ami", hcl.StringLiteral("ami-12345")),
    ])
  render.render_block(block)
  |> should.equal(
    "resource \"aws_instance\" \"web\" {\n  ami = \"ami-12345\"\n}",
  )
}

pub fn render_empty_block_test() {
  let block =
    hcl.Block(type_: "empty", labels: [], attributes: dict.new(), blocks: [])
  render.render_block(block)
  |> should.equal("empty {\n}")
}

pub fn render_nested_block_test() {
  let inner = hcl.simple_block("nested", [#("value", hcl.IntLiteral(42))])
  let outer =
    hcl.Block(
      type_: "outer",
      labels: [],
      attributes: dict.from_list([#("name", hcl.StringLiteral("test"))]),
      blocks: [inner],
    )
  render.render_block(outer)
  |> should.equal(
    "outer {\n  name = \"test\"\n\n  nested {\n    value = 42\n  }\n}",
  )
}

// ============================================================================
// Render Config Tests
// ============================================================================

pub fn render_empty_config_test() {
  render.render_config(terraform.empty_config())
  |> should.equal("\n")
}

pub fn render_config_with_provider_test() {
  let config =
    terraform.Config(..terraform.empty_config(), providers: [
      terraform.simple_provider("aws", [
        #("region", hcl.StringLiteral("us-west-2")),
      ]),
    ])
  render.render_config(config)
  |> string.contains("provider \"aws\"")
  |> should.be_true()
}

pub fn render_config_with_resource_test() {
  let config =
    terraform.Config(..terraform.empty_config(), resources: [
      terraform.simple_resource("aws_instance", "web", [
        #("ami", hcl.StringLiteral("ami-12345")),
        #("instance_type", hcl.StringLiteral("t2.micro")),
      ]),
    ])
  let rendered = render.render_config(config)
  rendered
  |> string.contains("resource \"aws_instance\" \"web\"")
  |> should.be_true()
  rendered |> string.contains("ami = \"ami-12345\"") |> should.be_true()
}

pub fn render_config_with_variable_test() {
  let config =
    terraform.Config(..terraform.empty_config(), variables: [
      terraform.Variable(
        name: "region",
        type_constraint: option.Some(hcl.Identifier("string")),
        default: option.Some(hcl.StringLiteral("us-west-2")),
        description: option.Some("AWS region"),
        sensitive: option.None,
        nullable: option.None,
        validation: [],
      ),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("variable \"region\"") |> should.be_true()
  rendered |> string.contains("type = string") |> should.be_true()
  rendered |> string.contains("default = \"us-west-2\"") |> should.be_true()
  rendered
  |> string.contains("description = \"AWS region\"")
  |> should.be_true()
}

pub fn render_config_with_output_test() {
  let config =
    terraform.Config(..terraform.empty_config(), outputs: [
      terraform.simple_output(
        "instance_ip",
        hcl.ref("aws_instance.web.public_ip"),
      ),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("output \"instance_ip\"") |> should.be_true()
  rendered
  |> string.contains("value = aws_instance.web.public_ip")
  |> should.be_true()
}

pub fn render_config_with_locals_test() {
  let config =
    terraform.Config(..terraform.empty_config(), locals: [
      terraform.Locals(
        dict.from_list([
          #("env", hcl.StringLiteral("production")),
        ]),
      ),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("locals {") |> should.be_true()
  rendered |> string.contains("env = \"production\"") |> should.be_true()
}

pub fn render_config_with_module_test() {
  let config =
    terraform.Config(..terraform.empty_config(), modules: [
      terraform.simple_module("vpc", "./modules/vpc", [
        #("cidr", hcl.StringLiteral("10.0.0.0/16")),
      ]),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("module \"vpc\"") |> should.be_true()
  rendered |> string.contains("source = \"./modules/vpc\"") |> should.be_true()
}

pub fn render_config_with_data_source_test() {
  let config =
    terraform.Config(..terraform.empty_config(), data_sources: [
      terraform.simple_data("aws_ami", "ubuntu", [
        #("most_recent", hcl.BoolLiteral(True)),
      ]),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("data \"aws_ami\" \"ubuntu\"") |> should.be_true()
  rendered |> string.contains("most_recent = true") |> should.be_true()
}

pub fn render_terraform_settings_test() {
  let config =
    terraform.Config(
      ..terraform.empty_config(),
      terraform: option.Some(terraform.TerraformSettings(
        required_version: option.Some(">= 1.0"),
        required_providers: dict.from_list([
          #(
            "aws",
            terraform.ProviderRequirement(
              "hashicorp/aws",
              option.Some("~> 5.0"),
            ),
          ),
        ]),
        backend: option.None,
        cloud: option.None,
      )),
    )
  let rendered = render.render_config(config)
  rendered |> string.contains("terraform {") |> should.be_true()
  rendered
  |> string.contains("required_version = \">= 1.0\"")
  |> should.be_true()
  rendered |> string.contains("required_providers {") |> should.be_true()
  rendered |> string.contains("source = \"hashicorp/aws\"") |> should.be_true()
}

pub fn render_resource_with_lifecycle_test() {
  let config =
    terraform.Config(..terraform.empty_config(), resources: [
      terraform.Resource(
        type_: "aws_instance",
        name: "web",
        attributes: dict.from_list([#("ami", hcl.StringLiteral("ami-12345"))]),
        blocks: [],
        meta: hcl.empty_meta(),
        lifecycle: option.Some(
          hcl.Lifecycle(
            create_before_destroy: option.Some(True),
            prevent_destroy: option.Some(True),
            ignore_changes: option.None,
            replace_triggered_by: option.None,
            precondition: [],
            postcondition: [],
          ),
        ),
      ),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("lifecycle {") |> should.be_true()
  rendered
  |> string.contains("create_before_destroy = true")
  |> should.be_true()
  rendered |> string.contains("prevent_destroy = true") |> should.be_true()
}

pub fn render_resource_with_count_test() {
  let config =
    terraform.Config(..terraform.empty_config(), resources: [
      terraform.Resource(
        type_: "aws_instance",
        name: "web",
        attributes: dict.from_list([#("ami", hcl.StringLiteral("ami-12345"))]),
        blocks: [],
        meta: hcl.MetaArguments(
          count: option.Some(hcl.IntLiteral(3)),
          for_each: option.None,
          provider: option.None,
          depends_on: option.None,
        ),
        lifecycle: option.None,
      ),
    ])
  let rendered = render.render_config(config)
  rendered |> string.contains("count = 3") |> should.be_true()
}
