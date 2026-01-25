//// Terra Madre - Terraform/HCL Types for Gleam
////
//// A Gleam library for representing and working with Terraform configurations.
////
//// ## Modules
//// - `terra_madre/hcl` - Core HCL types (expressions, blocks, meta-arguments)
//// - `terra_madre/terraform` - Terraform-specific blocks (resource, provider, etc.)
//// - `terra_madre/render` - Render Terraform types to HCL strings
////
//// ## References
//// - [HCL Native Syntax Specification](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md)
//// - [Terraform Configuration Language](https://developer.hashicorp.com/terraform/language)
////
//// ## Example
//// ```gleam
//// import terra_madre/hcl
//// import terra_madre/terraform
////
//// // Create an AWS provider
//// let provider = terraform.simple_provider("aws", [
////   #("region", hcl.StringLiteral("us-west-2")),
//// ])
////
//// // Create an EC2 instance resource
//// let instance = terraform.simple_resource("aws_instance", "web", [
////   #("ami", hcl.StringLiteral("ami-12345")),
////   #("instance_type", hcl.StringLiteral("t2.micro")),
//// ])
////
//// // Build a reference using dot notation
//// let ip_ref = hcl.ref("aws_instance.web.public_ip")
//// ```

// Re-export core HCL types
pub type Expr =
  hcl.Expr

pub type Block =
  hcl.Block

pub type MetaArguments =
  hcl.MetaArguments

pub type Lifecycle =
  hcl.Lifecycle

// Re-export Terraform types
pub type Config =
  terraform.Config

pub type Resource =
  terraform.Resource

pub type Provider =
  terraform.Provider

pub type DataSource =
  terraform.DataSource

pub type Variable =
  terraform.Variable

pub type Output =
  terraform.Output

pub type Module =
  terraform.Module

pub type Locals =
  terraform.Locals

// Re-export commonly used helpers
import terra_madre/hcl
import terra_madre/terraform

/// Build a reference chain from dot-notation.
/// Shorthand for `hcl.ref`.
pub fn ref(path: String) -> Expr {
  hcl.ref(path)
}

/// Create empty meta-arguments.
/// Shorthand for `hcl.empty_meta`.
pub fn empty_meta() -> MetaArguments {
  hcl.empty_meta()
}

/// Create empty lifecycle configuration.
/// Shorthand for `hcl.empty_lifecycle`.
pub fn empty_lifecycle() -> Lifecycle {
  hcl.empty_lifecycle()
}

/// Create an empty Terraform configuration.
/// Shorthand for `terraform.empty_config`.
pub fn empty_config() -> Config {
  terraform.empty_config()
}
