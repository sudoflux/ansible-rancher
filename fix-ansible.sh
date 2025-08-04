#!/bin/bash

# Script to fix Ansible version and collection issues

echo "Fixing Ansible installation and collections..."

# Update system packages
sudo apt update

# Remove old Ansible if installed via apt
sudo apt remove -y ansible

# Install pip if not already installed
sudo apt install -y python3-pip

# Install latest Ansible via pip
pip3 install --user ansible

# Add ~/.local/bin to PATH if not already there
if ! echo $PATH | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
fi

# Check new Ansible version
echo "New Ansible version:"
ansible --version

# Remove old collections and reinstall
rm -rf ~/.ansible/collections/

# Install collections with specific versions that work better
ansible-galaxy collection install community.general:>=6.0.0,<8.0.0
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install ansible.posix

# Install required Python libraries for Proxmox
pip3 install --user proxmoxer requests

echo "Ansible, collections, and Python libraries updated successfully!"
echo "Please run 'source ~/.bashrc' or start a new shell session."