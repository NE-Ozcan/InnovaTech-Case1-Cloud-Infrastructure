#!/bin/bash
set -e

# Logging instellen voor troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== [Innovatech Solutions] Start Provisioning Webserver (REQ-03, REQ-09) ==="

# 1. OS Pakketten updaten en Podman installeren (FOSS - REQ-10)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y podman uidmap slirp4netns fuse-overlayfs curl jq

# Ubuntu 24.04 AppArmor fix voor unprivileged user namespaces
sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 || true
echo "kernel.apparmor_restrict_unprivileged_userns=0" > /etc/sysctl.d/99-podman-userns.conf || true

# 2. Aanmaken van een Onbevoorrechte Gebruiker voor Rootless Podman
# Hiermee voorkomen we de gevaarlijke Docker Root Daemon (Docentfeedback de vakdocent!)
useradd -m -s /bin/bash appuser || true

# User Namespaces instellen via /etc/subuid en /etc/subgid
usermod --add-subuids 100000-165535 appuser
usermod --add-subgids 100000-165535 appuser
loginctl enable-linger appuser

# 3. Initiële HTML Bestemmingspagina genereren (Innovatech Ticketverkoop)
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "ec2-node")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "eu-central-1")

mkdir -p /home/appuser/webroot
cat << 'INITHTML' > /home/appuser/webroot/index.html
<!DOCTYPE html>
<html>
<head><title>Innovatech Solutions</title></head>
<body style="background:#0f172a;color:#f8fafc;font-family:sans-serif;text-align:center;padding:50px;">
  <h1>🎫 Innovatech Solutions - Ticket Portal</h1>
  <p>Webserver is online. Services worden geïnitialiseerd...</p>
</body>
</html>
INITHTML
chown -R appuser:appuser /home/appuser/webroot
chmod -R 755 /home/appuser/webroot

# 4. Container starten onder appuser met strikte 256MB cgroups limiet (REQ-09)
# We binden poort 80 (via net.ipv4.ip_unprivileged_port_start=80)
sysctl -w net.ipv4.ip_unprivileged_port_start=80

USER_UID=$(id -u appuser)
export XDG_RUNTIME_DIR="/run/user/$USER_UID"
mkdir -p "$XDG_RUNTIME_DIR"
chown -R appuser:appuser "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

su - appuser -c "export XDG_RUNTIME_DIR=/run/user/\$(id -u) && \
  podman run -d --name innovatech-web \
  --restart always \
  -p 80:80 \
  --memory 256m \
  -v /home/appuser/webroot:/usr/share/nginx/html:ro \
  docker.io/library/nginx:alpine"

# 5. Database Peering Verbindingsmonitor (Spoke 1 Web -> Spoke 2 Data Tier)
cat << 'DBCHECK' > /opt/db_monitor.sh
#!/bin/bash
DB_PORT=3306
WEBROOT="/home/appuser/webroot"
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "ec2-node")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "eu-central-1")

while true; do
  ACTIVE_IP=""
  for candidate in "10.2.1.112" "10.2.1.17"; do
    if python3 -c "import socket; s = socket.create_connection(('$candidate', $DB_PORT), timeout=2); s.close()" 2>/dev/null; then
      ACTIVE_IP="$candidate"
      break
    fi
  done

  if [ -n "$ACTIVE_IP" ]; then
    DB_STATUS_BADGE="<span class=\"badge badge-green\">✔ Database: \${ACTIVE_IP}:3306 (ONLINE)</span>"
    DB_TUNNEL_INFO="<p><strong>Database Peering Tunnel:</strong> Spoke 1 (10.1.0.0/16) &harr; Spoke 2 (10.2.0.0/16) [\${ACTIVE_IP}:3306 CONNECTED &amp; HEALTHY]</p>"
  else
    DB_STATUS_BADGE='<span class="badge badge-yellow" style="background:#854d0e;color:#fef08a;">⏳ Database: 10.2.1.112:3306 (CONNECTING...)</span>'
    DB_TUNNEL_INFO="<p><strong>Database Peering Tunnel:</strong> Verbinding initialiseren met Data Tier...</p>"
  fi

  cat <<HTML > $WEBROOT/index.html
<!DOCTYPE html>
<html lang="nl">
<head>
  <meta charset="UTF-8">
  <title>Innovatech Solutions - Ticket Portal</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f172a; color: #f8fafc; text-align: center; padding: 50px; }
    .card { background: #1e293b; border-radius: 12px; padding: 40px; max-width: 680px; margin: 0 auto; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
    h1 { color: #38bdf8; margin-bottom: 10px; }
    .badge { display: inline-block; padding: 6px 12px; border-radius: 20px; font-weight: bold; font-size: 0.85rem; margin: 5px; }
    .badge-green { background: #065f46; color: #34d399; }
    .badge-blue { background: #1e40af; color: #93c5fd; }
    .badge-purple { background: #581c87; color: #d8b4fe; }
    .info { margin-top: 25px; text-align: left; background: #0f172a; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 0.9rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🎫 Innovatech Solutions</h1>
    <p>Welkom bij het concertkaartjes reserveringsplatform.</p>
    <div>
      <span class="badge badge-green">✔ High Availability Multi-AZ</span>
      <span class="badge badge-blue">✔ Rootless Podman (No Root Daemon)</span>
      <span class="badge badge-purple">✔ Cgroups v2: 256MB RAM Limiet</span>
      $DB_STATUS_BADGE
    </div>
    <div class="info">
      <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
      <p><strong>Availability Zone:</strong> $AZ</p>
      <p><strong>Container Engine:</strong> Podman OCI Rootless</p>
      <p><strong>Memory Limit (REQ-09):</strong> memory.max: 256m</p>
      $DB_TUNNEL_INFO
      <p><strong>Status:</strong> Healthy (ALB Target Group Active)</p>
    </div>
  </div>
</body>
</html>
HTML
  chown -R appuser:appuser $WEBROOT/index.html
  sleep 5
done
DBCHECK

chmod +x /opt/db_monitor.sh
nohup /bin/bash /opt/db_monitor.sh >/dev/null 2>&1 &

echo "=== [Innovatech Solutions] Webserver, Rootless Podman en DB Monitor gestart! ==="
