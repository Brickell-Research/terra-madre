# Terra Madre Roadmap

## 1.0.0 - Generation

Core functionality for generating Terraform/HCL configurations.

- [ ] **Renderer** - `render_expr`, `render_block`, `render_config` with pretty-printing
- [ ] **Type Expressions** - `TypeExpr` for variable type constraints (`string`, `list(object({...}))`, etc.)
- [ ] **Provisioners** - `local-exec`, `remote-exec`, `file` block types
- [ ] **Modern Blocks** - `import`, `moved`, `removed`, `check` (Terraform 1.5+)
- [ ] **README** - usage examples and documentation

## 2.0.0 - Parsing & Analysis

Full round-trip support and configuration analysis.

- [ ] **Parser** - `parse_string`, `parse_file` -> `Result(Config, ParseError)`
- [ ] **Validation** - label counts, required attributes, type constraints
- [ ] **Reference Utilities** - dependency extraction, reference resolution
- [ ] **Config Merging** - combine multiple .tf files
- [ ] **Diff/Comparison** - detect changes between configs
