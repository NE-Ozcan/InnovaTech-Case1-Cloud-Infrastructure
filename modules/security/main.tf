# ==============================================================================
# ZERO-TRUST FIREWALL MATRIX (Conform Keuzedocument Paragraaf 2.4 - REQ-02)
# ==============================================================================

# 1. Application Load Balancer Security Group (Spoke Web VPC Ingress)
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-alb-sg-"
  description = "Publieke Ingress voor ALB; accepteert HTTPS/HTTP"
  vpc_id      = var.spoke_web_vpc_id

  # Inkomend HTTPS vanaf het publieke internet
  ingress {
    description = "HTTPS publiek verkeer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inkomend HTTP (voor automatische 301 redirect naar HTTPS)
  ingress {
    description = "HTTP redirect naar HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Uitgaand naar de backend webservers in Spoke 1 (10.1.0.0/16)
  egress {
    description = "Doorgestuurd verkeer naar Podman Web Tier"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.spoke_web_cidr]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
    Tier = "Ingress-ALB"
  }
}

# 2. Webserver Security Group (Spoke 1 Web VPC)
resource "aws_security_group" "web_sg" {
  name_prefix = "${var.project_name}-web-sg-"
  description = "Web Tier Security Group - Accepteert uitsluitend verkeer vanaf Ingress"
  vpc_id      = var.spoke_web_vpc_id

  # Inkomend HTTP verkeer: vanaf ALB / Web Subnets
  ingress {
    description = "Inkomend HTTP verkeer vanaf ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.spoke_web_cidr, var.hub_cidr]
  }

  # Uitgaand: Database queries naar de Data VPC (10.2.0.0/16) via Peering
  egress {
    description = "MySQL queries naar Data Tier"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.spoke_data_cidr]
  }

  egress {
    description = "PostgreSQL queries naar Data Tier"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.spoke_data_cidr]
  }

  # Uitgaand: DNS queries (UDP en TCP poort 53) voor domeinnaamherkenning (apt mirrors & container registries)
  egress {
    description = "DNS queries UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS queries TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Uitgaand: HTTPS via centrale NAT Gateway voor OS security patches & container images
  egress {
    description = "Uitgaande HTTPS downloads via centrale NAT Gateway"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Uitgaande HTTP downloads via centrale NAT Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-web-sg"
    Tier = "App-Web"
  }
}

# 3. Database Security Group (Spoke 2 Data VPC) - 100% Zero-Trust afgeschermd!
resource "aws_security_group" "db_sg" {
  name_prefix = "${var.project_name}-db-sg-"
  description = "Database Security Group - Uitsluitend bereikbaar voor Web Tier"
  vpc_id      = var.spoke_data_vpc_id

  # Inkomend: SQL poort 3306 en 5432 UITSLUITEND vanaf de Web Tier (10.1.0.0/16)
  ingress {
    description = "Toegestane MySQL verbindingen vanaf Web Tier"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.spoke_web_cidr]
  }

  ingress {
    description = "Toegestane PostgreSQL verbindingen vanaf Web Tier"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.spoke_web_cidr]
  }

  # LET OP ZERO-TRUST: Geen enkele egress-regel!
  # De database initieert zelf nooit verbindingen naar buiten (implicit deny).

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-db-sg"
    Tier = "Data-Database"
  }
}

# 4. CI/CD Self-Hosted Runner Security Group (Hub VPC Management Subnet) (REQ-07)
resource "aws_security_group" "runner_sg" {
  name_prefix = "${var.project_name}-runner-sg-"
  description = "Security Group voor Self-Hosted CI/CD Runner (Pull-based)"
  vpc_id      = var.hub_vpc_id

  # LET OP: Geen inkomende poorten open! Runner pollt uitgaand via HTTPS.

  # Uitgaand HTTPS naar GitHub/GitLab om deployment taken op te halen
  egress {
    description = "Pull deployment taken via HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Uitgaand naar de Web Tier via VPC Peering voor applicatie deployment
  egress {
    description = "Private deployment naar Web Tier"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.spoke_web_cidr]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-runner-sg"
    Tier = "Management-CI-CD"
  }
}
