#!/bin/bash

# Exit on any error
set -e

# Variables
CTID="800"
HOSTNAME="ansible-control"
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/centos-9-stream-default_20240828_amd64.tar.xz"
MEMORY="2048"
SWAP="512"
CORES="2"
PASSWORD="PASSWORD123"
SSH_KEY="/root/.ssh/id_rsa.pub"

# Function to check if template exists
check_template() {
  if [ ! -f "/var/lib/vz/template/cache/$(basename $TEMPLATE)" ]; then
    echo "Template not found. Downloading..."
    pveam update
    pveam download local $(basename $TEMPLATE)
  fi
}

# Function to check and create SSH key
setup_ssh_key() {
  if [ ! -f "$SSH_KEY" ]; then
    echo "SSH key not found. Generating new key pair..."
    mkdir -p /root/.ssh
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
  fi
}

# Function to check if container exists
check_container() {
  if pct status $CTID &>/dev/null; then
    echo "Container $CTID already exists. Please choose a different CTID or remove the existing container."
    exit 1
  fi
}

# Main execution
echo "Starting Ansible Control Node setup..."

# Run checks
echo "Running prerequisite checks..."
check_template
setup_ssh_key
check_container

echo "Creating container..."
# Create the container
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --memory $MEMORY \
  --swap $SWAP \
  --cores $CORES \
  --rootfs $STORAGE:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --password $PASSWORD \
  --ssh-public-keys $SSH_KEY \
  --unprivileged 1 \
  --features nesting=1

echo "Starting container..."
pct start $CTID

echo "Waiting for container to initialize..."
sleep 20

echo "Installing dependencies..."
# Install EPEL and dependencies
pct exec $CTID -- bash -c 'dnf install -y epel-release && \
  dnf update -y && \
  dnf install -y \
  ansible-core \
  python3-pip \
  git \
  sshpass \
  vim \
  curl \
  wget \
  tmux \
  python3-devel \
  gcc \
  libffi-devel \
  openssl-devel' || {
  echo "Failed to install packages"
  exit 1
}

echo "Setting up Ansible directory structure..."
# Create ansible directory structure
pct exec $CTID -- bash -c 'mkdir -p /etc/ansible/inventories/{dev,staging,prod} && \
  mkdir -p /etc/ansible/{group_vars,host_vars,roles,collections}'

# Create base ansible.cfg
pct exec $CTID -- bash -c 'cat > /etc/ansible/ansible.cfg << EOF
[defaults]
inventory = /etc/ansible/inventories
roles_path = /etc/ansible/roles
collections_path = /etc/ansible/collections
remote_tmp = /tmp/ansible
local_tmp = /tmp/ansible
host_key_checking = False
deprecation_warnings = False
interpreter_python = auto_silent
timeout = 60

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=30m -o ConnectionAttempts=100
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
EOF'

# Create example inventory
pct exec $CTID -- bash -c 'cat > /etc/ansible/inventories/dev/hosts << EOF
[all:vars]
ansible_user=admin
ansible_become=true
ansible_become_method=sudo

[web]
# web01.example.com
# web02.example.com

[db]
# db01.example.com
# db02.example.com

[dev:children]
web
db
EOF'

echo "Setting permissions..."
# Set proper permissions
pct exec $CTID -- bash -c 'chown -R root:root /etc/ansible && chmod -R 755 /etc/ansible'

echo "Setting up Python virtual environment..."
# Create ansible virtual environment
pct exec $CTID -- bash -c 'python3 -m venv /opt/ansible-venv && \
  . /opt/ansible-venv/bin/activate && \
  pip install --upgrade pip && \
  pip install ansible ansible-lint yamllint molecule molecule-docker'

# Add venv activation to .bashrc
pct exec $CTID -- bash -c 'echo "source /opt/ansible-venv/bin/activate" >> /root/.bashrc'

echo "Installing Ansible collections..."
# Install additional RHEL-specific collections
pct exec $CTID -- bash -c 'source /opt/ansible-venv/bin/activate && \
  ansible-galaxy collection install \
    ansible.posix \
    community.general \
    community.crypto \
    community.mysql \
    containers.podman'

echo "Configuring SELinux..."
# SELinux configuration - check if SELinux is available first
pct exec $CTID -- bash -c 'if [ -f /etc/selinux/config ]; then
    setenforce 0 2>/dev/null || true
    sed -i "s/^SELINUX=.*/SELINUX=permissive/g" /etc/selinux/config
fi'

echo "Setup complete! Container information:"
echo "------------------------------------"
echo "Container ID: $CTID"
echo "Hostname: $HOSTNAME"
echo "IP Address: $(pct exec $CTID -- ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
echo "SSH Key: $SSH_KEY"
echo ""
echo "To access your container:"
echo "pct enter $CTID"
echo ""
echo "Don't forget to change the root password inside the container!"
