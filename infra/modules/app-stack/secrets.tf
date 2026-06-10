resource "google_secret_manager_secret" "secret_basic" {
  for_each  = var.secrets
  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }
  deletion_protection = false
}

resource "google_secret_manager_secret_version" "secret_version" {
  for_each = var.secrets
  project  = var.project_id
  secret   = google_secret_manager_secret.secret_basic["${each.key}"].id

  secret_data = each.value
}