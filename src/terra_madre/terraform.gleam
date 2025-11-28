//// Terraform Top-Level Configuration Types
////
//// This module defines typed representations of Terraform's top-level blocks:
//// terraform, provider, resource, data, variable, output, locals, and module.
////
//// ## References
//// - [Terraform Configuration](https://developer.hashicorp.com/terraform/language)
//// - [Provider Configuration](https://developer.hashicorp.com/terraform/language/providers/configuration)
//// - [Resources](https://developer.hashicorp.com/terraform/language/resources)
//// - [Data Sources](https://developer.hashicorp.com/terraform/language/data-sources)
//// - [Variables](https://developer.hashicorp.com/terraform/language/values/variables)
//// - [Outputs](https://developer.hashicorp.com/terraform/language/values/outputs)
//// - [Locals](https://developer.hashicorp.com/terraform/language/values/locals)
//// - [Modules](https://developer.hashicorp.com/terraform/language/modules)

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import terra_madre/hcl.{
  type Block, type Condition, type Expr, type Lifecycle, type MetaArguments,
}

// ============================================================================
// TERRAFORM SETTINGS BLOCK
// ============================================================================

/// The `terraform {}` block for configuration settings.
///
/// Reference: https://developer.hashicorp.com/terraform/language/settings
///
/// ## Example
/// ```hcl
/// terraform {
///   required_version = ">= 1.0"
///   required_providers {
///     aws = {
///       source  = "hashicorp/aws"
///       version = "~> 5.0"
///     }
///   }
///   backend "s3" {
///     bucket = "my-terraform-state"
///     key    = "state.tfstate"
///   }
/// }
/// ```
/// ```gleam
/// TerraformSettings(
///   required_version: option.Some(">= 1.0"),
///   required_providers: dict.from_list([
///     #("aws", ProviderRequirement("hashicorp/aws", option.Some("~> 5.0"))),
///   ]),
///   backend: option.Some(hcl.block_with_attrs("s3", [], [
///     #("bucket", hcl.StringLiteral("my-terraform-state")),
///     #("key", hcl.StringLiteral("state.tfstate")),
///   ])),
///   cloud: option.None,
/// )
/// ```
pub type TerraformSettings {
  TerraformSettings(
    required_version: Option(String),
    required_providers: Dict(String, ProviderRequirement),
    backend: Option(Block),
    cloud: Option(Block),
  )
}

/// Provider version requirement in `required_providers` block.
///
/// ## Example
/// ```hcl
/// aws = {
///   source  = "hashicorp/aws"
///   version = "~> 5.0"
/// }
/// ```
/// ```gleam
/// ProviderRequirement("hashicorp/aws", option.Some("~> 5.0"))
/// ```
pub type ProviderRequirement {
  ProviderRequirement(source: String, version: Option(String))
}

// ============================================================================
// PROVIDER BLOCK
// ============================================================================

/// Provider configuration block.
///
/// Reference: https://developer.hashicorp.com/terraform/language/providers/configuration
///
/// ## Example
/// ```hcl
/// provider "aws" {
///   region  = "us-west-2"
///   profile = "production"
/// }
///
/// provider "aws" {
///   alias  = "west"
///   region = "us-west-1"
/// }
/// ```
/// ```gleam
/// // Primary AWS provider
/// Provider(
///   name: "aws",
///   alias: option.None,
///   attributes: dict.from_list([
///     #("region", hcl.StringLiteral("us-west-2")),
///     #("profile", hcl.StringLiteral("production")),
///   ]),
///   blocks: [],
/// )
///
/// // Aliased provider
/// Provider(
///   name: "aws",
///   alias: option.Some("west"),
///   attributes: dict.from_list([
///     #("region", hcl.StringLiteral("us-west-1")),
///   ]),
///   blocks: [],
/// )
/// ```
pub type Provider {
  Provider(
    name: String,
    alias: Option(String),
    attributes: Dict(String, Expr),
    blocks: List(Block),
  )
}

// ============================================================================
// RESOURCE BLOCK
// ============================================================================

/// Resource block - manages infrastructure objects.
///
/// Reference: https://developer.hashicorp.com/terraform/language/resources
///
/// ## Example
/// ```hcl
/// resource "aws_instance" "web" {
///   ami           = "ami-12345"
///   instance_type = "t2.micro"
///   count         = 3
///
///   tags = {
///     Name = "Web-${count.index}"
///   }
///
///   lifecycle {
///     create_before_destroy = true
///   }
/// }
/// ```
/// ```gleam
/// Resource(
///   type_: "aws_instance",
///   name: "web",
///   attributes: dict.from_list([
///     #("ami", hcl.StringLiteral("ami-12345")),
///     #("instance_type", hcl.StringLiteral("t2.micro")),
///   ]),
///   blocks: [],
///   meta: hcl.MetaArguments(
///     count: option.Some(hcl.IntLiteral(3)),
///     for_each: option.None,
///     provider: option.None,
///     depends_on: option.None,
///   ),
///   lifecycle: option.Some(hcl.Lifecycle(
///     create_before_destroy: option.Some(True),
///     prevent_destroy: option.None,
///     ignore_changes: option.None,
///     replace_triggered_by: option.None,
///     precondition: [],
///     postcondition: [],
///   )),
/// )
/// ```
pub type Resource {
  Resource(
    type_: String,
    name: String,
    attributes: Dict(String, Expr),
    blocks: List(Block),
    meta: MetaArguments,
    lifecycle: Option(Lifecycle),
  )
}

// ============================================================================
// DATA BLOCK
// ============================================================================

/// Data source block - reads existing infrastructure.
///
/// Reference: https://developer.hashicorp.com/terraform/language/data-sources
///
/// ## Example
/// ```hcl
/// data "aws_ami" "ubuntu" {
///   most_recent = true
///   owners      = ["099720109477"]
///
///   filter {
///     name   = "name"
///     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-*"]
///   }
/// }
/// ```
/// ```gleam
/// DataSource(
///   type_: "aws_ami",
///   name: "ubuntu",
///   attributes: dict.from_list([
///     #("most_recent", hcl.BoolLiteral(True)),
///     #("owners", hcl.ListExpr([hcl.StringLiteral("099720109477")])),
///   ]),
///   blocks: [
///     hcl.block_with_attrs("filter", [], [
///       #("name", hcl.StringLiteral("name")),
///       #("values", hcl.ListExpr([
///         hcl.StringLiteral("ubuntu/images/hvm-ssd/ubuntu-focal-*"),
///       ])),
///     ]),
///   ],
///   meta: hcl.empty_meta(),
/// )
/// ```
pub type DataSource {
  DataSource(
    type_: String,
    name: String,
    attributes: Dict(String, Expr),
    blocks: List(Block),
    meta: MetaArguments,
  )
}

// ============================================================================
// VARIABLE BLOCK
// ============================================================================

/// Input variable block.
///
/// Reference: https://developer.hashicorp.com/terraform/language/values/variables
///
/// ## Example
/// ```hcl
/// variable "instance_type" {
///   type        = string
///   default     = "t2.micro"
///   description = "EC2 instance type"
///
///   validation {
///     condition     = contains(["t2.micro", "t2.small"], var.instance_type)
///     error_message = "Must be t2.micro or t2.small"
///   }
/// }
/// ```
/// ```gleam
/// Variable(
///   name: "instance_type",
///   type_constraint: option.Some(hcl.Identifier("string")),
///   default: option.Some(hcl.StringLiteral("t2.micro")),
///   description: option.Some("EC2 instance type"),
///   sensitive: option.None,
///   nullable: option.None,
///   validation: [
///     hcl.Condition(
///       condition: hcl.FunctionCall("contains", [
///         hcl.ListExpr([hcl.StringLiteral("t2.micro"), hcl.StringLiteral("t2.small")]),
///         hcl.ref("var.instance_type"),
///       ], False),
///       error_message: "Must be t2.micro or t2.small",
///     ),
///   ],
/// )
/// ```
pub type Variable {
  Variable(
    name: String,
    type_constraint: Option(Expr),
    default: Option(Expr),
    description: Option(String),
    sensitive: Option(Bool),
    nullable: Option(Bool),
    validation: List(Condition),
  )
}

// ============================================================================
// OUTPUT BLOCK
// ============================================================================

/// Output value block.
///
/// Reference: https://developer.hashicorp.com/terraform/language/values/outputs
///
/// ## Example
/// ```hcl
/// output "instance_ip" {
///   value       = aws_instance.web.public_ip
///   description = "Public IP of the web server"
///   sensitive   = false
/// }
/// ```
/// ```gleam
/// Output(
///   name: "instance_ip",
///   value: hcl.ref("aws_instance.web.public_ip"),
///   description: option.Some("Public IP of the web server"),
///   sensitive: option.Some(False),
///   depends_on: option.None,
///   precondition: [],
/// )
/// ```
pub type Output {
  Output(
    name: String,
    value: Expr,
    description: Option(String),
    sensitive: Option(Bool),
    depends_on: Option(List(Expr)),
    precondition: List(Condition),
  )
}

// ============================================================================
// LOCALS BLOCK
// ============================================================================

/// Local values block.
///
/// Reference: https://developer.hashicorp.com/terraform/language/values/locals
///
/// ## Example
/// ```hcl
/// locals {
///   common_tags = {
///     Environment = var.environment
///     Project     = "my-project"
///   }
///   instance_name = "${var.prefix}-instance"
/// }
/// ```
/// ```gleam
/// Locals(dict.from_list([
///   #("common_tags", hcl.MapExpr([
///     #(hcl.IdentKey("Environment"), hcl.ref("var.environment")),
///     #(hcl.IdentKey("Project"), hcl.StringLiteral("my-project")),
///   ])),
///   #("instance_name", hcl.TemplateExpr([
///     hcl.Interpolation(hcl.ref("var.prefix")),
///     hcl.LiteralPart("-instance"),
///   ])),
/// ]))
/// ```
pub type Locals {
  Locals(values: Dict(String, Expr))
}

// ============================================================================
// MODULE BLOCK
// ============================================================================

/// Module call block.
///
/// Reference: https://developer.hashicorp.com/terraform/language/modules
///
/// ## Example
/// ```hcl
/// module "vpc" {
///   source  = "terraform-aws-modules/vpc/aws"
///   version = "5.0.0"
///
///   name            = "my-vpc"
///   cidr            = "10.0.0.0/16"
///   azs             = ["us-west-2a", "us-west-2b"]
///   private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
///
///   providers = {
///     aws = aws.west
///   }
/// }
/// ```
/// ```gleam
/// Module(
///   name: "vpc",
///   source: "terraform-aws-modules/vpc/aws",
///   version: option.Some("5.0.0"),
///   inputs: dict.from_list([
///     #("name", hcl.StringLiteral("my-vpc")),
///     #("cidr", hcl.StringLiteral("10.0.0.0/16")),
///     #("azs", hcl.ListExpr([
///       hcl.StringLiteral("us-west-2a"),
///       hcl.StringLiteral("us-west-2b"),
///     ])),
///   ]),
///   providers: option.Some(dict.from_list([
///     #("aws", hcl.ref("aws.west")),
///   ])),
///   meta: hcl.empty_meta(),
/// )
/// ```
pub type Module {
  Module(
    name: String,
    source: String,
    version: Option(String),
    inputs: Dict(String, Expr),
    providers: Option(Dict(String, Expr)),
    meta: MetaArguments,
  )
}

// ============================================================================
// COMPLETE CONFIGURATION
// ============================================================================

/// A complete Terraform configuration (one or more .tf files merged).
///
/// ## Example
/// ```gleam
/// Config(
///   terraform: option.Some(TerraformSettings(...)),
///   providers: [Provider(...)],
///   resources: [Resource(...)],
///   data_sources: [DataSource(...)],
///   variables: [Variable(...)],
///   outputs: [Output(...)],
///   locals: [Locals(...)],
///   modules: [Module(...)],
/// )
/// ```
pub type Config {
  Config(
    terraform: Option(TerraformSettings),
    providers: List(Provider),
    resources: List(Resource),
    data_sources: List(DataSource),
    variables: List(Variable),
    outputs: List(Output),
    locals: List(Locals),
    modules: List(Module),
  )
}

// ============================================================================
// HELPER CONSTRUCTORS
// ============================================================================

/// Create an empty configuration.
pub fn empty_config() -> Config {
  Config(
    terraform: option.None,
    providers: [],
    resources: [],
    data_sources: [],
    variables: [],
    outputs: [],
    locals: [],
    modules: [],
  )
}

/// Create a simple provider with just attributes.
/// ```gleam
/// simple_provider("aws", [#("region", hcl.StringLiteral("us-west-2"))])
/// ```
pub fn simple_provider(name: String, attrs: List(#(String, Expr))) -> Provider {
  Provider(
    name: name,
    alias: option.None,
    attributes: dict.from_list(attrs),
    blocks: [],
  )
}

/// Create a simple resource with just attributes.
/// ```gleam
/// simple_resource("aws_instance", "web", [
///   #("ami", hcl.StringLiteral("ami-12345")),
///   #("instance_type", hcl.StringLiteral("t2.micro")),
/// ])
/// ```
pub fn simple_resource(
  type_: String,
  name: String,
  attrs: List(#(String, Expr)),
) -> Resource {
  Resource(
    type_: type_,
    name: name,
    attributes: dict.from_list(attrs),
    blocks: [],
    meta: hcl.empty_meta(),
    lifecycle: option.None,
  )
}

/// Create a simple data source with just attributes.
/// ```gleam
/// simple_data("aws_ami", "ubuntu", [#("most_recent", hcl.BoolLiteral(True))])
/// ```
pub fn simple_data(
  type_: String,
  name: String,
  attrs: List(#(String, Expr)),
) -> DataSource {
  DataSource(
    type_: type_,
    name: name,
    attributes: dict.from_list(attrs),
    blocks: [],
    meta: hcl.empty_meta(),
  )
}

/// Create a simple variable with just a default value.
/// ```gleam
/// simple_variable("region", hcl.StringLiteral("us-west-2"))
/// ```
pub fn simple_variable(name: String, default: Expr) -> Variable {
  Variable(
    name: name,
    type_constraint: option.None,
    default: option.Some(default),
    description: option.None,
    sensitive: option.None,
    nullable: option.None,
    validation: [],
  )
}

/// Create a simple output.
/// ```gleam
/// simple_output("ip", hcl.ref("aws_instance.web.public_ip"))
/// ```
pub fn simple_output(name: String, value: Expr) -> Output {
  Output(
    name: name,
    value: value,
    description: option.None,
    sensitive: option.None,
    depends_on: option.None,
    precondition: [],
  )
}

/// Create a simple module call.
/// ```gleam
/// simple_module("vpc", "./modules/vpc", [
///   #("cidr", hcl.StringLiteral("10.0.0.0/16")),
/// ])
/// ```
pub fn simple_module(
  name: String,
  source: String,
  inputs: List(#(String, Expr)),
) -> Module {
  Module(
    name: name,
    source: source,
    version: option.None,
    inputs: dict.from_list(inputs),
    providers: option.None,
    meta: hcl.empty_meta(),
  )
}
