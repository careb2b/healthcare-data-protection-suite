# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This folder contains Terraform resources to setup the devops project, which includes:
# - The project itself,
# - APIs to enable,
# - Deletion lien,
# - Project level IAM permissions for the project owners,
# - A Cloud Storage bucket to store Terraform states for all deployments,
# - Org level IAM permissions for org admins.

// TODO: replace with https://github.com/terraform-google-modules/terraform-google-bootstrap
terraform {
  required_version = "~> 0.12.0"
  required_providers {
    google      = "~> 3.0"
    google-beta = "~> 3.0"
  }
{{- if get . "enable_bootstrap_gcs_backend"}}
  backend "gcs" {
    bucket = "{{.state_bucket}}"
    prefix = "bootstrap"
  }
{{- end}}
}

# Create the project, enable APIs, and create the deletion lien, if specified.
module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 8.1.0"

  name                    = "{{.project.project_id}}"
  {{- if eq .parent_type "organization"}}
  org_id                  = "{{.parent_id}}"
  {{- else}}
  org_id                  = ""
  folder_id               = "{{.parent_id}}"
  {{- end}}
  billing_account         = "{{.billing_account}}"
  lien                    = {{get . "enable_lien" true}}
  default_service_account = "keep"
  skip_gcloud_download    = true
  activate_apis = [
    "cloudbuild.googleapis.com",
  ]
}

# Terraform state bucket, hosted in the devops project.
module "state_bucket" {
source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 1.4"

  name       = "{{.state_bucket}}"
  project_id = module.project.project_id
  location   = "{{.storage_location}}"
}

# Project level IAM permissions for devops project owners.
resource "google_project_iam_binding" "devops_owners" {
  project = module.project.project_id
  role    = "roles/owner"
  members = {{hcl .project.owners}}
}

# Org level IAM permissions for org admins.
resource "google_{{.parent_type}}_iam_member" "admin" {
  {{- if eq .parent_type "organization"}}
  org_id = "{{.parent_id}}"
  {{- else}}
  folder = "folders/{{.parent_id}}"
  {{- end}}
  role   = "roles/resourcemanager.{{.parent_type}}Admin"
  member = "group:{{.admins_group}}"
}
