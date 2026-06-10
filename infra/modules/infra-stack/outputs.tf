output "service_accounts" {
  value = {
    for k, v in google_service_account.service_account :
    k => v.email
  }
}

output "storage_buckets" {
  value = {
    for k, v in google_storage_bucket.bucket :
    k => {
      name = v.name
      url  = v.url
    }
  }
}