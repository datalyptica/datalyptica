terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.26" }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

resource "kubernetes_namespace" "lakehouse" {
  metadata { name = "lakehouse" }
}