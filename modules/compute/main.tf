# ==============================================================================
# 1. DATA SOURCE: Ubuntu 24.04 LTS AMI
# ==============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ==============================================================================
# 2. APPLICATION LOAD BALANCER (In Hub VPC Public Subnets - REQ-01 & REQ-04)
# ==============================================================================
resource "aws_lb" "main_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.web_public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
    Tier = "Public-Ingress"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.spoke_web_vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/index.html"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  # Connection draining bij Spot Instance terminatie (2 minuten grace period)
  deregistration_delay = 60

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ==============================================================================
# 3. LAUNCH TEMPLATE: EC2 Webserver met Rootless Podman (REQ-03 & REQ-09)
# ==============================================================================
resource "aws_launch_template" "web_template" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.web_instance_type

  network_interfaces {
    associate_public_ip_address = false # 100% Private (Geen publiek IP!)
    security_groups             = [var.web_sg_id]
  }

  user_data = filebase64("${path.module}/cloud-init.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-webserver-node"
      Role = "Stateless-Podman-Worker"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# 4. HYBRIDE AUTO SCALING GROUP: ON-DEMAND + SPOT INSTANCES (FINOPS - REQ-04)
# ==============================================================================
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "${var.project_name}-web-asg-"
  vpc_zone_identifier = var.web_private_subnet_ids
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # FinOps Mixed Instances Policy: 2 On-Demand basis + Spot voor pieken!
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web_template.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.micro"
      }

      override {
        instance_type = "t3a.micro" # AMD alternatief voor extra Spot beschikbaarheid
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = var.asg_min_size # Vaste Multi-AZ basis van 2
      on_demand_percentage_above_base_capacity = 0                # 100% van de piekschaling is SPOT (70-90% korting!)
      spot_allocation_strategy                 = "price-capacity-optimized"
    }
  }

  health_check_type         = "ELB"
  health_check_grace_period = 180

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
