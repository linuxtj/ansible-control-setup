# Ansible Control Node - Proxmox LXC Setup

This project automates the deployment of an Ansible control node within a Proxmox LXC container using CentOS Stream 9. It's designed to provide a complete, reproducible environment for managing infrastructure through Ansible.

## Features

- Automated LXC container creation and configuration
- CentOS Stream 9 base system
- Pre-installed Ansible core and essential tools
- Python virtual environment with key packages
- Automated SSH key generation
- Pre-configured Ansible directory structure
- Comprehensive error handling
- SELinux configuration management
- Community-maintained Ansible collections

## Prerequisites

- Proxmox VE 8.x or later
- Internet connection
- Root access to Proxmox host
- Minimum 8GB available storage
- Basic understanding of Proxmox LXC containers

## Default Configuration

### Container Specifications
- Container ID: 800
- Memory: 2048 MB
- Swap: 512 MB
- CPU Cores: 2
- Storage: 8GB on local-lvm
- Network: DHCP on vmbr0
- Type: Unprivileged container with nesting enabled

### Installed Packages
- ansible-core
- python3-pip
- git
- sshpass
- vim
- curl
- wget
- tmux
- Development tools (gcc, python3-devel, etc.)

### Ansible Collections
- ansible.posix
- community.general
- community.crypto
- community.mysql
- containers.podman

## Installation

1. Create the scripts directory:
```bash
mkdir -p /root/infrastructure-as-code/
```

2. Save the script:
```bash
nano /root/infrastructure-as-code/setup-ansible-control.sh
# Copy and paste the script content
```

3. Make it executable:
```bash
chmod +x /root/infrastructure-as-code/setup-ansible-control.sh
```

4. Run the script:
```bash
/root/infrastructure-as-code/setup-ansible-control.sh
```

## Directory Structure

The script creates the following Ansible directory structure:
```
/etc/ansible/
├── ansible.cfg
├── collections/
├── group_vars/
├── host_vars/
├── inventories/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── roles/
```

## Post-Installation

After the script completes successfully:

1. Access the container:
```bash
pct enter 800
```

2. Change the root password:
```bash
passwd root
```

3. Verify Ansible installation:
```bash
ansible --version
```

4. The Python virtual environment will be automatically activated on login

## Security Considerations

1. Change the default password in the script before running
2. Update the SSH key location if needed
3. Review and adjust permissions as necessary
4. Consider implementing additional security measures based on your environment

## Troubleshooting

### Common Issues and Solutions

1. Template Download Fails:
```bash
pveam update
pveam available | grep centos
pveam download local centos-9-stream-default_20240828_amd64.tar.xz
```

2. SSH Key Issues:
```bash
# Regenerate SSH key manually
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa
```

3. Container Creation Fails:
- Check storage space: `df -h`
- Verify template existence
- Check Proxmox logs: `tail -f /var/log/pve/tasks/`

## Maintenance

### Updating the Container
```bash
pct enter 800
dnf update -y
```

### Backing Up
```bash
vzdump 800 --compress zstd --storage local
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes thoroughly
4. Submit a pull request

## License

[MIT License]

## Support

- For Proxmox-specific issues: [Proxmox Forums](https://forum.proxmox.com)
- For Ansible-specific issues: [Ansible Documentation](https://docs.ansible.com)

