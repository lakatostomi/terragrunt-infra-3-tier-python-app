locals {
  bucket_iam = merge([
    for bucket_key, bucket in var.storage_buckets : {
      for role, members in coalesce(bucket.iam, {}) :
      "${bucket_key}-${role}" => {
        bucket  = bucket_key
        role    = role
        members = members
      }
    }
  ]...)
}

resource "google_storage_bucket" "bucket" {
  for_each = var.storage_buckets

  project                     = var.project_id
  name                        = each.value.name
  location                    = each.value.location
  force_destroy               = each.value.force_destroy
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  versioning {
    enabled = each.value.versioning
  }
}

resource "google_storage_bucket_iam_binding" "binding" {
  for_each = local.bucket_iam

  bucket  = google_storage_bucket.bucket[each.value.bucket].name
  role    = each.value.role
  members = each.value.members
}

resource "google_artifact_registry_repository" "app_repo" {
  for_each               = var.artifact_registries
  project                = var.project_id
  location               = each.value.location
  repository_id          = each.value.name
  description            = each.value.description
  format                 = each.value.format
  cleanup_policy_dry_run = each.value.cleanup_policy_dry_run

  dynamic "cleanup_policies" {
    for_each = each.value.cleanup_policies
    content {
      id     = cleanup_policies.value.id
      action = cleanup_policies.value.action
      dynamic "condition" {
        for_each = (cleanup_policies.value.condition != null ? [cleanup_policies.value.condition] : [])
        content {
          tag_state             = condition.value.tag_state
          tag_prefixes          = try(condition.value.tag_prefixes, [])
          version_name_prefixes = try(condition.value.version_name_prefixes, [])
          package_name_prefixes = try(condition.value.package_name_prefixes, [])
          older_than            = try(condition.value.older_than, null)
          newer_than            = try(condition.value.newer_than, null)
        }
      }
      dynamic "most_recent_versions" {
        for_each = (cleanup_policies.value.most_recent_versions != null ? [cleanup_policies.value.most_recent_versions] : [])
        content {
          package_name_prefixes = try(most_recent_versions.value.package_name_prefixes, [])
          keep_count            = try(most_recent_versions.value.keep_count, null)
        }
      }
    }
  }
}