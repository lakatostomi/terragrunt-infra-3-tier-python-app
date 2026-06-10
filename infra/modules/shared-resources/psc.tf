locals {
  regional_psc = merge([
    for psc_key, psc_endpoint in var.psc_endpoints : {
      "${psc_key}/${psc_endpoint.endpoint_name}" = {
        psc_key       = psc_key
        project       = psc_endpoint.project
        region        = psc_endpoint.location
        endpoint_name = psc_endpoint.endpoint_name
        network_name  = psc_endpoint.network_name
        target        = psc_endpoint.target

        ip_name         = psc_endpoint.ip_address.name
        address         = psc_endpoint.ip_address.address
        subnetwork_name = psc_endpoint.ip_address.subnetwork_name
      }
    } if psc_endpoint.location != "global"
  ]...)

  global_psc = merge([
    for psc_key, psc_endpoint in var.psc_endpoints : {
      "${psc_key}/${psc_endpoint.target}" = {
        psc_key       = psc_key
        project       = psc_endpoint.project
        endpoint_name = psc_endpoint.endpoint_name
        network_name  = psc_endpoint.network_name
        target        = psc_endpoint.target

        ip_name = psc_endpoint.ip_address.name
        purpose = psc_endpoint.ip_address.purpose
        address = psc_endpoint.ip_address.address
      }
    } if psc_endpoint.location == "global"
  ]...)
}

resource "google_compute_address" "psc_regional_address" {
  for_each     = local.regional_psc
  name         = each.value.ip_name
  address_type = "INTERNAL"
  address      = each.value.address
  region       = each.value.region
  subnetwork   = "projects/${each.value.project}/regions/${each.value.region}/subnetworks/${each.value.subnetwork_name}"
}

resource "google_compute_forwarding_rule" "psc_regional_forwarding_rule" {
  for_each              = local.regional_psc
  name                  = each.value.endpoint_name
  region                = each.value.region
  network               = "https://www.googleapis.com/compute/v1/projects/${each.value.project}/global/networks/${each.value.network_name}"
  ip_address            = google_compute_address.psc_regional_address["${each.key}"].id
  target                = each.value.target
  load_balancing_scheme = ""
}

resource "google_compute_global_address" "psc_global_address" {
  for_each     = local.global_psc
  name         = each.value.ip_name
  purpose      = each.value.purpose
  address_type = "INTERNAL"
  address      = each.value.address
  network      = "projects/${each.value.project}/global/networks/${each.value.network_name}"
}

resource "google_compute_global_forwarding_rule" "psc_global_forwarding_rule" {
  for_each              = local.global_psc
  name                  = each.value.endpoint_name
  network               = "projects/${each.value.project}/global/networks/${each.value.network_name}"
  ip_address            = google_compute_global_address.psc_global_address["${each.key}"].id
  target                = each.value.target
  load_balancing_scheme = ""
}

