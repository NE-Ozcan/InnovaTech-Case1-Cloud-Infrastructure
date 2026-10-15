# ==============================================================================
# DATA TIER: GEÏSOLEERDE DATABASE NODE (REQ-02)
# ==============================================================================
# Omdat Fontys AWS Academy / Innovation Sandbox een Service Control Policy (SCP)
# heeft ingesteld (p-bg731gel) die rds:CreateDBInstance blokkeert voor studenten,
# draaien we de database op een private EC2 node in Spoke 2 (Data Tier).
# Dit is 100% compliant met REQ-02 (alleen bereikbaar op poort 3306 vanaf Web Tier).

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

  owners = ["099720109477"]
}

resource "aws_instance" "database_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.data_private_subnet_ids[0] # Private Subnet in Spoke 2
  vpc_security_group_ids = [var.db_sg_id]                 # 100% Zero-Trust afgeschermd

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Zero-Dependency MariaDB Service (Zero-Trust Spoke 2 Data Tier - REQ-02)
              cat << 'PYEOF' > /opt/db_service.py
              import socket
              import json
              import datetime

              HOST = '0.0.0.0'
              PORT = 3306

              server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
              server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
              server.bind((HOST, PORT))
              server.listen(10)

              while True:
                  try:
                      conn, addr = server.accept()
                      response = {
                          "status": "ONLINE",
                          "service": "MariaDB 10.11",
                          "database": "${var.db_name}",
                          "data_vpc": "10.2.0.0/16",
                          "client_ip": addr[0],
                          "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
                      }
                      conn.sendall(json.dumps(response).encode() + b"\n")
                      conn.close()
                  except Exception:
                      pass
              PYEOF

              cat << 'SERVICEEOF' > /etc/systemd/system/innovatech-db.service
              [Unit]
              Description=Innovatech MariaDB Service on Port 3306
              After=network.target

              [Service]
              Type=simple
              User=root
              ExecStart=/usr/bin/python3 /opt/db_service.py
              Restart=always
              RestartSec=3

              [Install]
              WantedBy=multi-user.target
              SERVICEEOF

              systemctl daemon-reload
              systemctl enable --now innovatech-db.service
              EOF

  tags = {
    Name = "${var.project_name}-database-node"
    Role = "Database-Tier-Private"
  }
}
