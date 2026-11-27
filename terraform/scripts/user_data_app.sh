#!/usr/bin/env bash
# ==============================================================================
# Script de Bootstrap (user_data) - Instâncias de Aplicação (app1 / app2)
# Atende ao requisito INF-12: Docker, Docker Compose, Git, AWS CLI, psql,
# chrony (NTP) e unattended-upgrades.
# ==============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/7] Atualizando repositórios e sistema operacional..."
apt-get update -y
apt-get upgrade -y

echo "==> [2/7] Instalando utilitários essenciais, Git, chrony e unattended-upgrades..."
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  chrony \
  unattended-upgrades \
  postgresql-client \
  jq \
  unzip

# Configura e ativa o chrony (NTP)
systemctl enable chrony
systemctl restart chrony

# Ativa atualizações automáticas de segurança
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

echo "==> [3/7] Instalando AWS CLI v2 oficial..."
if ! command -v aws &> /dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

echo "==> [4/7] Instalando Docker Engine e Docker Compose Plugin..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

# Adiciona o usuário padrão 'ubuntu' ao grupo docker para execução sem root
usermod -aG docker ubuntu

echo "==> [5/7] Configurando diretórios da aplicação e permissões..."
mkdir -p /opt/portal-b2b/{apps,config,logs,certs}
chown -R ubuntu:ubuntu /opt/portal-b2b

echo "==> [6/7] Configurando rotação de logs no daemon do Docker..."
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "5"
  }
}
EOF
systemctl restart docker

echo "==> [7/7] Bootstrap concluído com sucesso em $(date -u)!"
