resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnetworks

  project                  = var.host_project_id
  name                     = each.value.subnet_name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  purpose                  = each.value.purpose
  private_ip_google_access = each.value.private_ip_google_access
  network                  = "projects/${var.host_project_id}/global/networks/${var.vpc_name}"

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}