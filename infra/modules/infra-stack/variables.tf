variable "project_id" {
  type = string
}

variable "host_project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "firewall_policy_name" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "subnetworks" {
  type = map(object({
    subnet_name              = string
    purpose                  = optional(string, "PRIVATE")
    region                   = string
    ip_cidr_range            = string
    private_ip_google_access = optional(bool, true)
    secondary_ip_ranges      = optional(map(string), {})
  }))
  default = {}
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

variable "firewall_policy_ingress_rules" {
  type = map(object({
    priority                = number
    enable_logging          = optional(bool, false)
    action                  = string
    disabled                = optional(bool, false)
    target_service_accounts = optional(list(string))
    src_ip_ranges           = optional(list(string))
    src_fqdns               = optional(list(string))
    layer4_configs = optional(list(object({
      ip_protocol = string
      ports       = optional(list(string))
    })), [])
  }))
  default = {}
  validation {
    condition = alltrue([
      for r in values(var.firewall_policy_ingress_rules) :
      (
        try(length(r.src_ip_ranges), 0) > 0 ||
        try(length(r.src_fqdns), 0) > 0
      )
    ])

    error_message = "Each ingress rule must define src_ip_ranges or src_fqdns."
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_policy_ingress_rules) :
      contains(["allow", "deny", "goto_next"], rule.action)
    ])
    error_message = "Possible values are: allow, deny, goto_next"
  }

  validation {
    condition = length(distinct([
      for r in values(var.firewall_policy_ingress_rules) :
      r.priority
    ])) == length(values(var.firewall_policy_ingress_rules))

    error_message = "Policy rule priorities must be unique!"
  }
}

variable "firewall_policy_egress_rules" {
  type = map(object({
    priority                = number
    enable_logging          = optional(bool, false)
    action                  = string
    disabled                = optional(bool, false)
    target_service_accounts = optional(list(string))
    dest_ip_ranges          = optional(list(string))
    dest_fqdns              = optional(list(string))
    layer4_configs = optional(list(object({
      ip_protocol = string
      ports       = optional(list(string))
    })), [])
  }))
  default = {}
  validation {
    condition = alltrue([
      for r in values(var.firewall_policy_egress_rules) :
      (
        try(length(r.dest_ip_ranges), 0) > 0 ||
        try(length(r.dest_fqdns), 0) > 0
      )
    ])

    error_message = "Each egress rule must define dest_ip_ranges or dest_fqdns."
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_policy_egress_rules) :
      contains(["allow", "deny", "goto_next"], rule.action)
    ])
    error_message = "Possible values are: allow, deny, goto_next"
  }

  validation {
    condition = length(distinct([
      for r in values(var.firewall_policy_egress_rules) :
      r.priority
    ])) == length(values(var.firewall_policy_egress_rules))

    error_message = "Policy rules priorities must be unique!"
  }
}

variable "firewall_rules" {
  type = map(object({
    name        = string
    description = optional(string)
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    direction               = string
    disabled                = optional(bool, false)
    priority                = optional(number, 1000)
    destination_ranges      = optional(list(string))
    source_ranges           = optional(list(string))
    source_service_accounts = optional(list(string))
    target_service_accounts = optional(list(string))
    source_tags             = optional(list(string))
    target_tags             = optional(list(string))
    enable_logging          = optional(bool, false)
    log_config_metadata     = optional(string, "INCLUDE_ALL_METADATA")
    resource_manager_tags   = optional(map(string))
  }))
  default = {}
  validation {
    condition = alltrue([
      for rule in values(var.firewall_rules) : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", rule.name))
    ])
    error_message = "The name of the firewall must be 1-63 characters long and match the regular expression [a-z]([-a-z0-9]*[a-z0-9])?"
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_rules) : contains(["INGRESS", "EGRESS"], rule.direction)
    ])
    error_message = "Possible values are: INGRESS, EGRESS"
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_rules) :
      (
        rule.direction != "INGRESS" ||
        (
          try(length(rule.source_ranges), 0) > 0 ||
          try(length(rule.source_service_accounts), 0) > 0 ||
          try(length(rule.source_tags), 0) > 0
        )
      )
    ])
    error_message = "For INGRESS traffic, one of source_ranges, source_tags or source_service_accounts is required."
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_rules) :
      (
        rule.direction != "EGRESS" ||
        (
          try(length(rule.destination_ranges), 0) > 0 ||
          try(length(rule.target_service_accounts), 0) > 0 ||
          try(length(rule.target_tags), 0) > 0
        )
      )
    ])
    error_message = "For EGRESS traffic, one of destination_ranges, target_tags or target_service_accounts is required."
  }

  validation {
    condition = alltrue([
      for rule in values(var.firewall_rules) :
      (
        (rule.allow != null && rule.deny == null) ||
        (rule.allow == null && rule.deny != null)
      )
    ])
    error_message = "One of allow or deny is required!"
  }
}

variable "enable_cloud_run_direct_egress" {
  type    = bool
  default = false
}

variable "subnet_iam" {
  type    = map(list(string))
  default = {}
  validation {
    condition = alltrue([
      for key in keys(var.subnet_iam) : length(split("/", key)) == 2 #can(regex("^[^/]+/[^/]+$", key))
    ])
    error_message = "The subnet_iam keys must match the format 'region/subnet'"
  }

  validation {
    condition = alltrue([
      for subnet in keys(var.subnet_iam) :
      contains(keys(var.subnetworks), split("/", subnet)[1])
    ])

    error_message = "Each subnet_iam key must exist in subnetworks."
  }

  validation {
    condition = alltrue([
      for members in values(var.subnet_iam) : alltrue([
        for member in members : can(regex("^(serviceAccount|user|group):", member))
      ])
    ])
    error_message = "Members must start with serviceAccount:, user:, or group:."
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