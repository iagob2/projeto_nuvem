# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ECS Task Definition (exemplo)
# resource "aws_ecs_task_definition" "app" {
#   family                   = "${var.project_name}-task"
#   network_mode             = "awsvpc"
#   requires_compatibilities  = ["FARGATE"]
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = aws_iam_role.ecs_execution.arn
#   task_role_arn            = aws_iam_role.ecs_task.arn
#
#   container_definitions = jsonencode([
#     {
#       name  = "app"
#       image = "nginx:latest"
#
#       portMappings = [
#         {
#           containerPort = 80
#           protocol      = "tcp"
#         }
#       ]
#
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
#           "awslogs-region"        = var.aws_region
#           "awslogs-stream-prefix" = "ecs"
#         }
#       }
#     }
#   ])
# }

# ECS Service (exemplo)
# resource "aws_ecs_service" "app" {
#   name            = "${var.project_name}-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.app.arn
#   desired_count   = 2
#   launch_type     = "FARGATE"
#
#   network_configuration {
#     subnets          = aws_subnet.private[*].id
#     security_groups  = [aws_security_group.ecs.id]
#     assign_public_ip = false
#   }
#
#   load_balancer {
#     target_group_arn = aws_lb_target_group.app.arn
#     container_name   = "app"
#     container_port   = 80
#   }
#
#   depends_on = [aws_lb_listener.app]
# }

# CloudWatch Log Group para ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# ============================================================================
# ECS Task Definition - Back-end
# ============================================================================
resource "aws_ecs_task_definition" "backend" {
  family                   = "back-end-nuvem"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "${aws_ecr_repository.backend.repository_url}:latest"
    
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    environment = [{
      name  = "API_GATEWAY_URL"
      value = aws_api_gateway_stage.tasks_api.invoke_url
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }

    essential = true
  }])

  tags = {
    Name = "back-end-nuvem-task"
  }
}

# ============================================================================
# ECS Service - Back-end
# ============================================================================
resource "aws_ecs_service" "backend" {
  name            = "back-end-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  tags = {
    Name = "back-end-service"
  }
}

# ============================================================================
# ECS Task Definition - Front-end
# ============================================================================
resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-nuvem"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "${aws_ecr_repository.frontend.repository_url}:latest"
    
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }

    essential = true
  }])

  tags = {
    Name = "frontend-nuvem-task"
  }
}

# ============================================================================
# ECS Service - Front-end
# ============================================================================
resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id  # Front-end em subnet pública
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true  # Front-end precisa de IP público
  }

  tags = {
    Name = "frontend-service"
  }
}

