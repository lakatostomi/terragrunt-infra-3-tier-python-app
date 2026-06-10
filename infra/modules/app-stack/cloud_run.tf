data "google_artifact_registry_docker_image" "image" {
  for_each      = var.repository_data
  location      = each.value.repo_location
  repository_id = each.value.repo_id
  image_name    = "${each.value.image_name}:${each.value.image_tag}"
}

resource "google_cloud_run_v2_service" "cloud_run_service" {
  for_each             = var.cloud_run_services
  provider             = google-beta
  project              = var.project_id
  location             = each.value.location
  name                 = each.value.service_name
  deletion_protection  = each.value.deletion_protection
  ingress              = each.value.ingress
  iap_enabled          = each.value.iap_enabled
  launch_stage         = each.value.launch_stage
  invoker_iam_disabled = each.value.invoker_iam_disabled

  template {
    dynamic "containers" {
      for_each = each.value.containers
      content {
        name = containers.value.name
        image = (
          containers.value.repository_ref != null
          ? data.google_artifact_registry_docker_image.image[containers.value.repository_ref].self_link
          : containers.value.image
        )
        dynamic "ports" {
          for_each = (containers.value.ports != null ? [containers.value.ports] : [])
          content {
            name           = ports.value.name
            container_port = ports.value.container_port
          }
        }
        dynamic "resources" {
          for_each = (containers.value.resources != null ? [containers.value.resources] : [])
          content {
            cpu_idle          = resources.value.cpu_idle
            startup_cpu_boost = resources.value.startup_cpu_boost
            limits = merge(
              {
                cpu    = resources.value.limits.cpu
                memory = resources.value.limits.memory
              },
              resources.value.limits.gpu != null ? {
                "nvidia.com/gpu" = resources.value.limits.gpu
              } : {}
            )
          }
        }
        dynamic "env" {
          for_each = containers.value.envs
          content {
            name  = env.key
            value = env.value
          }
        }
      }

    }
    dynamic "scaling" {
      for_each = (each.value.scaling != null ? [each.value.scaling] : [])
      content {
        min_instance_count = scaling.value.min_instance_count
        max_instance_count = scaling.value.max_instance_count
      }
    }

    dynamic "vpc_access" {
      for_each = (each.value.vpc_access != null ? [each.value.vpc_access] : [])
      content {
        network_interfaces {
          network    = "projects/${var.project_id}/global/networks/${var.vpc_name}"
          subnetwork = "projects/${var.project_id}/regions/${each.value.location}/subnetworks/${vpc_access.value.subnetwork_name}"
          tags       = vpc_access.value.tags
        }
        egress = vpc_access.value.egress
      }
    }
    service_account = (
      each.value.project_service_account_key != null
      ? google_service_account.service_account[each.value.project_service_account_key].email
      : null
    )
  }
}