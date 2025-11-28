//// Terra Madre - Terraform/HCL Types for Gleam
////
//// A Gleam library for representing and working with Terraform configurations.
////
//// ## Modules
//// - `terra_madre/hcl` - Core HCL types (expressions, blocks, meta-arguments)
//// - `terra_madre/terraform` - Terraform-specific blocks (resource, provider, etc.)
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

