# HTTPS cert
resource "aws_acm_certificate" "ebs_lb_cert" {
  domain_name       = "api.holdemhounds.com"
  validation_method = "DNS"
  tags              = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Service role
resource "aws_iam_role" "ebs_service_role" {
  name               = "poker-app-ebs-service-role"
  assume_role_policy = file("${path.module}/policies/ebs_service_assume.json")
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_health_attach" {
  role       = aws_iam_role.ebs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "ebs_service_attach" {
  role       = aws_iam_role.ebs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# Instance role/profile
resource "aws_iam_role" "ebs_instance_role" {
  name               = "poker-app-ebs-instance-role"
  assume_role_policy = file("${path.module}/policies/ebs_instance_assume.json")
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ecr_read_attach" {
  role       = aws_iam_role.ebs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ebs_tier_attach" {
  role       = aws_iam_role.ebs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "ebs_instance_profile" {
  name = "poker-app-ebs-instance-profile"
  role = aws_iam_role.ebs_instance_role.name
}

# Application
resource "aws_elastic_beanstalk_application" "server_app" {
  name        = "poker-app-ebs-application"
  description = "EBS Application for Poker App"
  tags        = local.tags
}

locals {
  https_port_namespace = "aws:elbv2:listener:443"
}

resource "aws_elastic_beanstalk_environment" "prod_env" {
  name                = "poker-app-ebs-prod"
  description         = "Prod Env for Poker App"
  application         = aws_elastic_beanstalk_application.server_app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.1.0 running Docker"
  tags                = local.tags

  # Environment-wide settings
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.ebs_service_role.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "HTTPS:443/ping"
  }

  # Instance settings
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = module.vpc.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", module.vpc.public_subnets)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", module.vpc.public_subnets)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = true
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t2.micro"
  }

  # Autoscaling settings
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ebs_instance_profile.name
  }

  # Load balancer settings
  setting {
    namespace = local.https_port_namespace
    name      = "Protocol"
    value     = "HTTPS"
  }

  setting {
    namespace = local.https_port_namespace
    name      = "SSLCertificateArns"
    value     = aws_acm_certificate.ebs_lb_cert.id
  }
}

# Latest App Version
resource "aws_s3_bucket" "app_version_bucket" {
  bucket = "poker-app-version-bucket"
  acl    = "private"
  tags   = local.tags
}

resource "aws_s3_bucket_object" "app_version_bundle" {
  bucket = aws_s3_bucket.app_version_bucket.id
  key    = "Dockerrun.aws.json"
  tags   = local.tags
  content = templatefile("${path.module}/templates/Dockerrun.aws.json.tmpl", {
    repo_url = var.repo_url
  })
}

resource "aws_elastic_beanstalk_application_version" "latest" {
  name        = "poker-app-latest-version"
  application = aws_elastic_beanstalk_application.server_app.name
  description = "Version latest of Poker App"
  bucket      = aws_s3_bucket.app_version_bucket.id
  key         = aws_s3_bucket_object.app_version_bundle.id
  tags        = local.tags
  depends_on  = [aws_s3_bucket_object.app_version_bundle]
}
