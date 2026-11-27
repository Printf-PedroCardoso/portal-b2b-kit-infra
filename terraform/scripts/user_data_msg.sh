#!/usr/bin/env bash
# ==============================================================================
# Script de Bootstrap (user_data) - Instância de Mensageria (Redpanda rp-2)
# Atende aos requisitos INF-05 e INF-12: Docker, Docker Compose, Git, AWS CLI,
# psql, chrony (NTP) e unattended-upgrades.
# ==============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/6] Atualizando repositórios e sistema operacional..."
apt-get update -y
apt-get upgrade -y

echo "==> [2/6] Instalando dependências, chrony e unattended-upgrades..."
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

# NTP e Segurança
systemctl enable chrony
systemctl restart chrony
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

echo "==> [3/6] Instalando AWS CLI v2..."
if ! command -v aws &> /dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

echo "==> [4/6] Instalando Docker Engine..."
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
usermod -aG docker ubuntu

echo "==> [5/6] Instalando utilitário rpk (Redpanda CLI) oficial..."
curl -fsSL https://packages.redpanda.com/redpanda/install.sh | bash || true
apt-get install -y redpanda-rpk || true

echo "==> [6/6] Ajustando otimizações de kernel para Redpanda e Redis..."
sysctl -w vm.max_map_count=262144 || true
sysctl -w fs.file-max=500000 || true
sysctl -w vm.overcommit_memory=1 || true
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "fs.file-max=500000" >> /etc/sysctl.conf
echo "vm.overcommit_memory=1" >> /etc/sysctl.conf

mkdir -p /opt/redpanda/data /opt/redis/data
chown -R ubuntu:ubuntu /opt/redpanda /opt/redis

echo "==> Bootstrap de mensageria concluído com sucesso em $(date -u)!"
