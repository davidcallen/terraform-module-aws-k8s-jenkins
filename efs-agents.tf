# ---------------------------------------------------------------------------------------------------------------------
# Kubernetes Jenkins AGENTS EFS filesystem
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_efs_file_system" "k8s-jenkins-agents-efs" {
  count     = var.dynamic_efs_provisioning_enabled ? 0 : 1
  encrypted = true
  lifecycle {
    prevent_destroy = false # cant use var.environment.resource_deletion_protection
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name        = "${var.name}-agents-efs-data"
    Application = "jenkins"
  })
}
resource "aws_efs_mount_target" "k8s-jenkins-agents-efs" {
  count           = var.dynamic_efs_provisioning_enabled ? 0 : length(var.vpc_private_subnet_ids)
  file_system_id  = aws_efs_file_system.k8s-jenkins-agents-efs[0].id
  subnet_id       = var.vpc_private_subnet_ids[count.index]
  security_groups = [var.cluster_security_group_efs_id] # [aws_security_group.k8s-cluster-efs.id]
}
resource "aws_efs_access_point" "k8s-jenkins-agents-efs" {
  count          = var.dynamic_efs_provisioning_enabled ? 0 : 1
  file_system_id = aws_efs_file_system.k8s-jenkins-agents-efs[0].id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/home/jenkins"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }
}