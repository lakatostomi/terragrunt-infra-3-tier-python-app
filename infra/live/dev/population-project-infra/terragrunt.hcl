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
  env_config    = lookup(include.root.locals.config, basename(dirname(get_terragrunt_dir())))
  module_inputs = lookup(local.env_config, basename(get_terragrunt_dir()))
  module_source = lookup(include.root.locals.config.modules, basename(get_terragrunt_dir()))
  common_inputs = lookup(include.root.locals.config, "common_inputs")

  fw_policy_name    = local.common_inputs.fw_policy_name
  project_id        = local.module_inputs.project_id
  region            = include.root.locals.region
  app_subnet        = local.common_inputs.app_subnet
  app_subnet_range  = local.module_inputs.app_subnet_range
  frontend_sa       = local.common_inputs.frontend_sa
  backend_sa        = local.common_inputs.backend_sa
  cloudbuild_sa     = local.common_inputs.app_cicd_service_account
  frontend_sa_email = format("%s@%s.iam.gserviceaccount.com", local.frontend_sa, local.project_id)
  backend_sa_email  = format("%s@%s.iam.gserviceaccount.com", local.backend_sa, local.project_id)
}

inputs = {
  firewall_policy_name = local.fw_policy_name

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
      name = local.cloudbuild_sa
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
    allow-http-tiers = {
      name      = "allow-http-frontend-backend"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["8080"]
      }]
      source_service_accounts = [local.frontend_sa_email]
      target_service_accounts = [local.backend_sa_email]
    }
  }

  subnet_iam = {
    "${local.region}/app-subnet" = [
      "serviceAccount:${local.frontend_sa_email}",
      "serviceAccount:${local.backend_sa_email}"
    ]
  }
  enable_cloud_run_direct_egress = true
}