locals {
  recordsets = merge([
    for zone_key, dns_zone in var.dns_zones : {
      for recordset in dns_zone.recordsets :
      "${zone_key}/${recordset.name}/${recordset.type}" => {
        zone_key = zone_key
        dns_name = dns_zone.dns_name
        name     = recordset.name
        type     = recordset.type
        ttl      = recordset.ttl
        rrdatas  = recordset.rrdatas
      }
    }
  ]...)
}

resource "google_dns_managed_zone" "private-zone" {
  for_each    = var.dns_zones
  name        = each.value.name
  dns_name    = each.value.dns_name
  description = each.value.description
  labels      = try(each.value.labels, null)

  visibility = each.value.visibility

  private_visibility_config {
    networks {
      network_url = "projects/${var.project_id}/global/networks/${var.vpc_name}"
    }
  }
}

resource "google_dns_record_set" "a" {
  for_each     = local.recordsets
  name         = "${each.value.name}${each.value.dns_name}"
  managed_zone = google_dns_managed_zone.private-zone["${each.value.zone_key}"].name
  type         = each.value.type
  ttl          = each.value.ttl

  rrdatas = each.value.rrdatas
}