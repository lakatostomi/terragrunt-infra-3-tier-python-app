resource "google_cloudbuild_trigger" "cloud_build_trigger" {
  for_each    = var.cloud_build_triggers
  name        = each.value.name
  project     = each.value.project
  location    = each.value.location
  description = each.value.description
  disabled    = each.value.disabled

  dynamic "github" {
    for_each = [each.value.github]
    content {
      owner                           = github.value.owner
      name                            = github.value.name
      enterprise_config_resource_name = try(github.value.enterprise_config_resource_name, null)
      dynamic "push" {
        for_each = (github.value.push != null ? [github.value.push] : [])
        content {
          branch       = try(push.value.branch, null)
          invert_regex = push.value.invert_regex
          tag          = try(push.value.tag, null)
        }
      }
      dynamic "pull_request" {
        for_each = (github.value.pull_request != null ? [github.value.pull_request] : [])
        content {
          branch          = pull_request.value.branch
          invert_regex    = pull_request.value.invert_regex
          comment_control = pull_request.value.comment_control
        }
      }
    }
  }

  service_account = (
    each.value.service_account_email != null
    ? "projects/${each.value.project}/serviceAccounts/${each.value.service_account_email}"
    : null
  )
  filename = try(each.value.filename, null)

  ignored_files  = each.value.ignored_files
  included_files = each.value.included_files
}
