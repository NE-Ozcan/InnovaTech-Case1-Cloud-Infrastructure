data "aws_availability_zones" "available" {
  state = "available"
}

# ==============================================================================
# 1. HUB VPC (10.0.0.0/16) - Centrale Ingress, Egress en Beheer (REQ-01)
# ==============================================================================
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-hub-vpc"
    Role = "Hub-Network-Management"
  }
}

resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "${var.project_name}-hub-igw"
  }
}

# Publieke Subnets voor de Application Load Balancer (Multi-AZ)
resource "aws_subnet" "hub_public_1" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.hub_cidr, 8, 1) # 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-hub-public-1a"
    Tier = "Public-Ingress"
  }
}

resource "aws_subnet" "hub_public_2" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.hub_cidr, 8, 2) # 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-hub-public-1b"
    Tier = "Public-Ingress"
  }
}

# Management Subnet voor CI/CD Self-Hosted Runner (REQ-07)
resource "aws_subnet" "hub_mgmt" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_cidr, 8, 10) # 10.0.10.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-hub-mgmt-1a"
    Tier = "Management-Private"
  }
}

# FINOPS KEUZE: Één centrale NAT Gateway in de Web Public Subnet 1 ($388/jr besparing!)
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.web_igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "hub_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.web_public_1.id

  tags = {
    Name = "${var.project_name}-central-nat-gw"
  }

  depends_on = [aws_internet_gateway.web_igw]
}

# Routing voor Publieke Ingress
resource "aws_route_table" "hub_public_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }

  tags = {
    Name = "${var.project_name}-hub-public-rt"
  }
}

resource "aws_route_table_association" "hub_pub_assoc_1" {
  subnet_id      = aws_subnet.hub_public_1.id
  route_table_id = aws_route_table.hub_public_rt.id
}

resource "aws_route_table_association" "hub_pub_assoc_2" {
  subnet_id      = aws_subnet.hub_public_2.id
  route_table_id = aws_route_table.hub_public_rt.id
}

# Routing voor Management Subnet
resource "aws_route_table" "hub_mgmt_rt" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "${var.project_name}-hub-mgmt-rt"
  }
}

resource "aws_route_table_association" "hub_mgmt_assoc" {
  subnet_id      = aws_subnet.hub_mgmt.id
  route_table_id = aws_route_table.hub_mgmt_rt.id
}


# ==============================================================================
# 2. SPOKE 1: WEB TIER VPC (10.1.0.0/16) - Schaalbare Webservers (REQ-01 & REQ-03)
# ==============================================================================
resource "aws_vpc" "spoke_web" {
  cidr_block           = var.spoke_web_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-spoke-web-vpc"
    Role = "Web-App-Tier"
  }
}

resource "aws_internet_gateway" "web_igw" {
  vpc_id = aws_vpc.spoke_web.id

  tags = {
    Name = "${var.project_name}-web-igw"
  }
}

# Publieke Subnets in Spoke Web voor de Application Load Balancer
resource "aws_subnet" "web_public_1" {
  vpc_id                  = aws_vpc.spoke_web.id
  cidr_block              = cidrsubnet(var.spoke_web_cidr, 8, 10) # 10.1.10.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-web-public-1a"
    Tier = "Public-Ingress"
  }
}

resource "aws_subnet" "web_public_2" {
  vpc_id                  = aws_vpc.spoke_web.id
  cidr_block              = cidrsubnet(var.spoke_web_cidr, 8, 20) # 10.1.20.0/24
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-web-public-1b"
    Tier = "Public-Ingress"
  }
}

# Routing voor Publieke Ingress in Web VPC
resource "aws_route_table" "web_public_rt" {
  vpc_id = aws_vpc.spoke_web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_igw.id
  }

  tags = {
    Name = "${var.project_name}-web-public-rt"
  }
}

resource "aws_route_table_association" "web_pub_assoc_1" {
  subnet_id      = aws_subnet.web_public_1.id
  route_table_id = aws_route_table.web_public_rt.id
}

resource "aws_route_table_association" "web_pub_assoc_2" {
  subnet_id      = aws_subnet.web_public_2.id
  route_table_id = aws_route_table.web_public_rt.id
}

# Private Web Subnets (100% afgeschermd van het publieke internet!)
resource "aws_subnet" "web_private_1" {
  vpc_id            = aws_vpc.spoke_web.id
  cidr_block        = cidrsubnet(var.spoke_web_cidr, 8, 1) # 10.1.1.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-web-private-1a"
    Tier = "App-Private"
  }
}

resource "aws_subnet" "web_private_2" {
  vpc_id            = aws_vpc.spoke_web.id
  cidr_block        = cidrsubnet(var.spoke_web_cidr, 8, 2) # 10.1.2.0/24
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-web-private-1b"
    Tier = "App-Private"
  }
}

resource "aws_route_table" "web_rt" {
  vpc_id = aws_vpc.spoke_web.id

  tags = {
    Name = "${var.project_name}-web-rt"
  }
}

resource "aws_route_table_association" "web_assoc_1" {
  subnet_id      = aws_subnet.web_private_1.id
  route_table_id = aws_route_table.web_rt.id
}

resource "aws_route_table_association" "web_assoc_2" {
  subnet_id      = aws_subnet.web_private_2.id
  route_table_id = aws_route_table.web_rt.id
}


# ==============================================================================
# 3. SPOKE 2: DATA TIER VPC (10.2.0.0/16) - Geïsoleerde Database (REQ-01 & REQ-02)
# ==============================================================================
resource "aws_vpc" "spoke_data" {
  cidr_block           = var.spoke_data_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-spoke-data-vpc"
    Role = "Database-Tier"
  }
}

# Dedicated Database Subnets voor Amazon RDS Multi-AZ Subnet Group
resource "aws_subnet" "data_private_1" {
  vpc_id            = aws_vpc.spoke_data.id
  cidr_block        = cidrsubnet(var.spoke_data_cidr, 8, 1) # 10.2.1.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-data-private-1a"
    Tier = "Data-Private"
  }
}

resource "aws_subnet" "data_private_2" {
  vpc_id            = aws_vpc.spoke_data.id
  cidr_block        = cidrsubnet(var.spoke_data_cidr, 8, 2) # 10.2.2.0/24
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-data-private-1b"
    Tier = "Data-Private"
  }
}

resource "aws_route_table" "data_rt" {
  vpc_id = aws_vpc.spoke_data.id

  tags = {
    Name = "${var.project_name}-data-rt"
  }
}

resource "aws_route_table_association" "data_assoc_1" {
  subnet_id      = aws_subnet.data_private_1.id
  route_table_id = aws_route_table.data_rt.id
}

resource "aws_route_table_association" "data_assoc_2" {
  subnet_id      = aws_subnet.data_private_2.id
  route_table_id = aws_route_table.data_rt.id
}


# ==============================================================================
# 4. VPC PEERING TUNNELS (FINOPS: $0/mnd i.p.v. $110/mnd Transit Gateway!)
# ==============================================================================

# Peering 1: Hub <-> Spoke 1 (Web Tier)
resource "aws_vpc_peering_connection" "hub_to_web" {
  vpc_id      = aws_vpc.hub.id
  peer_vpc_id = aws_vpc.spoke_web.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-peering-hub-to-web"
  }
}

# Peering 2: Spoke 1 (Web Tier) <-> Spoke 2 (Data Tier)
resource "aws_vpc_peering_connection" "web_to_data" {
  vpc_id      = aws_vpc.spoke_web.id
  peer_vpc_id = aws_vpc.spoke_data.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-peering-web-to-data"
  }
}

# LET OP ZERO-TRUST: Géén peering tussen Hub en Data VPC! (Non-transitieve isolatie)


# ==============================================================================
# 5. PEERING ROUTES (Onderlinge Netwerkpaden)
# ==============================================================================

# Hub Public RT -> Route naar Web VPC (10.1.0.0/16)
resource "aws_route" "hub_to_web_route" {
  route_table_id            = aws_route_table.hub_public_rt.id
  destination_cidr_block    = var.spoke_web_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub_to_web.id
}

# Hub Management RT -> Route naar Web VPC (10.1.0.0/16) voor CI/CD Runner
resource "aws_route" "hub_mgmt_to_web_route" {
  route_table_id            = aws_route_table.hub_mgmt_rt.id
  destination_cidr_block    = var.spoke_web_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub_to_web.id
}

# Web RT -> Route naar Hub VPC (10.0.0.0/16) voor inkomend ALB-verkeer
resource "aws_route" "web_to_hub_route" {
  route_table_id            = aws_route_table.web_rt.id
  destination_cidr_block    = var.hub_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub_to_web.id
}

# Web RT -> Route naar Data VPC (10.2.0.0/16) voor MySQL queries
resource "aws_route" "web_to_data_route" {
  route_table_id            = aws_route_table.web_rt.id
  destination_cidr_block    = var.spoke_data_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.web_to_data.id
}

# Web RT -> Route naar Internet via NAT Gateway (voor Podman containers & apt patches)
resource "aws_route" "web_to_nat_route" {
  route_table_id         = aws_route_table.web_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.hub_nat.id
}

# Data RT -> Route naar Web VPC (10.1.0.0/16) voor SQL antwoorden
resource "aws_route" "data_to_web_route" {
  route_table_id            = aws_route_table.data_rt.id
  destination_cidr_block    = var.spoke_web_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.web_to_data.id
}
