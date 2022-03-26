//resource "aws_ebs_volume" "jenkins-agents-ebs" {
//  availability_zone = var.aws_zones[1]
//  size              = 8
//  encrypted         = true
//
//  tags = merge(var.global_default_tags, var.environment.default_tags, {
//    Name            = "${var.name}-jenkins-agents"
//    Zone            = var.aws_zones[0]
//    Application     = "jenkins-agents"
////    ApplicationName = var.name_suffix
//  })
//}
