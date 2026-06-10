resource "google_compute_firewall_policy_rule" "fw_policy_ingress_rules" {
  for_each                = var.firewall_policy_ingress_rules
  firewall_policy         = var.firewall_policy_name
  priority                = each.value.priority
  enable_logging          = each.value.enable_logging
  action                  = each.value.action
  direction               = "INGRESS"
  disabled                = each.value.disabled
  target_service_accounts = try(each.value.target_service_accounts, null)

  match {
    src_ip_ranges = try(each.value.src_ip_ranges, null)
    src_fqdns     = try(each.value.src_fqdns, null)

    dynamic "layer4_configs" {
      for_each = try(each.value.layer4_configs, [])
      content {
        ip_protocol = layer4_configs.value.ip_protocol
        ports       = try(layer4_configs.value.ports, null)
      }
    }
  }
  lifecycle {
    precondition {
      condition     = length(try(each.value.layer4_configs, [])) > 0
      error_message = "At least one layer4_config must be specified."
    }
  }
}

resource "google_compute_firewall_policy_rule" "fw_policy_egress_rules" {
  for_each                = var.firewall_policy_egress_rules
  firewall_policy         = var.firewall_policy_name
  priority                = each.value.priority
  enable_logging          = each.value.enable_logging
  action                  = each.value.action
  direction               = "EGRESS"
  disabled                = each.value.disabled
  target_service_accounts = try(each.value.target_service_accounts, null)

  match {
    dest_ip_ranges = try(each.value.dest_ip_ranges, null)
    dest_fqdns     = try(each.value.dest_fqdns, null)

    dynamic "layer4_configs" {
      for_each = try(each.value.layer4_configs, [])
      content {
        ip_protocol = layer4_configs.value.ip_protocol
        ports       = try(layer4_configs.value.ports, null)
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(try(each.value.layer4_configs, [])) > 0
      error_message = "At least one layer4_config must be specified."
    }
  }
}

resource "google_compute_firewall" "firewall_rules" {
  for_each    = var.firewall_rules
  project     = var.project_id
  name        = each.value.name
  description = try(each.value.description, null)
  network     = "projects/${var.host_project_id}/global/networks/${var.vpc_name}"
  direction   = each.value.direction

  dynamic "allow" {
    for_each = coalesce(each.value.allow, [])
    content {
      protocol = try(allow.value.protocol, null)
      ports    = try(allow.value.ports, [])
    }
  }

  dynamic "deny" {
    for_each = coalesce(each.value.deny, [])
    content {
      protocol = try(deny.value.protocol, null)
      ports    = try(deny.value.ports, [])
    }

  }

  source_ranges           = try(each.value.source_ranges, null)
  source_service_accounts = try(each.value.source_service_accounts, null)
  source_tags             = try(each.value.source_tags, null)

  destination_ranges      = try(each.value.destination_ranges, null)
  target_service_accounts = try(each.value.target_service_accounts, null)
  target_tags             = try(each.value.target_tags, null)

  disabled = each.value.disabled
  priority = each.value.priority

  enable_logging = each.value.enable_logging

  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      metadata = each.value.log_config_metadata
    }
  }
  dynamic "params" {
    for_each = try(each.value.resource_manager_tags, null) != null ? [1] : []
    content {
      resource_manager_tags = each.value.resource_manager_tags
    }
  }
}