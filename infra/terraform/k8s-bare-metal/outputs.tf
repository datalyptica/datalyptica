output "namespace" {
  value = kubernetes_namespace.lakehouse.metadata[0].name
}