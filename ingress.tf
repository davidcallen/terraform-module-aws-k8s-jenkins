//# ---------------------------------------------------------------------------------------------------------------------
//# Kubernetes : Ingress using AWS App Load Balancer
//# With use of annotations e.g. "kubernetes.io/ingress.class : alb" this will create an Private ALB for use by this ingress.
//# It uses the AWS Load Balancer Controller (installed into Cluster) to do this.
//# It also creates a TargetGroup for the service. It will listen on port 443 and forward to jenkins onto its Pod Port.
//# Can then access Jenkins via the ALB DNS
//# ---------------------------------------------------------------------------------------------------------------------
resource "kubernetes_ingress" "k8s-ingress-jenkins" {
  count = (var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled)
  || (var.ha_private_load_balancer.enabled))) ? 1 : 0
  metadata {
    name      = "${var.cluster_name}-ingress-jenkins"
    namespace = var.org_short_name
    annotations = {
      # For info on annotations see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/load-balancer-name" = var.cluster_name
      "alb.ingress.kubernetes.io/target-type"        = "instance"
      "alb.ingress.kubernetes.io/backend-protocol"   = "HTTP"
      "alb.ingress.kubernetes.io/scheme"             = var.ha_public_load_balancer.enabled ? "internet-facing" : "internal"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = (var.ha_public_load_balancer.ssl_cert.use_amazon_provider
      || var.ha_private_load_balancer.ssl_cert.use_amazon_provider) ? aws_acm_certificate.k8s-ingress-jenkins[0].arn : "" # TODO : create the below self-signed tls cert
      "alb.ingress.kubernetes.io/ssl-policy" = "ELBSecurityPolicy-TLS-1-1-2017-01"
      #       "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\":80}]"   # temp test on port 80
      "alb.ingress.kubernetes.io/healthcheck-path" = "/login"
      "alb.ingress.kubernetes.io/subnets"          = join(",", var.ha_public_load_balancer.enabled ? var.vpc_public_subnet_ids : var.vpc_private_subnet_ids)
      # "alb.ingress.kubernetes.io/inbound-cidrs" = ...
      # "alb.ingress.kubernetes.io/security-groups" =  sg-xxxx, nameOfSg1, nameOfSg2
    }
  }

  spec {
    backend {
      service_name = "jenkins"
      service_port = 8080
    }
    // ... for path based routing ...
    //    rule {
    //      http {
    //        path {
    //          backend {
    //            service_name = "${var.org_short_name}-jenkins"
    //            service_port = 8080
    //          }
    //
    //          path = "/jenkins/*"
    //        }
    //      }
    //    }
    tls {
      hosts = ["jenkins.${var.environment.name}.${var.org_domain_name}"]
    }
  }
  wait_for_load_balancer = true # Wait so we can get Load Balancer DNS name for our Route53 records below ...
}

# ---------------------------------------------------------------------------------------------------------------------
# SSL/TLS Certificate for the Load Balancer
# ---------------------------------------------------------------------------------------------------------------------
# The below self-signed cert can be useful in testing....
//resource "tls_private_key" "ingress-jenkins" {
//  algorithm = "RSA"
//}
//resource "tls_self_signed_cert" "ingress-jenkins" {
//  key_algorithm   = "RSA"
//  private_key_pem = tls_private_key.ingress-jenkins.private_key_pem
//  subject {
//    common_name   = "jenkins.${var.environment.name}.${var.org_domain_name}"
//    organization  = var.org_name
//    country       = "GB"
//    locality      = "London"
//    organizational_unit = "HQ"
//    province      = "Greater London"
//  }
//  validity_period_hours = 720
//  early_renewal_hours   = 600
//  allowed_uses = [
//    "key_encipherment",
//    "digital_signature",
//    "server_auth",
//  ]
//}
//resource "aws_acm_certificate" "ingress-jenkins" {
//  private_key      = tls_private_key.ingress-jenkins.private_key_pem
//  certificate_body = tls_self_signed_cert.ingress-jenkins.cert_pem
//  depends_on = [tls_self_signed_cert.ingress-jenkins]
//}
resource "aws_acm_certificate" "k8s-ingress-jenkins" {
  count = (var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? 1 : 0
  domain_name       = "jenkins.${var.environment.name}.${var.org_domain_name}"
  validation_method = "DNS"
  tags = merge(var.environment.default_tags, {
    Name = "${var.name}-k8s-cluster-jenkins"
  })
  lifecycle {
    create_before_destroy = true
  }
}
locals {
  https_cert_domain_validation_options = (var.route53_enabled && var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? aws_acm_certificate.k8s-ingress-jenkins[0].domain_validation_options : []
}
resource "aws_route53_record" "jenkins-controller-amazon-provider-https-cert-validation" {
  for_each = {
    for dvo in local.https_cert_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_public_hosted_zone_id
}
resource "aws_acm_certificate_validation" "jenkins-controller-amazon-provider" {
  count = (var.route53_enabled && var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? 1 : 0
  certificate_arn         = aws_acm_certificate.k8s-ingress-jenkins[0].arn
  validation_record_fqdns = [for record in aws_route53_record.jenkins-controller-amazon-provider-https-cert-validation : record.fqdn]
}

# ---------------------------------------------------------------------------------------------------------------------
# Route53 DNS for the Load Balancers
# ---------------------------------------------------------------------------------------------------------------------
//data "kubernetes_ingress" "k8s-ingress-jenkins" {
//  count = (var.ha_high_availability_enabled && (
//    (var.ha_public_load_balancer.enabled)
//  || (var.ha_private_load_balancer.enabled))) ? 1 : 0
//  metadata {
//    name = "${var.cluster_name}-ingress-jenkins"
//  }
//}
# The below use of "kubernetes_ingress.k8s-ingress-jenkins[0].status.0.load_balancer.0.ingress.0.hostname" can only be
# accessed once ALB created so can be prone to fail here
resource "aws_route53_record" "jenkins-controller-amazon-provider-public-dns" {
  count           = (var.route53_enabled && var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_public_load_balancer.hostname_fqdn
  records         = [kubernetes_ingress.k8s-ingress-jenkins[0].status.0.load_balancer.0.ingress.0.hostname]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_public_hosted_zone_id
}
# If Public ALB and no Private ALB then use Public ALB DNS on the PrivateHZ (otherwise DNS resolution will fail)
resource "aws_route53_record" "jenkins-controller-amazon-provider-private-dns-for-public-alb" {
  count = (var.route53_enabled && var.ha_high_availability_enabled
    && var.ha_public_load_balancer.enabled
    && var.ha_private_load_balancer.enabled == false
  ) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_public_load_balancer.hostname_fqdn
  records         = [kubernetes_ingress.k8s-ingress-jenkins[0].status.0.load_balancer.0.ingress.0.hostname]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_private_hosted_zone_id
}

resource "aws_route53_record" "jenkins-controller-amazon-provider-private-dns-for-private-alb" {
  count           = (var.route53_enabled && var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_private_load_balancer.hostname_fqdn
  records         = [kubernetes_ingress.k8s-ingress-jenkins[0].status.0.load_balancer.0.ingress.0.hostname]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_private_hosted_zone_id
}