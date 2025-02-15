locals {
  prefix = "yl"
}

resource "aws_ecr_repository" "ecr" {
  name         = "${local.prefix}-ecr"
  force_delete = true
}

module "vpc-1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"
  name    = "yl-vpc-1"

  cidr             = "10.1.0.0/16"
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  #private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets   = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  # database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway   = false  # set to false if no private subnet
  single_nat_gateway   = false
  enable_dns_hostnames = true # needed for DNS resolution
}

resource "aws_security_group" "allow_ssh" {
  name = "yl-ecr-ecs-security-group"
  description = "Allow SSH inbound"
  #vpc_id = "vpc-01c494fe1e8787c82" vpc-0e387e57c766bf7b9
  #vpc_id = "vpc-0e387e57c766bf7b9"
  vpc_id = module.vpc-1.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8080
  ip_protocol = "tcp"
  to_port = 8080
}


resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 0
  ip_protocol = "tcp"
  to_port = 65535
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${local.prefix}-ecs"
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    yl-task-1 = { #task definition and service name -> #Change
      cpu    = 512
      memory = 1024
      container_definitions = {
        yl-container = { #container name -> Change
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-ecr:latest"
          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      # subnet_ids                   = ["subnet-02ade1d135132baff","subnet-01528a30e6cf8f25e","subnet-05cb129a6131bf583"] #List of subnet IDs to use for your tasks
      # security_group_ids           = ["sg-0d0c4f80609cb55a1"] #Create a SG resource and pass it here
      subnet_ids                   = data.aws_subnets.public-1.ids
      security_group_ids           = [aws_security_group.allow_ssh.id]
    }
  }
}
