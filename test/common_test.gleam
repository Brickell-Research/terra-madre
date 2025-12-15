import gleam/list
import gleeunit/should
import terra_madre/common

pub fn sanitize_terraform_identifier_test() {
  [
    #("org/team/auth/latency", "org_team_auth_latency"),
    #("my slo name", "my_slo_name"),
    #("my slo, name", "my_slo__name"),
    #("my slo's name", "my_slo_s_name"),
    #("my slo-name", "my_slo-name"),
    #("simple_name", "simple_name"),
    #("123_resource", "_123_resource"),
    #("0invalid", "_0invalid"),
    #("name@domain", "name_domain"),
    #("foo.bar", "foo_bar"),
    #("test:value", "test_value"),
    #("a+b=c", "a_b_c"),
    #("(grouped)", "_grouped_"),
    #("[array]", "_array_"),
  ]
  |> list.each(fn(pair) {
    let #(input, expected) = pair

    input
    |> common.sanitize_terraform_identifier
    |> should.equal(expected)
  })
}
