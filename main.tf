locals {
  prefix = "yl"
}

resource "aws_ecr_repository" "ecr" {
  name         = "${local.prefix}-ecr"
  force_delete = true
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
      subnet_ids                   = ["subnet-02ade1d135132baff","subnet-01528a30e6cf8f25e","subnet-05cb129a6131bf583"] #List of subnet IDs to use for your tasks
      security_group_ids           = ["sg-0d0c4f80609cb55a1"] #Create a SG resource and pass it here
    }
  }
}
