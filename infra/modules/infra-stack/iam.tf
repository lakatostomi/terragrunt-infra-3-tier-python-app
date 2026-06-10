locals {
  project_roles = merge([
    for sa_key, sa in var.service_accounts : {
      for role in coalesce(sa.iam_project_roles, []) :
      "${sa_key}-${role}" => {
        sa    = sa_key
        roles = role
      }
    }
  ]...)

  iam_roles = merge([
    for sa_key, sa in var.service_accounts : {
      for principal, roles in coalesce(sa.iam, {}) :
      "${sa_key}-${principal}" => {
        sa        = sa_key
        principal = principal
        roles     = roles
      }
    }
  ]...)

  sa_iam_role = merge([
    for key, item in local.iam_roles : {
      for role in item.roles :
      "${item.principal}-${role}" => {
        sa        = item.sa
        principal = item.principal
        role      = role
      }
    }
  ]...)

  subnet_iam = merge([
    for subnet, principals in var.subnet_iam : {
      for member in principals :
      "${subnet}/${member}" => {
        region     = split("/", subnet)[0]
        subnet_key = split("/", subnet)[1]
        member     = member
      }
    }
  ]...)
}

resource "google_service_account" "service_account" {
  for_each     = var.service_accounts
  project      = var.project_id
  account_id   = each.value.name
  display_name = each.key
}

resource "google_project_iam_member" "service_account_iam_role" {
  for_each = local.project_roles
  project  = var.project_id
  role     = each.value.roles
  member   = "serviceAccount:${google_service_account.service_account[each.value.sa].email}"
}

resource "google_service_account_iam_member" "service_account_iam_member" {
  for_each           = local.sa_iam_role
  service_account_id = google_service_account.service_account[each.value.sa].name
  role               = each.value.role
  member             = each.value.principal
}



resource "google_compute_subnetwork_iam_member" "subnet_member" {
  for_each   = local.subnet_iam
  project    = var.host_project_id
  region     = each.value.region
  subnetwork = google_compute_subnetwork.subnets["${each.value.subnet_key}"].name
  role       = "roles/compute.networkUser"
  member     = each.value.member
}

data "google_project" "service_project" {
  project_id = var.project_id
}

resource "google_compute_subnetwork_iam_member" "cloudrun_service_agent" {
  for_each = var.enable_cloud_run_direct_egress ? var.subnetworks : {}

  project    = var.host_project_id
  region     = each.value.region
  subnetwork = google_compute_subnetwork.subnets[each.key].id

  role = "roles/compute.networkUser"

  member = "serviceAccount:service-${data.google_project.service_project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}