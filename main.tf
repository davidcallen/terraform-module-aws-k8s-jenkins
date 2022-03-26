data "aws_eks_cluster" "k8s" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "k8s" {
  name = var.cluster_name
}

resource "kubernetes_secret" "k8s-jenkins-admin" {
  metadata {
    name      = "${var.org_short_name}-jenkins-admin"
    namespace = kubernetes_namespace.k8s-cluster-jenkins.id
  }
  type = "string"
  data = {
    admin_password = var.jenkins_admin_password
  }
}

resource "helm_release" "k8s-jenkins" {
  name       = "jenkins"
  namespace  = kubernetes_namespace.k8s-cluster-jenkins.id
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  set {
    name  = "annotations.alb.ingress.kubernetes.io/target-type" # Necessary to trigger AWS Load Balancer Controller to expose the Service
    value = "ip"
  }
  set {
    name  = "controller.adminPassword"
    value = kubernetes_secret.k8s-jenkins-admin.data.admin_password
  }
  set {
    name  = "namespaceOverride"
    value = var.namespace
  }
  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.k8s-jenkins-efs-static[0].metadata[0].name
  }
  set {
    name  = "persistence.storageClass"
    value = var.storage_class_name
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
  set {
    name  = "controller.customJenkinsLabels"
    value = "jenkins"
  }
  set {
    name  = "controller.serviceType"
    value = "NodePort" # NodePort needed by AWS Load Balancer if want ALB.  Use value="LoadBalancer" if want AWS Classic LB
  }
  set {
    name  = "controller.installPlugins[0]"
    value = "subversion:2.14.4"
  }
  set {
    name  = "agent.podName"
    value = "${var.org_short_name}-jenkins-agent"
  }
  set {
    name  = "agent.namespace"
    value = var.org_short_name
  }
}

output "pvc_id" {
  value = kubernetes_persistent_volume_claim.k8s-jenkins-efs-static[0].metadata[0].name
}