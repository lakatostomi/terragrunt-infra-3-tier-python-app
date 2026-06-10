include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "environment" {
  path   = find_in_parent_folders("environment.hcl")
  expose = true
}

terraform {
  source = "${local.module_source.url}?ref=${local.module_source.ref}"
  #source = "../../../modules/infra-stack"
}

locals {
  env_config    = lookup(include.root.locals.config, reverse(split("/", get_parent_terragrunt_dir("environment")))[0])
  module_inputs = lookup(local.env_config, reverse(split("/", path_relative_to_include("root")))[0])
  module_source = lookup(include.root.locals.config.modules, reverse(split("/", path_relative_to_include("root")))[0])

  fw-policy-name   = local.module_inputs.fw-policy-name
  region           = local.module_inputs.region
  app_subnet       = local.module_inputs.app_subnet
  app_subnet_range = local.module_inputs.app_subnet_range
  frontend_dev_sa  = local.module_inputs.frontend_dev_sa
  backend_dev_sa   = local.module_inputs.backend_dev_sa
}

inputs = {
  firewall_policy_name = local.fw-policy-name

  subnetworks = {
    app-subnet = {
      subnet_name   = local.app_subnet
      purpose       = "PRIVATE"
      region        = local.region
      ip_cidr_range = local.app_subnet_range
    }
  }

  service_accounts = {
    cloudbuild-app-sa = {
      name = "cloudbuild-app-sa"
      iam_project_roles = [
        "roles/logging.logWriter",
        "roles/artifactregistry.writer",
      ]
    }
  }

  firewall_policy_ingress_rules = {
    ingress-allow-psql = {
      priority       = 100
      action         = "allow"
      src_ip_ranges  = [local.app_subnet_range]
      enable_logging = false
      layer4_configs = [{
        ip_protocol = "tcp"
        ports       = ["5432"]
      }]
    }
  }

  firewall_rules = {
    allow-http-between-tiers = {
      name      = "allow-http-frontend-backend"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["8080"]
      }]
      source_service_accounts = [local.frontend_dev_sa]
      target_service_accounts = [local.backend_dev_sa]
    }
  }

  # subnet_iam = {
  #   "${local.region}/${local.app_subnet}" = [
  #     local.frontend_dev_sa,
  #     local.backend_dev_sa
  #     ]
  # }
  # enable_cloud_run_direct_egress = true
}