#!/bin/bash
#
# Rancher Deployment Script for ansible-admin box
# Run this script from the ansible-admin box to deploy Rancher on Proxmox
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as ansible user
if [ "$USER" != "ansible" ]; then
    print_warn "Not running as ansible user. Current user: $USER"
    print_info "It's recommended to run this as the ansible user"
fi

# Check if SSH key exists
if [ ! -f ~/.ssh/ansible_ed25519 ]; then
    print_error "SSH key not found at ~/.ssh/ansible_ed25519"
    print_info "Please ensure your SSH key is properly configured"
    exit 1
fi

# Check if vault file exists
if [ ! -f group_vars/vault.yml ]; then
    if [ -f group_vars/vault.yml.example ]; then
        print_warn "Vault file not found. Creating from template..."
        cp group_vars/vault.yml.example group_vars/vault.yml
        print_info "Please edit group_vars/vault.yml with your passwords"
        print_info "Then run: ansible-vault encrypt group_vars/vault.yml"
        exit 1
    fi
fi

# Function to run ansible playbook
run_playbook() {
    local playbook=$1
    local extra_args=${2:-}
    
    print_info "Running playbook: $playbook"
    
    if [ -f group_vars/vault.yml ]; then
        # Check if vault is encrypted
        if grep -q 'ANSIBLE_VAULT' group_vars/vault.yml; then
            ansible-playbook -i inventory/hosts.yml "$playbook" --ask-vault-pass $extra_args
        else
            print_warn "Vault file is not encrypted. Consider encrypting it with:"
            print_warn "ansible-vault encrypt group_vars/vault.yml"
            ansible-playbook -i inventory/hosts.yml "$playbook" $extra_args
        fi
    else
        ansible-playbook -i inventory/hosts.yml "$playbook" $extra_args
    fi
}

# Function to test connectivity
test_connectivity() {
    print_info "Testing connectivity to Proxmox nodes..."
    ansible proxmox -i inventory/hosts.yml -m ping
    
    if [ $? -eq 0 ]; then
        print_info "Successfully connected to all Proxmox nodes"
    else
        print_error "Failed to connect to one or more Proxmox nodes"
        print_info "Please check your SSH configuration and try again"
        exit 1
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "======================================"
    echo "   Rancher Deployment on Proxmox     "
    echo "======================================"
    echo "1) Test connectivity to Proxmox nodes"
    echo "2) Install Ansible collections"
    echo "3) Full deployment (VMs + K8s + Rancher)"
    echo "4) Deploy without VM provisioning"
    echo "5) Provision VMs only"
    echo "6) Deploy Kubernetes only"
    echo "7) Install Rancher only"
    echo "8) Run post-deployment tasks"
    echo "9) Show cluster status"
    echo "0) Exit"
    echo ""
}

# Install Ansible collections
install_collections() {
    print_info "Installing required Ansible collections..."
    ansible-galaxy collection install -r requirements.yml
    print_info "Collections installed successfully"
}

# Get cluster status
show_status() {
    print_info "Getting cluster status..."
    ansible rancher1 -i inventory/hosts.yml -b -m shell -a "kubectl get nodes"
    echo ""
    ansible rancher1 -i inventory/hosts.yml -b -m shell -a "kubectl get pods -n cattle-system"
}

# Main script
main() {
    while true; do
        show_menu
        read -p "Select an option [0-9]: " choice
        
        case $choice in
            1)
                test_connectivity
                ;;
            2)
                install_collections
                ;;
            3)
                print_info "Starting full deployment..."
                test_connectivity
                run_playbook site.yml
                print_info "Full deployment completed!"
                ;;
            4)
                print_info "Deploying without VM provisioning..."
                run_playbook site.yml "-e provision_vms=false"
                print_info "Deployment completed!"
                ;;
            5)
                print_info "Provisioning VMs only..."
                run_playbook playbooks/01-provision-vms.yml
                print_info "VM provisioning completed!"
                ;;
            6)
                print_info "Deploying Kubernetes only..."
                run_playbook playbooks/02-prepare-nodes.yml
                run_playbook playbooks/03-deploy-kubernetes.yml
                print_info "Kubernetes deployment completed!"
                ;;
            7)
                print_info "Installing Rancher only..."
                run_playbook playbooks/04-install-rancher.yml
                print_info "Rancher installation completed!"
                ;;
            8)
                print_info "Running post-deployment tasks..."
                run_playbook playbooks/05-post-deploy.yml
                print_info "Post-deployment tasks completed!"
                ;;
            9)
                show_status
                ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-9"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main