include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${local.module_source.url}?ref=${local.module_source.ref}"
  #source = "../../modules/shared-resources"
}

locals {
  module_inputs = lookup(include.root.locals.config, path_relative_to_include()).inputs
  module_source = lookup(include.root.locals.config.modules, path_relative_to_include())
  db_secrets = lookup(include.root.locals.config, "common_inputs").secrets

  project_id              = local.module_inputs.project_id
  routing_project_id      = local.module_inputs.routing_project_id
  region                  = include.root.locals.region
  self_vpc_name           = local.module_inputs.self_vpc_name
  routing_vpc_name        = local.module_inputs.routing_vpc_name
  sql_user_name           = local.db_secrets.POSTGRESS_USER
  sql_password            = local.db_secrets.POSTGRESS_PASSWORD
  consumers               = local.module_inputs.consumers
  routing_subnet_name     = "routing-subnet"
  routing_subnet_ip_range = "10.10.0.0/28"
  all_apis_global_ip      = "10.0.1.1"
}

inputs = {
  project_id = local.project_id
  region     = local.region

  subnetworks = {
    routing-subnet = {
      project       = local.project_id
      vpc_name      = local.routing_vpc_name
      subnet_name   = local.routing_subnet_name
      purpose       = "PRIVATE"
      region        = local.region
      ip_cidr_range = local.routing_subnet_ip_range
    }
  }

  psc_endpoints = {
    "global-all_apis" = {
      endpoint_name = "pscglobalallapis"
      project       = local.routing_project_id
      location      = "global"
      network_name  = local.routing_vpc_name
      target        = "all-apis"
      ip_address = {
        name    = "all-apis-global-ip"
        purpose = "PRIVATE_SERVICE_CONNECT"
        address = local.all_apis_global_ip
      }
    }
  }

  dns_zones = {
    "cloud-run-dns-zone" = {
      name        = "cloud-run-dns-zone"
      dns_name    = "app.run."
      description = "Managed DNS zone for cloud run"
      visibility  = "private"
      private_visibility_networks = concat([
        "projects/${local.routing_project_id}/global/networks/${local.routing_vpc_name}"
        ],
        [
          for project_id, vpc_name in local.consumers : "projects/${project_id}/global/networks/${vpc_name}"
      ])
      recordsets = [
        {
          name = "*."
          type = "CNAME"
          ttl  = 300
          rrdatas = [
            "app.run.",
          ]
        },
        {
          name = ""
          type = "A"
          ttl  = 300
          rrdatas = [
            local.all_apis_global_ip
          ]
        },
      ]
    }
  }

  sql_instances = {
    shared-app-db = {
      name                = "shared-app-db"
      database_version    = "POSTGRES_17"
      project             = local.project_id
      region              = local.region
      availability_type   = "REGIONAL"
      user_labels         = {}
      tier                = "db-g1-small"
      edition             = "ENTERPRISE"
      disk_size           = 10
      disk_type           = "PD_HDD"
      deletion_protection = false
      ip_configuration = {
        ipv4_enabled       = false
        private_network    = local.self_vpc_name
        allocated_ip_range = null
      }
      psc_config = {
        allowed_consumer_projects = [local.project_id, local.routing_project_id]

        auto_connections = {
          consumer_network            = local.routing_vpc_name
          consumer_service_project_id = local.routing_project_id
        }
      }
      users = {
        "app-user" = {
          user_name     = local.sql_user_name
          user_password = local.sql_password
        }
      }
      dns_zone = {
        name           = "db-populationapp"
        dns_name       = "populationapp.internal."
        recordset_name = "db."
      }
      databases = {
        "population-data" = "population_data"
      }
    }
  }
}