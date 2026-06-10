locals {
  config = yamldecode(file("config.yaml"))

  backend_bucket = lookup(local.config, "backend_bucket")
  impersonate_sa = lookup(local.config, "impersonate_sa")
}

remote_state {
  backend = "gcs"
  config = {
    bucket = "${local.backend_bucket}"
    prefix = "terraform/state/${get_path_from_repo_root()}"
  }
  generate = {
    path      = "./backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    provider "google" {
        project = var.project_id
        region = var.region
        impersonate_service_account = "${local.impersonate_sa}"
    }
    provider "google-beta" {
        project = var.project_id
        region = var.region
        impersonate_service_account = "${local.impersonate_sa}"
    }
    EOT
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    terraform {
        required_version = ">= 1.12.4"
      required_providers {
        google = {
          source = "hashicorp/google"
          version = "7.33"
        }
        google-beta = {
          source = "hashicorp/google-beta"
          version = "7.33"
        }
      }
    }
    EOT
}