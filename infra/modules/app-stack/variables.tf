variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "service_accounts" {
  type = map(object({
    name              = string
    iam_project_roles = optional(list(string))
    iam               = optional(map(list(string)))
  }))
  default = {}
  validation {
    condition = alltrue([
      for sa in values(var.service_accounts) :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", sa.name))
    ])
    error_message = "Service account name must match regular expression [a-z]([-a-z0-9]*[a-z0-9]) and must be 6-30 characters long!"
  }
  validation {
    condition = alltrue(flatten([
      for sa in var.service_accounts : [
        for principal in keys(coalesce(sa.iam, {})) :
        can(regex("^(serviceAccount|user|group):", principal))
      ]
    ]))
    error_message = "Service account IAM principals must start with serviceAccount:, user:, or group:."
  }
}

variable "artifact_registries" {
  type = map(object({
    name                   = string
    location               = string
    description            = optional(string, null)
    format                 = optional(string, "DOCKER")
    cleanup_policy_dry_run = optional(bool, false)
    cleanup_policies = optional(list(object({
      id     = string
      action = optional(string, "KEEP")
      condition = optional(object({
        tag_state             = optional(string, "ANY")
        tag_prefixes          = optional(list(string), [])
        version_name_prefixes = optional(list(string), [])
        package_name_prefixes = optional(list(string), [])
        older_than            = optional(string, null)
        newer_than            = optional(string, null)
      }))
      most_recent_versions = optional(object({
        package_name_prefixes = optional(list(string), [])
        keep_count            = optional(number, 3)
      }))
    })), [])
  }))

  validation {
    condition = alltrue(flatten([
      for repo in values(var.artifact_registries) : [
        for policy in coalesce(repo.cleanup_policies, []) :
        (
          policy.condition != null ||
          policy.most_recent_versions != null
        )
      ]
    ]))

    error_message = "Each cleanup policy must specify condition or most_recent_versions."
  }

  validation {
    condition = alltrue([
      for repo in values(var.artifact_registries) :
      contains(["DOCKER"], repo.format)
    ])

    error_message = "Invalid Artifact Registry format, module only supports DOCKER!"
  }
  default = {}
}

variable "cloud_build_triggers" {
  type = map(object({
    name        = string
    location    = string
    project     = string
    description = optional(string, null)
    disabled    = optional(bool, false)
    github = object({
      owner                           = string
      name                            = string
      enterprise_config_resource_name = optional(string)
      push = optional(object({
        invert_regex = optional(bool, false)
        branch       = optional(string)
        tag          = optional(string)
      }))
      pull_request = optional(object({
        branch          = string
        comment_control = optional(string, "COMMENTS_DISABLED")
        invert_regex    = optional(bool, false)
      }))
    })
    service_account_email = optional(string, null)
    filename              = string
    ignored_files         = optional(list(string), [])
    included_files        = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for trigger in values(var.cloud_build_triggers) :
      (
        (trigger.github.push != null && trigger.github.pull_request == null) ||
        (trigger.github.push == null && trigger.github.pull_request != null)
      )
    ])
    error_message = "Each build trigger must specify a push or pull_request."
  }

  validation {
    condition = alltrue([
      for trigger in values(var.cloud_build_triggers) :
      trigger.filename != null
    ])

    error_message = "filename is required."
  }

  validation {
    condition = alltrue([
      for trigger in values(var.cloud_build_triggers) :
      length(trigger.github.owner) > 0 &&
      length(trigger.github.name) > 0
    ])

    error_message = "GitHub owner and repository name are required."
  }

  validation {
    condition = alltrue(flatten([
      for trigger in values(var.cloud_build_triggers) : [
        trigger.github.push == null ? true : (
          (
            trigger.github.push.branch != null &&
            trigger.github.push.tag == null
          ) ||
          (
            trigger.github.push.branch == null &&
            trigger.github.push.tag != null
          )
        )
      ]
    ]))

    error_message = "Push trigger must specify exactly one of branch or tag."
  }
}

variable "storage_buckets" {
  type = map(object({
    name                        = string
    location                    = string
    versioning                  = optional(bool, false)
    force_destroy               = bool
    uniform_bucket_level_access = optional(bool, false)
    iam                         = optional(map(list(string)))
  }))
  default = {}
}

variable "repository_data" {
  type = map(object({
    repo_id       = string
    image_name    = string
    image_tag     = string
    repo_location = string
  }))
  default = {}
}

variable "cloud_run_services" {
  type = map(object({
    service_name         = string
    location             = string
    deletion_protection  = optional(bool, false)
    ingress              = optional(string, "INGRESS_TRAFFIC_ALL")
    iap_enabled          = optional(bool, false)
    launch_stage         = optional(string, null)
    invoker_iam_disabled = optional(bool, true)
    containers = map(object({
      name           = string
      image          = optional(string, null)
      repository_ref = optional(string, null)
      ports = optional(object({
        name           = optional(string, null)
        container_port = optional(number)
      }))
      resources = optional(object({
        cpu_idle          = optional(bool, false)
        startup_cpu_boost = optional(bool, false)
        limits = optional(object({
          cpu    = optional(string, "1")
          memory = optional(string, "512Mi")
          gpu    = optional(string, null)
        }))
      }))
      envs = optional(map(string), {})
    }))
    vpc_access = optional(object({
      egress          = optional(string, "ALL_TRAFFIC")
      subnetwork_name = string
      tags            = optional(list(string), [])
    }))
    scaling = optional(object({
      min_instance_count = optional(number)
      max_instance_count = optional(number)
    }))
    project_service_account_key = optional(string, null)
  }))
  default = {}
  validation {
    condition = alltrue(flatten([
      for service in values(var.cloud_run_services) : [
        for container in values(service.containers) : (
          container.repository_ref != null && container.image == null ||
          container.repository_ref == null && container.image != null
        )
      ]
    ]))
    error_message = "Specify exactly one of image or repository_ref!"
  }

  validation {
    condition = alltrue(flatten([
      for service in values(var.cloud_run_services) : [
        for container in values(service.containers) : (
          container.repository_ref == null ||
          contains(keys(var.repository_data), container.repository_ref)
        )
      ]
    ]))
    error_message = "repository_ref must reference an existing repository_data key."
  }

  validation {
    condition = alltrue([
      for service in values(var.cloud_run_services) : (
        service.project_service_account_key != null ||
        contains(keys(var.service_accounts), service.project_service_account_key)
      )
      ]
    )
    error_message = "project_service_account_key must reference an existing service account key."
  }

  validation {
    condition = alltrue([
      for service in values(var.cloud_run_services) :
      (
        service.scaling == null ||
        service.scaling.max_instance_count == null ||
        service.scaling.min_instance_count == null ||
        service.scaling.min_instance_count <= service.scaling.max_instance_count
      )
    ])

    error_message = "min_instance_count must be less than or equal to max_instance_count."
  }
}

variable "secrets" {
  type    = map(string)
  default = {}
  validation {
    condition = alltrue([
      for secret, secret_version in var.secrets :
      length(secret) > 0 &&
      length(secret_version) > 0
    ])

    error_message = "Both secret and secret version must be specified!"
  }
}

variable "dns_zones" {
  type = map(object({
    name                        = string
    dns_name                    = string
    description                 = optional(string, "Managed DNS Zone")
    labels                      = optional(map(string))
    visibility                  = string
    private_visibility_networks = list(string)
    recordsets = list(object({
      name    = string
      type    = string
      ttl     = optional(number, 300)
      rrdatas = list(string)
    }))
  }))
  default = {}
  validation {
    condition = alltrue([
      for dns_zone in values(var.dns_zones) :
      contains(["private"], dns_zone.visibility)
    ])
    error_message = "The module only allows to create private dns zones!"
  }

  validation {
    condition = alltrue([
      for dns_zone in values(var.dns_zones) :
      alltrue([
        for recordset in dns_zone.recordsets :
        contains(["A", "CNAME"], recordset.type)
      ])
    ])
    error_message = "The module only allows to create private dns zones with recordset 'A' or 'CNAME'!"
  }
}