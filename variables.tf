# Variable Definitions and defaults.
#
# Only define what is needed in this module
#
variable "aws_region" {
  type = string
}
variable "name" {
  description = "The Name of the deployed app (and its resources)"
  type        = string
  default     = ""
}
variable "namespace" {
  type = string
}
variable "environment" {
  description = "Environment information e.g. account IDs, public/private subnet cidrs"
  type = object({
    name = string
    # Environment Account IDs are used for giving permissions to those Accounts for resources such as AMIs
    account_id           = string
    resource_name_prefix = string
    # For some environments  (e.g. Core, Customer/production) want to protect against accidental deletion of resources
    resource_deletion_protection = bool
    default_tags                 = map(string)
  })
  default = {
    name                         = ""
    account_id                   = ""
    resource_name_prefix         = ""
    resource_deletion_protection = true
    default_tags                 = {}
  }
}
variable "org_domain_name" {
  description = "Domain name for organisation e.g. parkrunpointsleague.org"
  default     = ""
  type        = string
}
variable "org_short_name" {
  description = "Short name for organisation e.g. prpl"
  default     = ""
  type        = string
}
variable "cluster_name" {
  description = "The Kubernetes Cluster name"
  type        = string
  default     = ""
}
variable "cluster_security_group_efs_id" {
  type = string
}
variable "vpc_id" {
  description = "The VPC ID"
  type        = string
  default     = ""
}
variable "vpc_public_subnet_ids" {
  description = "The VPC public subnet IDs list"
  type        = list(string)
  default     = []
}
variable "vpc_public_subnet_cidrs" {
  description = "The VPC public subnet CIDRs list"
  type        = list(string)
  default     = []
}
variable "vpc_private_subnet_ids" {
  description = "The VPC private subnet IDs list"
  type        = list(string)
  default     = []
}
variable "vpc_private_subnet_cidrs" {
  description = "The VPC private subnet CIDRs list"
  type        = list(string)
  default     = []
}
variable "cluster_ingress_allowed_cidrs" {
  description = "The Cluster ingress allowed CIDRs list"
  type        = list(string)
  default     = []
}
variable "dynamic_efs_provisioning_enabled" {
  type = bool
}
variable "storage_class_name" {
  type = string
}
variable "route53_enabled" {
  description = "If using Route53 for DNS resolution"
  default     = false
  type        = bool
}
variable "route53_public_hosted_zone_id" {
  description = "Route53 Public Hosted Zone ID (if in use)."
  default     = ""
  type        = string
}
variable "route53_private_hosted_zone_id" {
  description = "Route53 Private Hosted Zone ID (if in use)."
  default     = ""
  type        = string
}
variable "ha_high_availability_enabled" {
  description = "High Availability setup using Auto-Scaling Group, across AZs with Application Load Balancer"
  type        = bool
  default     = false
}
variable "ha_public_load_balancer" {
  description = "High Availability Public Load Balancer config"
  type = object({
    enabled       = bool
    hostname_fqdn = string
    port          = number
    ssl_cert = object({
      use_amazon_provider = bool
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = bool
    })
    allowed_ingress_cidrs = object({
      https = list(string)
    })
    disallow_ingress_internal_health_check_from_cidrs = list(string)
    # Dont want users reaching internal healthcheck page
  })
  default = {
    enabled       = false
    hostname_fqdn = ""
    port          = 443
    ssl_cert = {
      use_amazon_provider = true
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = false
    }
    allowed_ingress_cidrs = {
      https = []
    }
    disallow_ingress_internal_health_check_from_cidrs = []
  }
}
variable "ha_private_load_balancer" {
  description = "High Availability Private Load Balancer config"
  type = object({
    enabled       = bool
    hostname_fqdn = string
    port          = number
    ssl_cert = object({
      use_amazon_provider = bool
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = bool
    })
    allowed_ingress_cidrs = object({
      https = list(string)
    })
    disallow_ingress_internal_health_check_from_cidrs = list(string)
    # Dont want users reaching internal healthcheck page
  })
  default = {
    enabled       = false
    hostname_fqdn = ""
    port          = 443
    ssl_cert = {
      use_amazon_provider = true
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = false
    }
    allowed_ingress_cidrs = {
      https = []
    }
    disallow_ingress_internal_health_check_from_cidrs = []
  }
}
variable "jenkins_admin_password" {
  type      = string
  sensitive = true
}
variable "global_default_tags" {
  description = "Global default tags"
  type        = map(string)
  default     = {}
}