locals {
  root_inputs = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  env_inputs  = lookup(local.root_inputs.locals.config, reverse(split("/", get_parent_terragrunt_dir()))[0]).inputs

  project_id      = local.env_inputs.project_id
  self_vpc_name   = local.env_inputs.self_vpc_name
  host_project_id = local.env_inputs.host_project_id

}

inputs = {
  project_id      = local.project_id
  vpc_name        = local.self_vpc_name
  host_project_id = local.host_project_id
}