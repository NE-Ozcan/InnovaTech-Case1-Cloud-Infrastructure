# ==============================================================================
# FASE 3: OBSERVABILITY & AUTO-SCALING TRIGGER STACK (REQ-05 & REQ-04)
# ==============================================================================
# Biedt realtime dashboards, geautomatiseerde piekdetectie en FinOps-afschaling.

# 1. AUTO SCALING POLICIES (Dynamische Schaalregels)
# ------------------------------------------------------------------------------
# Schaal-Uit Policy: Voegt bij concertverkoop-pieken 1 Spot Instance toe
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# Schaal-In Policy: Verwijdert in daluren 1 instance ter kostenbesparing (FinOps)
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# 2. CLOUDWATCH METRIC ALARMS (Piekdetectie & Schaaltriggers)
# ------------------------------------------------------------------------------
# High CPU Alarm: Triggert bij >70% gemiddelde CPU over 2 opeenvolgende minuten
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Triggert automatische opschaling bij concertkaartjes piekbelasting (>70% CPU) (REQ-05)"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

# Low CPU Alarm: Triggert afschaling bij <30% CPU in daluren
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Triggert automatische afschaling in daluren (<30% CPU) voor minimale kosten (FinOps - REQ-04 & REQ-05)"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

# 3. CLOUDWATCH OBSERVABILITY DASHBOARD (Centraal Monitoring Overzicht - REQ-05)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "observability" {
  dashboard_name = "${var.project_name}-observability-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name, { stat = "Average", label = "Gemiddelde CPU Belasting (%)" }]
          ]
          period = 60
          region = "eu-central-1"
          title  = "Innovatech Web Tier - CPU Belasting (Piekdetectie)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main_alb.arn_suffix, { stat = "Sum", label = "Inkomende HTTP Requests" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", label = "Response Tijd (sec)" }]
          ]
          period = 60
          region = "eu-central-1"
          title  = "Application Load Balancer - Verkeer & Responstijd (REQ-01)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.web_tg.arn_suffix, "LoadBalancer", aws_lb.main_alb.arn_suffix, { stat = "Average", label = "Gezonde Webservers" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Ongezonde Webservers" }]
          ]
          period = 60
          region = "eu-central-1"
          title  = "Target Group - Health Check Beschikbaarheid (Multi-AZ)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name, { stat = "Sum", label = "Netwerk In (Bytes)" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", label = "Netwerk Uit (Bytes)" }]
          ]
          period = 60
          region = "eu-central-1"
          title  = "Netwerkdoorvoer Webservers"
        }
      }
    ]
  })
}
