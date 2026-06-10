resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnetworks

  project       = each.value.project
  name          = each.value.subnet_name
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  purpose       = each.value.purpose
  network       = "projects/${each.value.project}/global/networks/${each.value.vpc_name}"

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}