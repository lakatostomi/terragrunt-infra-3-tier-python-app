locals {
  sql_users = merge([
    for sql_key, sql in var.sql_instances : {
      for user_key, user in coalesce(sql.users, {}) :
      "${sql_key}/${user_key}" => {
        sql_key  = sql_key
        name     = user.user_name
        password = user.user_password
        host     = user.user_host
      }
    }
  ]...)

  dns_sql = merge([
    for sql_key, sql in var.sql_instances : {
      "${sql_key}/${sql.dns_zone.name}" = {
        sql_key = sql_key

        name           = sql.dns_zone.name
        dns_name       = sql.dns_zone.dns_name
        recordset_name = sql.dns_zone.recordset_name
        ttl            = sql.dns_zone.ttl

        consumer_network            = sql.psc_config.auto_connections.consumer_network
        consumer_service_project_id = sql.psc_config.auto_connections.consumer_service_project_id
      }
    } if sql.dns_zone != null
  ]...)

  databases = merge([
    for sql_key, sql in var.sql_instances : {
      for db_key, db in sql.databases :
      "${sql_key}/${db_key}" => {
        sql_key  = sql_key
        database = db
      }
    } if sql.databases != null
  ]...)
}

resource "google_sql_database_instance" "default_sql" {
  for_each            = var.sql_instances
  name                = each.value.name
  database_version    = each.value.database_version
  project             = each.value.project
  region              = each.value.region
  root_password       = each.value.root_password
  deletion_protection = each.value.deletion_protection

  settings {
    tier                  = each.value.tier
    disk_size             = each.value.disk_size
    disk_type             = each.value.disk_type
    edition               = each.value.edition
    availability_type     = each.value.availability_type
    user_labels           = each.value.user_labels
    connector_enforcement = each.value.connector_enforcement

    ip_configuration {
      ipv4_enabled       = each.value.ip_configuration.ipv4_enabled
      private_network    = (each.value.ip_configuration.private_network != null ? "projects/${each.value.project}/global/networks/${each.value.ip_configuration.private_network}" : null)
      allocated_ip_range = each.value.ip_configuration.allocated_ip_range

      dynamic "psc_config" {
        for_each = each.value.psc_config != null ? [each.value.psc_config] : []
        content {
          psc_enabled               = true
          allowed_consumer_projects = psc_config.value.allowed_consumer_projects

          dynamic "psc_auto_connections" {
            for_each = psc_config.value.auto_connections != null ? [psc_config.value.auto_connections] : []
            content {
              consumer_network            = "projects/${psc_auto_connections.value.consumer_service_project_id}/global/networks/${psc_auto_connections.value.consumer_network}"
              consumer_service_project_id = psc_auto_connections.value.consumer_service_project_id
            }
          }
        }
      }
    }
  }
}

resource "google_sql_user" "users" {
  for_each = local.sql_users

  name     = each.value.name
  instance = google_sql_database_instance.default_sql["${each.value.sql_key}"].name
  host     = each.value.host
  password = each.value.password
}

resource "google_sql_database" "database" {
  for_each = local.databases
  name     = each.value.database
  instance = google_sql_database_instance.default_sql["${each.value.sql_key}"].name
}

resource "google_dns_managed_zone" "sql_psc_managed_zone" {
  for_each = local.dns_sql
  name     = each.value.name
  dns_name = each.value.dns_name

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = "projects/${each.value.consumer_service_project_id}/global/networks/${each.value.consumer_network}"
    }
  }
}

resource "google_dns_record_set" "sql_psc_recordset" {
  for_each = local.dns_sql

  name         = "${each.value.recordset_name}${each.value.dns_name}"
  managed_zone = google_dns_managed_zone.sql_psc_managed_zone["${each.key}"].name
  type         = "A"
  ttl          = each.value.ttl

  rrdatas = [one(flatten([
    for settings in google_sql_database_instance.default_sql[each.value.sql_key].settings :
    [
      for ip in settings.ip_configuration :
      [
        for psc in ip.psc_config :
        [
          for conn in psc.psc_auto_connections :
          conn.ip_address
        ]
      ]
    ]
  ]))]
}