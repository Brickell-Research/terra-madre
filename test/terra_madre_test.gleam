import gleam/dict
import gleam/option
import gleeunit
import gleeunit/should
import terra_madre/hcl
import terra_madre/terraform

pub fn main() {
  gleeunit.main()
}

// ============================================================================
// Expression Tests
// ============================================================================

pub fn string_literal_test() {
  let expr = hcl.StringLiteral("hello")
  case expr {
    hcl.StringLiteral(val) -> val |> should.equal("hello")
    _ -> should.fail()
  }
}

pub fn int_literal_test() {
  let expr = hcl.IntLiteral(42)
  case expr {
    hcl.IntLiteral(val) -> val |> should.equal(42)
    _ -> should.fail()
  }
}

pub fn bool_literal_test() {
  let expr = hcl.BoolLiteral(True)
  case expr {
    hcl.BoolLiteral(val) -> val |> should.equal(True)
    _ -> should.fail()
  }
}

pub fn ref_single_test() {
  let expr = hcl.ref("var")
  case expr {
    hcl.Identifier("var") -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn ref_two_parts_test() {
  let expr = hcl.ref("var.region")
  case expr {
    hcl.GetAttr(hcl.Identifier("var"), "region") -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn ref_three_parts_test() {
  let expr = hcl.ref("aws_instance.web.public_ip")
  case expr {
    hcl.GetAttr(hcl.GetAttr(hcl.Identifier("aws_instance"), "web"), "public_ip") ->
      should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn list_expr_test() {
  let expr =
    hcl.ListExpr([
      hcl.StringLiteral("a"),
      hcl.StringLiteral("b"),
      hcl.StringLiteral("c"),
    ])
  case expr {
    hcl.ListExpr(items) -> items |> should.equal([
      hcl.StringLiteral("a"),
      hcl.StringLiteral("b"),
      hcl.StringLiteral("c"),
    ])
    _ -> should.fail()
  }
}

pub fn map_expr_test() {
  let expr =
    hcl.MapExpr([
      #(hcl.IdentKey("name"), hcl.StringLiteral("test")),
      #(hcl.IdentKey("port"), hcl.IntLiteral(8080)),
    ])
  case expr {
    hcl.MapExpr(pairs) -> {
      pairs
      |> should.equal([
        #(hcl.IdentKey("name"), hcl.StringLiteral("test")),
        #(hcl.IdentKey("port"), hcl.IntLiteral(8080)),
      ])
    }
    _ -> should.fail()
  }
}

pub fn function_call_test() {
  let expr =
    hcl.FunctionCall("file", [hcl.StringLiteral("config.json")], False)
  case expr {
    hcl.FunctionCall(name, args, expand) -> {
      name |> should.equal("file")
      args |> should.equal([hcl.StringLiteral("config.json")])
      expand |> should.equal(False)
    }
    _ -> should.fail()
  }
}

pub fn conditional_test() {
  let expr =
    hcl.Conditional(
      hcl.ref("var.enabled"),
      hcl.StringLiteral("on"),
      hcl.StringLiteral("off"),
    )
  case expr {
    hcl.Conditional(cond, t, f) -> {
      cond |> should.equal(hcl.ref("var.enabled"))
      t |> should.equal(hcl.StringLiteral("on"))
      f |> should.equal(hcl.StringLiteral("off"))
    }
    _ -> should.fail()
  }
}

pub fn binary_op_test() {
  let expr =
    hcl.BinaryOp(hcl.ref("var.count"), hcl.GreaterThan, hcl.IntLiteral(0))
  case expr {
    hcl.BinaryOp(left, op, right) -> {
      left |> should.equal(hcl.ref("var.count"))
      op |> should.equal(hcl.GreaterThan)
      right |> should.equal(hcl.IntLiteral(0))
    }
    _ -> should.fail()
  }
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
  let inner = hcl.simple_block("ebs_block_device", [
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
