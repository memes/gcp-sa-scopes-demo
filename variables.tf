variable "project_id" {
  type        = string
  description = <<-EOD
The GCP project where the resources will be deployed.
EOD
}

variable "region" {
  type        = string
  description = <<-EOD
The compute region where resources will be deployed.
EOD
}

variable "prefix" {
  type        = string
  default     = "sa-scope-demo"
  description = <<-EOD
The prefix to apply to all generated resources; default is 'sa-scope-demo'.
EOD
}

variable "scopes" {
  type = map(list(string))
  default = {
    no-scopes = []
    cloud-platform = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    legacy-gdm = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
    ]
  }
  description = <<-EOD
A map of OAuth scope combinations, keyed by scenario name. The default values
will create VMs for each service account with no scopes, cloud-platform, and a
common legacy GDM set of scopes.

Override this to try out other combinations.
EOD
}

variable "allowed_cidrs" {
  type = list(string)
  default = [
    "0.0.0.0/0",
  ]
  description = <<-EOD
The list of source CIDRs that will be permitted to SSH to the VMs. Default is
['0.0.0.0/0'].
EOD
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = <<-EOD
An optional set of labels to apply to generated resources. The default set is
empty.
EOD
}
