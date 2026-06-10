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
  #source = "../../../modules/app-stack"
}

locals {
  env_config    = lookup(include.root.locals.config, reverse(split("/", get_parent_terragrunt_dir("environment")))[0])
  module_inputs = lookup(local.env_config, reverse(split("/", path_relative_to_include("root")))[0])
  module_source = lookup(include.root.locals.config.modules, reverse(split("/", path_relative_to_include("root")))[0])

  project_id               = local.module_inputs.project_id
  region                   = local.module_inputs.region
  app_subnet               = local.module_inputs.app_subnet
  app_cicd_service_account = local.module_inputs.app_cicd_service_account
  app_secrets              = local.module_inputs.secrets
}

inputs = {
  service_accounts = {
    frontend-runtime-sa = {
      name = "frontend-runtime-sa"
      iam_project_roles = [
        "roles/artifactregistry.reader",
      ]
    }
    backend-runtime-sa = {
      name = "backend-runtime-sa"
      iam_project_roles = [
        "roles/storage.objectUser",
        "roles/artifactregistry.reader",
        "roles/secretmanager.secretAccessor"
      ]
    }
  }

  artifact_registries = {
    frontend-registry = {
      location    = local.region
      name        = "populationapp-frontend"
      description = "Streamlit app registry"
      format      = "DOCKER"

      cleanup_policies = [{
        id     = "delete-untagged"
        action = "DELETE"
        condition = {
          tag_state = "UNTAGGED"
        }
      }]
    }

    backend-registry = {
      location    = local.region
      name        = "populationapp-backend"
      description = "Backend app registry"
      format      = "DOCKER"

      cleanup_policies = [{
        id     = "delete-untagged"
        action = "DELETE"
        condition = {
          tag_state = "UNTAGGED"
        }
      }]
    }
  }

  cloud_build_triggers = {
    frontend-trigger = {
      name        = "fontend-app-dev-push-trigger"
      location    = local.region
      project     = local.project_id
      description = "Push tigger to build image from source code of the frontend app"

      github = {
        owner = "lakatostomi"
        name  = "population-data-st-frontend-app"
        push = {
          branch = "^main$"
        }
      }

      service_account_email = local.app_cicd_service_account
      filename              = "cloudbuild.yaml"

      ignored_files  = ["*.md", ".gitignore", ".dockerignore"]
      included_files = ["**/*.py", "**/requirements.txt", "Dockerfile", "cloudbuild.yaml"]

    }

    backend-trigger = {
      name        = "backend-app-dev-push-trigger"
      location    = local.region
      project     = local.project_id
      description = "Push tigger to build image from source code of the backend app"

      github = {
        owner = "lakatostomi"
        name  = "population-data-fastapi-backend-app"
        push = {
          branch = "^main$"
        }
      }

      service_account_email = local.app_cicd_service_account
      filename              = "cloudbuild.yaml"

      ignored_files  = ["*.md", ".gitignore", ".dockerignore"]
      included_files = ["**/*.py", "**/requirements.txt", "Dockerfile", "cloudbuild.yaml"]

    }
  }

  repository_data = {
    backend_data_ref = {
      repo_location = local.region
      repo_id       = "populationapp-backend"
      image_name    = "backend_app"
      image_tag     = "latest"
    }

    frontend_data_ref = {
      repo_location = local.region
      repo_id       = "populationapp-frontend"
      image_name    = "frontend_app"
      image_tag     = "latest"
    }
  }

  # cloud_run_services = {
  #   backend_service = {
  #     location             = local.region
  #     service_name         = "population-app-backend-service"
  #     deletion_protection  = false
  #     ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  #     invoker_iam_disabled = true
  #     containers = {
  #       "backend-service-1" = {
  #         name           = "backend-service-1"
  #         repository_ref = "backend_data_ref"
  #         ports = {
  #           container_port = 8080
  #         }
  #       }
  #     }
  #     scaling = {
  #       max_instance_count = 1
  #       max_instance_count = 2
  #     }
  #     vpc_access = {
  #       subnetwork_name = local.app_subnet
  #     }
  #     project_service_account_key = "backend-runtime-sa"
  #   }

  #   frontend_service = {
  #     location             = local.region
  #     service_name         = "population-app-frontend-service"
  #     deletion_protection  = false
  #     ingress              = "INGRESS_TRAFFIC_ALL"
  #     invoker_iam_disabled = true
  #     containers = {
  #       "frontend-service-1" = {
  #         name           = "frontend-service-1"
  #         repository_ref = "frontend_data_ref"
  #         ports = {
  #           container_port = 8080
  #         }
  #         envs = {
  #         "CLOUD_API_SERVER" = "https://population-app-backend-service-307608633870.europe-west1.run.app"
  #       }
  #       }
  #     }
  #     scaling = {
  #       max_instance_count = 1
  #       max_instance_count = 2
  #     }
  #     vpc_access = {
  #       subnetwork_name = local.app_subnet
  #       egress = "ALL_TRAFFIC"
  #     }
  #     project_service_account_key = "frontend-runtime-sa"
  #   }
  # }

  secrets = local.app_secrets
}

