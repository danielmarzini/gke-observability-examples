# Copyright 2023 Google LLC
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

locals {
  billing_account_id = ""
  folder_id          = ""
  region-1           = "europe-west3"
  region-2           = "europe-west2"
  project_id         = ""
}

module "project" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v23.0.0"
  billing_account = local.billing_account_id
  name            = local.project_id
  parent          = local.folder_id
  services = [
    "compute.googleapis.com",
    "stackdriver.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
}

module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v23.0.0"
  project_id = module.project.project_id
  name       = "default"
  subnets_proxy_only = [
    {
      ip_cidr_range = "10.0.1.0/24"
      name          = "regional-proxy"
      region        = "europe-west8"
      active        = true
    }
  ]
  subnets = [
    {
      ip_cidr_range = "10.0.0.0/24"
      name          = "subnet-1"
      region        = local.region-1
      secondary_ip_ranges = {
        pods     = "172.16.0.0/20"
        services = "192.168.0.0/24"
      }
    }
  ]
}

module "nat" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v23.0.0"
  project_id     = module.project.project_id
  region         = local.region-1
  name           = "default"
  router_network = module.vpc.network.self_link
}


module "cluster_nodepool_sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v23.0.0"
  project_id = module.project.project_id
  name       = "cluster-nodepool-sa"
  # non-authoritative roles granted *to* the service accounts on other resources
  iam_project_roles = {
    "${module.project.project_id}" = [
      "roles/monitoring.metricWriter",
      "roles/logging.logWriter",
      "roles/artifactregistry.reader",
    ]
  }
}

module "cluster-1" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster-standard"
  project_id          = module.project.project_id
  name                = "cluster-1"
  location            = local.region-1
  release_channel     = "RAPID"
  deletion_protection = false
  vpc_config = {
    network    = module.vpc.self_link
    subnetwork = module.vpc.subnets["${local.region-1}/subnet-1"].self_link
    secondary_range_names = {
      pods     = "pods"
      services = "services"
    }
    master_ipv4_cidr_block = "172.19.27.0/28"
  }
  private_cluster_config = {
    enable_private_endpoint = false
    master_global_access    = true
  }
  enable_features = {
    dataplane_v2             = true
    workload_identity        = true
    vertical_pod_autoscaling = true
  }
  labels = {
    environment = "test"
  }
  backup_configs = {
    enable_backup_agent = false
  }
  monitoring_config = {
    enable_managed_prometheus         = true
    enable_api_server_metrics         = true
    enable_controller_manager_metrics = true
    enable_scheduler_metrics          = true
  }

  logging_config = {
    enable_workloads_logs = true
  }
}

module "cluster-1-nodepool-1" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool"
  project_id   = module.project.project_id
  cluster_name = module.cluster-1.name
  location     = local.region-1
  name         = "nodepool-1"
  labels       = { environment = "dev" }
  service_account = {
    create = false
    email  = module.cluster_nodepool_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  node_config = {
    machine_type        = "n2-standard-4"
    disk_size_gb        = 50
    disk_type           = "pd-ssd"
    ephemeral_ssd_count = 1
    gvnic               = true
    spot                = true
  }
  nodepool_config = {
    autoscaling = {
      max_node_count = 10
      min_node_count = 1
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }
}


