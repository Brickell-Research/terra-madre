import gleam/dict
import gleam/io
import gleam/option
import gleeunit
import terra_madre/hcl
import terra_madre/render
import terra_madre/terraform

pub fn main() {
  gleeunit.main()
}

pub fn output_format_verification_test() {
  let config = terraform.Config(
    terraform: option.Some(terraform.TerraformSettings(
      required_version: option.None,
      required_providers: dict.from_list([
        #("datadog", terraform.ProviderRequirement("DataDog/datadog", option.Some("~> 3.0"))),
      ]),
      backend: option.None,
      cloud: option.None,
    )),
    providers: [],
    variables: [],
    locals: [],
    data_sources: [],
    resources: [
      terraform.simple_resource("datadog_slo", "test", [
        #("name", hcl.StringLiteral("Test SLO")),
        #("tags", hcl.ListExpr([
          hcl.StringLiteral("tag1"),
          hcl.StringLiteral("tag2"),
          hcl.StringLiteral("tag3"),
        ])),
      ]),
    ],
    modules: [],
    outputs: [],
  )
  let output = render.render_config(config)
  io.println("=== Generated Terraform Output ===")
  io.println(output)
  io.println("=== End ===")
}
