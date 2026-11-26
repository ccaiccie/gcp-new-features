terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}

provider "google" {
  alias   = "producer"
  project = var.producer_project_id
  region  = var.region
}

provider "google" {
  alias   = "consumer"
  project = var.consumer_project_id
  region  = var.region
}
