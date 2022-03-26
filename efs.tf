# ---------------------------------------------------------------------------------------------------------------------
# Kubernetes Jenkins EFS filesystem
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_efs_file_system" "k8s-jenkins-controller-efs" {
  count     = var.dynamic_efs_provisioning_enabled ? 0 : 1
  encrypted = true
  lifecycle {
    prevent_destroy = false # cant use var.environment.resource_deletion_protection
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name        = "${var.name}-controller-efs-data"
    Application = "jenkins"
  })
}
resource "aws_efs_mount_target" "k8s-jenkins-controller-efs" {
  count           = var.dynamic_efs_provisioning_enabled ? 0 : length(var.vpc_private_subnet_ids)
  file_system_id  = aws_efs_file_system.k8s-jenkins-controller-efs[0].id
  subnet_id       = var.vpc_private_subnet_ids[count.index]
  security_groups = [var.cluster_security_group_efs_id] # [aws_security_group.k8s-cluster-efs.id]
}
resource "aws_efs_access_point" "k8s-jenkins-controller-efs" {
  count          = var.dynamic_efs_provisioning_enabled ? 0 : 1
  file_system_id = aws_efs_file_system.k8s-jenkins-controller-efs[0].id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/jenkins"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }
}

# PV based from :
#   https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
#   https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/static_provisioning
# Note : dynamic provisioning not supported on Fargate nodes
resource "kubernetes_persistent_volume" "k8s-jenkins-efs-static" {
  count = var.dynamic_efs_provisioning_enabled ? 0 : 1
  metadata {
    name = "${var.org_short_name}-jenkins-pv"
    # namespace = kubernetes_namespace.k8s-cluster-jenkins.id
    labels = {
      "app" = "${var.org_short_name}-jenkins"
    }
  }
  spec {
    storage_class_name = var.storage_class_name
    capacity = {
      storage = "1Gi" # This capacity value is ignored with EFS
    }
    access_modes                     = ["ReadWriteMany"]
    volume_mode                      = "Filesystem"
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        # This using an existing (static) AWS EFS accesspoint - it must already exist.
        volume_handle = "${aws_efs_file_system.k8s-jenkins-controller-efs[0].id}::${aws_efs_access_point.k8s-jenkins-controller-efs[0].id}"
      }
    }
  }
}
resource "kubernetes_persistent_volume_claim" "k8s-jenkins-efs-static" {
  count = var.dynamic_efs_provisioning_enabled ? 0 : 1
  metadata {
    name      = "${var.org_short_name}-jenkins-pvc"
    namespace = kubernetes_namespace.k8s-cluster-jenkins.id
    labels = {
      "app" = "${var.org_short_name}-jenkins"
    }
  }
  spec {
    storage_class_name = var.storage_class_name
    access_modes       = ["ReadWriteMany"]
    resources {
      limits = {}
      requests = {
        storage = "1Gi" # This capacity value is ignored with EFS
      }
    }
  }
}