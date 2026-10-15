# ==============================================================================
# INNOVATECH SOLUTIONS - CLOUD-NATIVE HUB & SPOKE ARCHITECTUUR (OPENTOFU / IAC)
# ==============================================================================

# 1. Netwerk Module (Hub VPC, Spoke 1 Web VPC, Spoke 2 Data VPC & Peering)
module "networking" {
  source = "./modules/networking"

  project_name    = var.project_name
  environment     = var.environment
  hub_cidr        = var.hub_cidr
  spoke_web_cidr  = var.spoke_web_cidr
  spoke_data_cidr = var.spoke_data_cidr
}

# 2. Security Module (Zero-Trust Security Groups Matrix)
module "security" {
  source = "./modules/security"

  project_name      = var.project_name
  environment       = var.environment
  hub_vpc_id        = module.networking.hub_vpc_id
  spoke_web_vpc_id  = module.networking.spoke_web_vpc_id
  spoke_data_vpc_id = module.networking.spoke_data_vpc_id
  hub_cidr          = var.hub_cidr
  spoke_web_cidr    = var.spoke_web_cidr
  spoke_data_cidr   = var.spoke_data_cidr
}

# 3. Compute Module (ALB, Launch Template met Rootless Podman & Spot ASG)
module "compute" {
  source = "./modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  hub_vpc_id             = module.networking.hub_vpc_id
  spoke_web_vpc_id       = module.networking.spoke_web_vpc_id
  web_public_subnet_ids  = module.networking.web_public_subnet_ids
  web_private_subnet_ids = module.networking.web_private_subnet_ids
  alb_sg_id              = module.security.alb_sg_id
  web_sg_id              = module.security.web_sg_id
  web_instance_type      = var.web_instance_type
  asg_min_size           = var.asg_min_size
  asg_max_size           = var.asg_max_size
  asg_desired_capacity   = var.asg_desired_capacity
}

# 4. Database Module (Amazon RDS MySQL Multi-AZ)
module "database" {
  source = "./modules/database"

  project_name            = var.project_name
  environment             = var.environment
  data_private_subnet_ids = module.networking.data_private_subnet_ids
  db_sg_id                = module.security.db_sg_id
  db_instance_class       = var.db_instance_class
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
}
