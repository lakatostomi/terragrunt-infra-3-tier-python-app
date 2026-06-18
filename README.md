# Terragrunt Multi-Environment Infrastructure — 3-Tier Python Application

This repository contains the Terragrunt-based infrastructure code for deploying a three-tier Python web application on Google Cloud Platform. The primary focus of this project is to demonstrate a **multi-environment infrastructure pattern using Terragrunt**, with reusable custom Terraform modules, a hierarchical configuration structure, and a GitLab CI/CD pipeline backed by Workload Identity Federation for keyless authentication.

The application itself (a population data browser with a Streamlit frontend and FastAPI backend) is the vehicle for the infrastructure — the real subject matter is the layered Terragrunt design.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Infrastructure Design](#infrastructure-design)
  - [Project Layout: Shared Services and Environment Stacks](#project-layout-shared-services-and-environment-stacks)
  - [Terragrunt Configuration Hierarchy](#terragrunt-configuration-hierarchy)
  - [Custom Terraform Modules](#custom-terraform-modules)
- [Module Reference](#module-reference)
  - [shared-resources](#shared-resources)
  - [infra-stack](#infra-stack)
  - [app-stack](#app-stack)
- [Networking and Connectivity](#networking-and-connectivity)
- [IAM and Security](#iam-and-security)
- [CI/CD Pipeline](#cicd-pipeline)
- [Prerequisites](#prerequisites)
- [Usage](#usage)

---

## Architecture Overview

The infrastructure follows a hub-and-spoke model across multiple GCP projects:

- A **shared-services project** hosts centralised resources consumed by all environments: a Cloud SQL (PostgreSQL 17) instance exposed via Private Service Connect, a routing VPC with a PSC endpoint for Google APIs (`all-apis`), and private DNS zones for both the database and Cloud Run.
- Each **environment** (`dev`, `test`) runs in its own GCP project with a Shared VPC setup. Per-environment resources are split across two Terragrunt units: `population-project-infra` (network, firewall, IAM, service accounts) and `population-project-app` (Artifact Registry, Cloud Build triggers, Cloud Run services, Secret Manager secrets).
- The **frontend** Cloud Run service is publicly reachable (`INGRESS_TRAFFIC_ALL`) while the **backend** Cloud Run service is internal-only (`INGRESS_TRAFFIC_INTERNAL_ONLY`), connected via Direct VPC Egress on a dedicated `app-subnet`.

---

## Repository Structure

```
.
├── app/
│   ├── backend/          # FastAPI application
│   └── frontend/         # Streamlit application
└── infra/
    ├── live/             # Terragrunt live configuration (all environments)
    │   ├── root.hcl                        # Root Terragrunt config (backend, providers, versions)
    │   ├── .gitlab-ci.yml                  # GitLab CI/CD pipeline
    │   ├── shared-services/
    │   │   └── terragrunt.hcl              # Shared Cloud SQL, PSC, DNS
    │   ├── dev/
    │   │   ├── environment.hcl             # Dev environment inputs
    │   │   ├── population-project-infra/
    │   │   │   └── terragrunt.hcl          # Dev network, firewall, IAM
    │   │   └── population-project-app/
    │   │       └── terragrunt.hcl          # Dev Cloud Run, Artifact Registry, CI/CD, Secrets
    │   └── test/
    │       ├── environment.hcl             # Test environment inputs
    │       ├── population-project-infra/
    │       │   └── terragrunt.hcl
    │       └── population-project-app/
    │           └── terragrunt.hcl
    └── modules/          # Reusable custom Terraform modules
        ├── shared-resources/
        ├── infra-stack/
        └── app-stack/
```

---

## Infrastructure Design

### Project Layout: Shared Services and Environment Stacks

The infrastructure is divided into three logical layers, each backed by one of the custom modules:

| Layer | Terragrunt Unit | GCP Project | Module |
|---|---|---|---|
| Shared services | `shared-services/` | Shared/routing project | `shared-resources` |
| Per-env network & IAM | `<env>/population-project-infra/` | Environment project | `infra-stack` |
| Per-env application | `<env>/population-project-app/` | Environment project | `app-stack` |

The `population-project-app` unit declares an explicit `dependency` block on `shared-services` to consume the Cloud SQL PSC DNS recordset output (`db_recordset`), and a `dependencies` block on `population-project-infra` to enforce creation ordering. This means Terragrunt always applies the three stacks in the correct sequence without manual orchestration.

### Terragrunt Configuration Hierarchy

All configuration is data-driven through a single `config.yaml` file read at the root level. The `root.hcl` file is the only place where GCS remote state, provider generation, and Terraform version constraints are defined — everything else inherits from it via `find_in_parent_folders()`.

**`root.hcl`** generates three files into every Terragrunt unit at `init` time:

- `backend.tf` — GCS backend using the bucket and path prefix `terraform/state/<path-from-repo-root>` derived dynamically via `get_path_from_repo_root()`.
- `provider.tf` — `google` and `google-beta` providers configured with service account impersonation (`impersonate_service_account`), so no long-lived key files are ever needed locally or in CI.
- `versions.tf` — Terraform `>= 1.12.4`, `hashicorp/google = 7.33`, `hashicorp/google-beta = 7.33`.

**`environment.hcl`** lives in each environment directory (`dev/`, `test/`) and exposes the environment-level `project_id`, `self_vpc_name`, and `host_project_id` inputs. Unit-level `terragrunt.hcl` files include both `root.hcl` and `environment.hcl` using separate `include` blocks with `expose = true`, allowing them to read parent locals directly.

**Unit-level `terragrunt.hcl`** files resolve all inputs from `config.yaml` via `lookup()` calls keyed on the directory name (`basename(get_terragrunt_dir())`), keeping each unit's HCL purely structural with no hard-coded values.

Module sources are pinned by Git tag via a `modules` section in `config.yaml` — each unit reads `local.module_source.url` and `local.module_source.ref` to construct its `terraform.source` string (e.g., `${url}?ref=${ref}`). Local source paths are left commented-in for fast local iteration.

### Custom Terraform Modules

All three modules share a consistent design philosophy: resources are declared as `for_each` over typed input maps, making every module fully data-driven. No resource is hard-coded. Input variables use Terraform's `optional()` and `validation` blocks extensively to enforce correctness at `plan` time rather than at apply time.

---

## Module Reference

### `shared-resources`

Manages the centralised resources shared across all environments. Designed to be applied once per shared/routing project.

**Resources:**

- `google_sql_database_instance` — Cloud SQL PostgreSQL 17 instance (`shared-app-db`) with PSC enabled (`psc_enabled = true`), no public IP, `REGIONAL` availability, `db-g1-small` tier, `PD_HDD` storage, and auto-created PSC connections into the routing VPC. `deletion_protection` is toggled via input to allow teardown in non-production scenarios.
- `google_sql_user` / `google_sql_database` — Iterated from nested maps inside `sql_instances`, keyed as `<sql_key>/<user_key>` and `<sql_key>/<db_key>` respectively.
- `google_dns_managed_zone` + `google_dns_record_set` (SQL PSC) — A private DNS zone (`populationapp.internal.`) and an `A` record (`db.populationapp.internal.`) pointing at the PSC auto-connection IP address, resolved dynamically by iterating the nested `psc_auto_connections` block on the SQL instance.
- `google_compute_global_address` + `google_compute_global_forwarding_rule` — Global PSC endpoint for `all-apis` (`10.0.1.1`) in the routing VPC, enabling Private Google Access for Cloud Run services without external IPs.
- `google_compute_subnetwork` — Routing subnet (`10.10.0.0/28`) in the routing VPC.
- `google_dns_managed_zone` + `google_dns_record_set` (Cloud Run DNS) — A private zone for `app.run.` with a wildcard `CNAME` pointing to `app.run.` and an `A` record resolving to the PSC global address (`10.0.1.1`). The zone's `private_visibility_config` includes both the routing VPC and all consumer VPCs passed in via the `consumers` map.

---

### `infra-stack`

Manages per-environment networking, firewall rules, service account provisioning, and subnet IAM. Applied once per environment project.

**Resources:**

- `google_compute_subnetwork` — Environment-specific `app-subnet` created in the Shared VPC host project. `private_ip_google_access` defaults to `true`. Supports optional secondary IP ranges for future GKE use.
- `google_compute_firewall_policy_rule` (ingress/egress) — Rules added to a pre-existing Hierarchical Firewall Policy (name passed via `firewall_policy_name`). The dev/test units configure an ingress rule at priority `100` to allow TCP `5432` from the `app-subnet` CIDR. Both ingress and egress rule resources include a `lifecycle.precondition` that enforces at least one `layer4_config` per rule.
- `google_compute_firewall` — VPC-level firewall rules for service-account-based east-west traffic. The dev unit creates `allow-http-frontend-backend`, permitting TCP `8080` from the frontend service account to the backend service account.
- `google_service_account` + `google_project_iam_member` — Service accounts are created and granted project roles from the `iam_project_roles` list. The dev unit creates a `cloudbuild-app-sa` with `roles/logging.logWriter` and `roles/artifactregistry.writer`.
- `google_compute_subnetwork_iam_member` — Grants `roles/compute.networkUser` on the `app-subnet` to:
  - Each member in `subnet_iam` (frontend and backend runtime service accounts).
  - The Cloud Run service agent (`service-<project-number>@serverless-robot-prod.iam.gserviceaccount.com`) when `enable_cloud_run_direct_egress = true`, required for Direct VPC Egress to function.
- `google_storage_bucket` + `google_storage_bucket_iam_binding` — Optional GCS buckets with uniform access control and configurable IAM bindings per role.

---

### `app-stack`

Manages per-environment application-layer resources: container registries, CI/CD triggers, Cloud Run services, secrets, and runtime IAM. Applied after `infra-stack`.

**Resources:**

- `google_artifact_registry_repository` — Docker repositories for `populationapp-frontend` and `populationapp-backend`. Each includes a `cleanup_policies` block to auto-delete untagged images (`tag_state = "UNTAGGED"`, `action = "DELETE"`). Validation ensures every cleanup policy specifies either `condition` or `most_recent_versions`.
- `google_cloudbuild_trigger` — GitHub push triggers (branch `^main$`) for both the frontend (`population-data-st-frontend-app`) and backend (`population-data-fastapi-backend-app`) repositories. Triggers run the in-repo `cloudbuild.yaml`, scoped to relevant file patterns (`**/*.py`, `**/requirements.txt`, `Dockerfile`). The trigger service account is the `cloudbuild-app-sa` created by `infra-stack`.
- `data.google_artifact_registry_docker_image` + `google_cloud_run_v2_service` — Cloud Run v2 services using `google-beta` provider. Image references are resolved at plan time via the `repository_data` map and the `google_artifact_registry_docker_image` data source. Key service configuration:
  - `backend_service`: `INGRESS_TRAFFIC_INTERNAL_ONLY`, `invoker_iam_disabled = true`, Direct VPC Egress with no explicit `egress` setting (defaults to `PRIVATE_RANGES_ONLY`), scales 1–2 instances, attached to `backend-runtime-sa`.
  - `frontend_service`: `INGRESS_TRAFFIC_ALL`, `invoker_iam_disabled = true`, Direct VPC Egress with `egress = "ALL_TRAFFIC"` to route all outbound traffic through the VPC (required to reach the internal backend), scales 1–2 instances, `CLOUD_API_SERVER` env var set to the backend's internal URL, attached to `frontend-runtime-sa`.
- `google_service_account` + `google_project_iam_member` — Runtime service accounts: `frontend-runtime-sa` (`roles/artifactregistry.reader`) and `backend-runtime-sa` (`roles/storage.objectUser`, `roles/artifactregistry.reader`, `roles/secretmanager.secretAccessor`).
- `google_secret_manager_secret` + `google_secret_manager_secret_version` — All application secrets (database credentials, connection strings) stored in Secret Manager with automatic replication. The `POSTGRES_HOST` secret is assembled in the `population-project-app` terragrunt unit using the `db_recordset` output from the `shared-services` dependency: `trimsuffix(dependency.shared-services.outputs.db_recordset[local.db_dns_key].recordset, "."):5432`.
- `google_dns_managed_zone` + `google_dns_record_set` — Optional per-environment private DNS zones.
- `google_storage_bucket` — Optional GCS buckets with IAM bindings.

---

## Networking and Connectivity

## Out-of-Scope Prerequisites (Provisioned in Other Stages)

This project assumes a number of foundational resources already exist and are managed outside of this repository's lifecycle. These are provisioned in separate, prerequisite stages and only **consumed** (via references, or pre-existing names/IDs) by the Terragrunt units and modules described above:

- **VPC networks** — The Shared VPC host networks (both the per-environment VPCs and the routing VPC) referenced via `vpc_name` / `host_project_id` / `routing_vpc_name`.
- **Hub-and-spoke network topology via NCC** — The Network Connectivity Center hub-and-spoke setup connecting the routing VPC (hub) to the environment VPCs (spokes) is provisioned separately; this project only attaches PSC endpoints and subnets to the existing topology.
- **Hierarchical Firewall Policy** — The firewall policy itself, its attachment to the relevant project folder, and any baseline organization-wide rules are created in a separate stage. This project only adds additional rules (e.g. the PostgreSQL ingress rule) to the existing policy via `firewall_policy_name`.
- **DNS peering** — Cross-project/cross-VPC DNS peering configurations are established beforehand; this project only creates private zones and recordsets that rely on that peering being in place.
- **Workload Identity Federation (WIF) setup** — The WIF pool and provider, along with the associated service account and IAM bindings used by the CI/CD pipeline, are created ahead of time.
- **Terraform/Terragrunt remote state backend bucket** — The GCS bucket referenced in `root.hcl` as `backend_bucket` is created in a prior bootstrap stage, not by this project.

The connectivity model is built around Private Service Connect to avoid exposing any data plane traffic to the public internet:

- **Cloud SQL → Cloud Run (backend):** The Cloud SQL instance exposes a PSC service attachment. An auto-connection is created into the routing VPC at a static IP. A private DNS zone (`populationapp.internal.`) resolves `db.populationapp.internal.` to that PSC IP. Cloud Run backend service uses Direct VPC Egress and routes all traffic through the `app-subnet`, resolving the database host via the private DNS zone.
- **Cloud Run → Google APIs:** A global PSC forwarding rule targets `all-apis` at `10.0.1.1` in the routing VPC. A private DNS zone (`app.run.`) with a wildcard CNAME and an `A` record at `10.0.1.1` is shared across all consumer VPCs, so Cloud Run services resolve Google API endpoints privately.
- **Frontend → Backend:** The frontend Cloud Run service sends requests to the backend's internal Cloud Run URL (formatted as `https://<service>-<project-number>.<region>.run.app`). With `egress = "ALL_TRAFFIC"` on the frontend, these requests traverse the VPC and are resolved via the `app.run.` private DNS zone to the PSC global endpoint, never leaving the Google network.

---

## IAM and Security

- **No long-lived key files.** Provider authentication uses service account impersonation (`impersonate_service_account`) in the provider configuration, generated at runtime by `root.hcl`. The operator's or CI runner's identity assumes the Terraform SA via short-lived credentials.
- **Least-privilege service accounts.** Each workload has a dedicated SA with only the roles required for its function. The Cloud Build SA does not share an identity with the Cloud Run runtime SAs.
- **Invoker IAM disabled.** Both Cloud Run services set `invoker_iam_disabled = true`, preventing unauthenticated invocations while still allowing direct HTTPS access to the public frontend via the Cloud Run URL.
- **Service-account-scoped firewall rules.** The `allow-http-frontend-backend` firewall rule uses `source_service_accounts` and `target_service_accounts` rather than IP ranges or tags, so only traffic originating from the frontend SA identity can reach the backend SA identity on port `8080`.
- **Hierarchical Firewall Policy integration.** PostgreSQL access (TCP `5432`) is controlled at the firewall policy level (priority `100`) rather than via VPC firewall rules, allowing consistent enforcement across the organisation hierarchy.

---

## CI/CD Pipeline

The pipeline is defined in `infra/live/.gitlab-ci.yml` and is triggered on merge request events, web UI triggers, and pipeline triggers.

**Stages:** `gcp_auth` → `validate` → `plan` → `test` → `deploy` → `destroy`

**Workload Identity Federation authentication:** The `gcp_auth` job uses GitLab's native OIDC `id_tokens` feature to obtain a short-lived JWT (`ID_TOKEN_GCP`), then calls `gcloud iam workload-identity-pools create-cred-config` to generate an Application Default Credentials file pointing at the WIF provider and service account. The credential file is passed forward to subsequent jobs as a GitLab artifact. No service account key JSON is stored as a CI variable.

**Runtime variables:**

| Variable | Options | Description |
|---|---|---|
| `WORK_DIR` | `shared-services`, `dev/population-project-infra`, `dev/population-project-app`, `test/population-project-infra`, `test/population-project-app` | Terragrunt directory to target |
| `ACTION` | `apply`, `destroy` | Operation to perform |
| `TG_PROVIDER_CACHE` | `0`, `1` | Enable Terragrunt provider caching |
| `CHECKOV_TEST` | `true`, `false` | Enable checkov sercurity policy test |

**Key pipeline behaviours:**

- `validate` runs `terragrunt run --all --queue-include-dir` scoped to `WORK_DIR`, followed by `terragrunt hcl fmt --check` and `terragrunt hcl validate`.
- `plan` saves the plan output to `${CI_PROJECT_DIR}/${WORK_DIR}/plan.cache` and publishes it as an artifact, ensuring `deploy` applies exactly the reviewed plan.
- `test` is an optional **Checkov** static security analysis stage that runs against the Terraform plan output before any `apply` is triggered.
- `deploy` is `when: manual` and uses `resource_group: "terragrunt-${WORK_DIR}"` to prevent concurrent applies on the same unit.
- `destroy` is restricted to the default branch and also `when: manual`.
- Provider cache is stored in `.terragrunt-provider-cache/` and keyed on `.terraform.lock.hcl` using GitLab's `cache` directive with `pull-push` policy.

### Checkov Policy configuration (`checkov_test.yaml`)

The Checkov config targets the `terraform_plan` framework with `soft-fail: false` (hard block on any finding). Output is produced in both `cli` and `json` formats. The enabled checks cover the following domains:

**IAM**
- `CKV_GCP_46` — Default service account not used at project level
- `CKV_GCP_41` — IAM users not assigned Service Account User / Token Creator roles at project level
- `CKV_GCP_49` — Roles do not impersonate or manage service accounts at project level
- `CKV_GCP_117` — Basic roles (`owner`, `editor`, `viewer`) not used at project level

**Cloud Storage**
- `CKV_GCP_29` — Uniform bucket-level access enabled
- `CKV_GCP_78` — Versioning enabled
- `CKV_GCP_114` — Buckets not publicly accessible

**Cloud SQL**
- `CKV_GCP_14` — Backup configuration enabled
- `CKV_GCP_11` — No public IP assigned
- `CKV_GCP_79` — Latest major version in use

**Networking / Artifact Registry**
- `CKV_GCP_101` — Artifact Registry repositories not publicly or anonymously accessible
- `CKV2_GCP_12` — Compute firewall ingress does not allow unrestricted access to all ports
- `CKV_GCP_106` — Compute firewall ingress does not allow unrestricted HTTP (port 80) access

**Logging**
- `CKV_GCP_26` — VPC Flow Logs enabled on every subnet

---

## Prerequisites

- Terraform `>= 1.12.4`
- Terragrunt `>= 1.0.4`
- `google` and `google-beta` providers pinned to `7.33`
- A GCP identity with `roles/iam.serviceAccountTokenCreator` on the Terraform impersonation SA
- A populated `config.yaml` at `infra/live/` (not committed; structure can be found below)
- For CI: A Workload Identity Pool and Provider configured in GCP to trust the GitLab project's OIDC tokens

---

## Structure of the config file

**config.yaml**

```yaml
backend_bucket: 
impersonate_sa: 
region: 
modules:
  shared-services:
    url: https://gitlab.com/terraform_projects2/3-tier-app-tf-modules.git//shared-resources
    ref: v1.0.1
  population-project-infra:
    url: https://gitlab.com/terraform_projects2/3-tier-app-tf-modules.git//infra-stack
    ref: v1.0.1
  population-project-app:
    url: https://gitlab.com/terraform_projects2/3-tier-app-tf-modules.git//app-stack
    ref: v1.0.1 
common_inputs:
  fw_policy_name: 
  app_subnet: 
  frontend_sa: 
  backend_sa: 
  app_cicd_service_account: 
  db_dns_key:
  secrets:
      PROJECT_ID: 
      TABLE_ID: 
      POSTGRES_USER: 
      POSTGRES_PASSWORD:
shared-services:
  inputs:
    project_id: 
    routing_project_id: 
    self_vpc_name: 
    routing_vpc_name: 
    consumers:
      consumer_id_1: 
      consumer_id_2:      
dev:
  inputs:
    project_id: 
    host_project_id:
    self_vpc_name: 
  population-project-infra:
    project_id: 
    app_subnet_range: 
  population-project-app:  
    project_id: 
    project_number:  
test:
  inputs:
    project_id: 
    host_project_id: 
    self_vpc_name: 
  population-project-infra:
    project_id: 
    app_subnet_range: 
  population-project-app:  
    project_id: 
    project_number:   
```
