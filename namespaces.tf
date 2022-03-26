resource "kubernetes_namespace" "k8s-cluster-jenkins" {
  metadata {
//    labels = {
//      app = "my-app"
//    }
    name = var.org_short_name
  }
}