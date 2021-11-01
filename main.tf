terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.90"
    }
  }
}

locals {
  sa_emails = {
    # The Google Default Compute service account is subject to the same scoping
    # rules as a user-defined service account, but if you want to include it
    # in the demo uncomment the next line.
    # default-compute = null
    enabled  = google_service_account.enabled.email
    disabled = google_service_account.disabled.email
  }

}

# A service account that will be created and enabled
resource "google_service_account" "enabled" {
  project      = var.project_id
  account_id   = format("%s-enabled", var.prefix)
  display_name = "Enabled account for service accounts/scope demo"
  disabled     = false
}

# A service account that will be created but disabled.
# NOTE: GCP API does not permit creating a disabled service account; do a two-step
# apply to get this setup correctly. See 'Using this demo' section of README.
resource "google_service_account" "disabled" {
  project      = var.project_id
  account_id   = format("%s-disabled", var.prefix)
  display_name = "Disabled account for service accounts/scope demo"
  disabled     = true
}

# Create a network for the VMs
resource "google_compute_network" "network" {
  project                 = var.project_id
  name                    = var.prefix
  auto_create_subnetworks = false
  mtu                     = 1460
}

# Create a subnet for the VMs
resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = var.prefix
  ip_cidr_range = "172.16.0.0/16"
  region        = var.region
  network       = google_compute_network.network.id
}

# Create a VM for each combination of service account and scopes
resource "google_compute_instance" "vms" {
  for_each = { for pair in setproduct(keys(local.sa_emails), keys(var.scopes)) : format("%s-%s-%s", var.prefix, pair[0], pair[1]) => {
    sa_email = local.sa_emails[pair[0]]
    scopes   = var.scopes[pair[1]]
  } }
  project      = var.project_id
  name         = each.key
  machine_type = "e2-medium"
  zone         = format("%s-a", var.region)
  service_account {
    email  = each.value.sa_email
    scopes = each.value.scopes
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {}
  }
  tags = [
    var.prefix,
  ]
  labels = var.labels

  metadata = {
    enable-oslogin     = "TRUE"
    serial-port-enable = "TRUE"
    startup-script     = <<-EOD
#!/bin/sh
apt-get update -qq
apt-get install -qqy jq curl
echo "##### BEGIN SA DETAILS #####" > /dev/ttyS0
code="$(curl -s -w '{"http_status": "%%{http_code}"}' -o /run/sa_email -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/email | jq -r '.http_status')"
case "$${code}" in
    200)
        echo "Effective service account is $(cat /run/sa_email)" > /dev/ttyS0
        code="$(curl -s -w '{"http_status": "%%{http_code}"}' -o /run/sa_token -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token | jq -r '.http_status')"
        echo "Token endpoint Response code: $${code}" > /dev/ttyS0
        case "$${code}" in
            200)
                echo "Access token is: $(jq -r .access_token < /run/sa_token)" > /dev/ttyS0
                ;;
            404)
                echo "An access token is not available on this VM" > /dev/ttyS0
                ;;
            *)
                echo "Unexpected code for token endpoint: $${code}" > /dev/ttyS0
                ;;
        esac
        ;;
    404)
        echo "This VM is running without access to a service account" > /dev/ttyS0
        ;;
    *)
        echo "Unexpected HTTP code for email endpoint: $${code}"  > /dev/ttyS0
        ;;
esac
echo "##### END SA DETAILS #####" > /dev/ttyS0
[ -e /run/sa_email ] && rm -f /run/sa_email
[ -e /run/sa_token ] && rm -f /run/sa_token
EOD
  }
}

# Create a firewall rule to allow access via SSH
resource "google_compute_firewall" "ssh" {
  project       = var.project_id
  name          = "allow-ssh-sa-scope-demo"
  network       = google_compute_network.network.self_link
  source_ranges = var.allowed_cidrs
  target_tags = [
    var.prefix,
  ]
  allow {
    protocol = "TCP"
    ports = [
      22,
    ]
  }
}
