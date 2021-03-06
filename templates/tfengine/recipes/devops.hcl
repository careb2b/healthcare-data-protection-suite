# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

schema = {
  title                = "Devops Recipe"
  additionalProperties = false
  properties = {
    parent_type = {
      description = <<EOF
        Type of parent GCP resource to apply the policy.
        Must be one of 'organization' or 'folder'.
      EOF
      type        = "string"
      pattern     = "^organization|folder$"
    }
    parent_id = {
      description = <<EOF
        ID of parent GCP resource to apply the policy.
        Can be one of the organization ID or folder ID according to parent_type.
      EOF
      type        = "string"
      pattern     = "^[0-9]{8,25}$"
    }
    billing_account = {
      description = "ID of billing account to attach to this project."
      type        = "string"
    }
    project = {
      description          = "Config for the project to host devops resources such as remote state and CICD."
      type                 = "object"
      additionalProperties = false
      properties = {
        project_id = {
          description = "ID of project."
          type        = "string"
        }
        owners = {
          description = <<EOF
            List of members to transfer ownership of the project to.
            NOTE: By default the creating user will be the owner of the project.
            Thus, there should be a group in this list and you must be part of that group,
            so a group owns the project going forward.
          EOF
          type = "array"
          items = {
            type = "string"
          }
        }
      }
    }
    state_bucket = {
      description = "Name of Terraform remote state bucket."
      type        = "string"
    }
    storage_location = {
      description = "Location of state bucket."
      type        = "string"
    }
    admins_group = {
      description = "Group who will be given org admin access."
      type        = "string"
    }
    enable_bootstrap_gcs_backend = {
      description = <<EOF
        Whether to enable GCS backend for the bootstrap deployment. Defaults to false.
        Since the bootstrap deployment creates the state bucket, it cannot back the state
        to the GCS bucket on the first deployment. Thus, this field should be set to true
        after the bootstrap deployment has been applied. Then the user can run
        `terraform init` in the bootstrapd deployment to transfer the state
        from local to GCS.
      EOF
      type       = "boolean"
    }
    enable_terragrunt = {
      description = <<EOF
        Whether to convert to a Terragrunt deployment. If set to "false", generate Terraform-only
        configs and the CICD pipelines will only use Terraform. Default to "true".
    EOF
      type        = "boolean"
    }
    cicd = {
      description          = "Config for CICD. If unset there will be no CICD."
      type                 = "object"
      additionalProperties = false
      required = [
        "branch_regex",
      ]
      properties = {
        github = {
          description          = "Config for GitHub Cloud Build triggers."
          type                 = "object"
          additionalProperties = false
          properties = {
            owner = {
              description = "GitHub repo owner."
              type        = "string"
            }
            name = {
              description = "GitHub repo name."
              type        = "string"
            }
          }
        }
        cloud_source_repository = {
          description          = "Config for Google Cloud Source Repository Cloud Build triggers."
          type                 = "object"
          additionalProperties = false
          properties = {
            name = {
              description = <<EOF
                Cloud Source Repository repo name.
                The Cloud Source Repository should be hosted under the devops project.
              EOF
              type        = "string"
            }
          }
        }
        branch_regex = {
          description = "Regex of the branches to set the Cloud Build Triggers to monitor."
          type        = "string"
        }
        terraform_root = {
          description = "Path of the directory relative to the repo root containing the Terraform configs."
          type        = "string"
        }
        build_viewers = {
          description = <<EOF
            IAM members to grant `cloudbuild.builds.viewer` role in the devops project
            to see CICD results.
          EOF
          type        = "array"
          items = {
            type = "string"
          }
        }
        managed_services = {
          description = <<EOF
            APIs to enable in the devops project so the Cloud Build service account
            can manage those services in other projects.
          EOF
          type        = "array"
          items = {
            type = "string"
          }
        }
        validate_trigger = {
          description = <<EOF
            Config block for the presubmit validation Cloud Build trigger. If specified, create
            the trigger and grant the Cloud Build Service Account necessary permissions to perform
            the build.
          EOF
          type                 = "object"
          additionalProperties = false
          properties = {
            disable = {
              description = <<EOF
                Whether or not to disable automatic triggering from a PR/push to branch. Default
                to false.
              EOF
              type        = "boolean"
            }
          }
        }
        plan_trigger = {
          description = <<EOF
            Config block for the presubmit plan Cloud Build trigger.
            If specified, create the trigger and grant the Cloud Build Service Account
            necessary permissions to perform the build.
          EOF
          type                 = "object"
          additionalProperties = false
          properties = {
            disable = {
              description = <<EOF
                Whether or not to disable automatic triggering from a PR/push to branch.
                Defaults to false.
              EOF
              type        = "boolean"
            }
          }
        }
        apply_trigger = {
          description = <<EOF
            Config block for the postsubmit apply/deployyemt Cloud Build trigger.
            If specified,create the trigger and grant the Cloud Build Service Account
            necessary permissions to perform the build.
          EOF
          type                 = "object"
          additionalProperties = false
          properties = {
            disable = {
              description = <<EOF
                Whether or not to disable automatic triggering from a PR/push to branch. Default
                to false.
              EOF
              type        = "boolean"
            }
          }
        }
      }
    }
  }
}

template "bootstrap" {
  component_path = "../components/bootstrap"
  output_path    = "./bootstrap"
}

{{if get . "enable_terragrunt" true}}
template "root" {
  component_path = "../components/terragrunt/root"
  output_path    = "./live"
}
{{else}}
template "root" {
  component_path = "../components/terraform/root"
  output_path    = "./live"
}
{{end}}

# At least one trigger is specified.
{{if and (has . "cicd") (or (has .cicd "validate_trigger") (has .cicd "plan_trigger") (has .cicd "apply_trigger"))}}
template "cicd_manual" {
  component_path = "../components/cicd/manual"
  output_path    = "./cicd"
  flatten {
    key = "cicd"
  }
}

{{if get . "enable_terragrunt" true}}
template "root" {
  component_path = "../components/cicd/terragrunt"
  output_path    = "./cicd"
}
{{end}}

template "cicd_auto" {
  component_path = "../components/cicd/auto"
  output_path    = "./live/cicd"
  flatten {
    key = "cicd"
  }
}
{{end}}
