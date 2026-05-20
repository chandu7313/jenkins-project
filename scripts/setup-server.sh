#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  AWS Ubuntu EC2 — One-shot setup script
#  Installs: Docker, Java 17, Jenkins, Nginx (reverse proxy)
#  Run as:   sudo bash setup-server.sh
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors for output ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Must run as root ──
if [ "$EUID" -ne 0 ]; then
  err "Please run as root: sudo bash setup-server.sh"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "   Jenkins + Docker Setup for AWS Ubuntu EC2"
echo "══════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────
# 1. System update
# ─────────────────────────────────────
log "Updating system packages..."
apt update -qq && apt upgrade -y -qq

# ─────────────────────────────────────
# 2. Install Docker
# ─────────────────────────────────────
if command -v docker &> /dev/null; then
  log "Docker is already installed: $(docker --version)"
else
  log "Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
  log "Docker installed: $(docker --version)"
fi

systemctl enable docker
systemctl start docker

# ─────────────────────────────────────
# 3. Install Java 17
# ─────────────────────────────────────
if command -v java &> /dev/null; then
  log "Java is already installed: $(java -version 2>&1 | head -1)"
else
  log "Installing OpenJDK 17..."
  apt install -y -qq openjdk-17-jre
  log "Java installed: $(java -version 2>&1 | head -1)"
fi

# ─────────────────────────────────────
# 4. Install Jenkins
# ─────────────────────────────────────
if command -v jenkins &> /dev/null || systemctl is-active --quiet jenkins 2>/dev/null; then
  log "Jenkins is already installed"
else
  log "Installing Jenkins..."
  wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" | tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

  apt update -qq
  apt install -y -qq jenkins
  log "Jenkins installed"
fi

systemctl enable jenkins
systemctl start jenkins

# ─────────────────────────────────────
# 5. Add users to docker group
# ─────────────────────────────────────
log "Adding 'jenkins' and 'ubuntu' users to docker group..."
usermod -aG docker jenkins 2>/dev/null || true
usermod -aG docker ubuntu 2>/dev/null || true

# Restart Jenkins so it picks up docker group
systemctl restart jenkins

# ─────────────────────────────────────
# 6. Install Nginx (reverse proxy)
# ─────────────────────────────────────
if command -v nginx &> /dev/null; then
  log "Nginx is already installed"
else
  log "Installing Nginx..."
  apt install -y -qq nginx
  log "Nginx installed"
fi

# Configure Nginx as reverse proxy for the Node.js app
cat > /etc/nginx/sites-available/jenkins-devops << 'NGINX_CONF'
server {
    listen 80;
    server_name _;

    # Node.js application
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
    }
}
NGINX_CONF

# Enable the site
ln -sf /etc/nginx/sites-available/jenkins-devops /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
systemctl enable nginx

# ─────────────────────────────────────
# 7. Configure firewall (ufw)
# ─────────────────────────────────────
log "Configuring firewall..."
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP (Nginx → App)
ufw allow 8080/tcp   # Jenkins
ufw allow 3000/tcp   # Direct app access (optional)
ufw --force enable
log "Firewall configured"

# ─────────────────────────────────────
# 8. Summary
# ─────────────────────────────────────
JENKINS_PASS=""
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  JENKINS_PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
fi

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<YOUR-EC2-PUBLIC-IP>")

echo ""
echo "══════════════════════════════════════════════════"
echo "   ✅  Setup Complete!"
echo "══════════════════════════════════════════════════"
echo ""
echo "  Docker:   $(docker --version)"
echo "  Java:     $(java -version 2>&1 | head -1)"
echo "  Jenkins:  $(systemctl is-active jenkins)"
echo "  Nginx:    $(systemctl is-active nginx)"
echo ""
echo "  ┌───────────────────────────────────────────┐"
echo "  │  Jenkins UI:  http://${PUBLIC_IP}:8080     │"
echo "  │  App (direct): http://${PUBLIC_IP}:3000    │"
echo "  │  App (nginx):  http://${PUBLIC_IP}         │"
echo "  └───────────────────────────────────────────┘"
echo ""
if [ -n "$JENKINS_PASS" ]; then
  echo "  Jenkins Initial Admin Password:"
  echo "  ${JENKINS_PASS}"
  echo ""
fi
echo "  ⚠  Log out and back in for docker group to take effect:"
echo "     exit && ssh -i \"jenkins-key.pem\" ubuntu@${PUBLIC_IP}"
echo ""
