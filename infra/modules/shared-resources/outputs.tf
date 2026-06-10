output "sql_instance_names" {
  description = "Created Cloud SQL instance names."

  value = {
    for k, instance in google_sql_database_instance.default_sql :
    k => instance.name
  }
}

output "sql_connection_names" {
  description = "Cloud SQL connection names."

  value = {
    for k, instance in google_sql_database_instance.default_sql :
    k => instance.connection_name
  }
}

output "sql_private_ips" {
  description = "Private IP addresses of Cloud SQL instances."

  value = {
    for k, instance in google_sql_database_instance.default_sql :
    k => instance.private_ip_address
  }
}

output "sql_psc_service_attachments" {
  description = "PSC service attachments exposed by Cloud SQL."

  value = {
    for k, instance in google_sql_database_instance.default_sql :
    k => try(
      instance.psc_service_attachment_link,
      null
    )
  }
}

output "regional_psc_addresses" {
  description = "Regional PSC endpoint addresses."

  value = {
    for k, address in google_compute_address.psc_regional_address :
    k => address.address
  }
}

output "global_psc_addresses" {
  description = "Global PSC endpoint addresses."

  value = {
    for k, address in google_compute_global_address.psc_global_address :
    k => address.address
  }
}

output "psc_forwarding_rules" {
  description = "PSC forwarding rules."

  value = merge(
    {
      for k, fr in google_compute_forwarding_rule.psc_regional_forwarding_rule :
      k => fr.self_link
    },
    {
      for k, fr in google_compute_global_forwarding_rule.psc_global_forwarding_rule :
      k => fr.self_link
    }
  )
}

output "dns_zones" {
  description = "Created private DNS zones."

  value = {
    for k, zone in google_dns_managed_zone.sql_psc_managed_zone :
    k => {
      id       = zone.id
      name     = zone.name
      dns_name = zone.dns_name
    }
  }
}
