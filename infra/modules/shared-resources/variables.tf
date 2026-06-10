variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "sql_instances" {
  type = map(object({
    name                  = string
    database_version      = string
    project               = string
    region                = string
    availability_type     = optional(string, "REGIONAL")
    user_labels           = optional(map(string))
    tier                  = string
    edition               = optional(string, "ENTERPRISE")
    connector_enforcement = optional(string, "NOT_REQUIRED")
    root_password         = optional(string)
    disk_size             = optional(number, 10)
    disk_type             = optional(string, "PD_HDD")
    deletion_protection   = optional(bool, false)
    ip_configuration = object({
      ipv4_enabled       = optional(bool, false)
      private_network    = optional(string)
      allocated_ip_range = optional(string, null)
    })
    psc_config = optional(object({
      allowed_consumer_projects = optional(list(string))

      auto_connections = optional(object({
        consumer_network            = string
        consumer_service_project_id = string
      }))
    }))
    dns_zone = optional(object({
      name           = string
      dns_name       = string
      recordset_name = string
      ttl            = optional(number, 300)
    }))
    users = optional(map(object({
      user_name     = string
      user_password = string
      user_host     = optional(string)
    })))
    databases = optional(map(string), null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for sql in values(var.sql_instances) :
      sql.dns_zone == null ||
      (
        sql.psc_config != null &&
        sql.psc_config.auto_connections != null
      )
    ])

    error_message = "If dns_zone is configured, psc_config.auto_connections must also be configured."
  }

  validation {
    condition = alltrue([
      for sql in values(var.sql_instances) :
      sql.ip_configuration.ipv4_enabled ||
      sql.ip_configuration.private_network != null
    ])

    error_message = "If ipv4_enabled is false, private_network must be specified."
  }

  validation {
    condition = (
      length(flatten([
        for sql in values(var.sql_instances) : [
          for db in values(sql.databases) :
          db
        ]
      ]))
      ==
      length(distinct(flatten([
        for sql in values(var.sql_instances) : [
          for db in values(sql.databases) :
          db
        ]
      ])))
    )

    error_message = "Database names must be unique across all sql_instances."
  }

  validation {
    condition = alltrue([
      for sql in values(var.sql_instances) :
      sql.psc_config == null ||
      sql.psc_config.auto_connections == null ||
      (
        trim(sql.psc_config.auto_connections.consumer_network, " ") != "" &&
        trim(sql.psc_config.auto_connections.consumer_service_project_id, " ") != ""
      )
    ])

    error_message = "psc_config.auto_connections requires both consumer_network and consumer_service_project_id."
  }
}

variable "psc_endpoints" {
  type = map(object({
    endpoint_name = string
    project       = string
    location      = optional(string, "global")
    network_name  = string
    target        = optional(string, "all-apis")
    ip_address = object({
      name            = string
      purpose         = optional(string, "PRIVATE_SERVICE_CONNECT")
      address         = string
      subnetwork_name = optional(string, null)
    })
  }))
  default = {}
  validation {
    condition = alltrue([
      for endpoint in values(var.psc_endpoints) :
      endpoint.location == "global" ||
      can(regex("^[a-z]+-[a-z0-9]+[0-9]$", endpoint.location))
    ])

    error_message = "Location must be 'global' or a valid GCP region."
  }

  validation {
    condition = alltrue([
      for endpoint in values(var.psc_endpoints) :
    endpoint.location != "global" || endpoint.ip_address.subnetwork_name == null])
    error_message = "If the location is global, a subnetwork can not be defined!"
  }

  validation {
    condition = alltrue([
      for endpoint in values(var.psc_endpoints) :
      endpoint.location == "global" || endpoint.ip_address.subnetwork_name != null && endpoint.ip_address.purpose == "PRIVATE_SERVICE_CONNECT"]
    )
    error_message = "If the location is not global a subnetwork_name is required and purpose must be PRIVATE_SERVICE_CONNECT."
  }

  validation {
    condition = alltrue([
      for endpoint in values(var.psc_endpoints) :
      endpoint.target == "all-apis" || can(regex("^projects/[a-zA-Z0-9_-]+/regions/[a-zA-Z0-9_-]+/serviceAttachments/[a-zA-Z0-9_-]+$", endpoint.target))
    ])
    error_message = "Only two target is accepted: 'all-apis' or a valid serviceAttachment ID!"
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

variable "subnetworks" {
  type = map(object({
    project             = string
    vpc_name            = string
    subnet_name         = string
    purpose             = optional(string, "PRIVATE")
    region              = string
    ip_cidr_range       = string
    secondary_ip_ranges = optional(map(string), {})
  }))
}