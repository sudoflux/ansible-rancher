# Ansible Rancher Kubernetes Deployment

This Ansible playbook automates the deployment of a 3-node HA Kubernetes cluster with Rancher on Proxmox VMs using Ceph storage.

## Architecture Overview

- **3-node Kubernetes cluster** running on Proxmox VMs
- **Rancher HA deployment** with 3 replicas
- **Calico CNI** for pod networking
- **cert-manager** for TLS certificate management
- **Optional monitoring** with Prometheus and Grafana

## Prerequisites

1. **Proxmox Cluster**: 3-node Proxmox cluster with Ceph storage configured
2. **VM Template**: Ubuntu 22.04 template (ID: 9000) with cloud-init support
3. **Network**: VLAN 100 configured on Proxmox bridge
4. **SSH Access**: SSH key authentication to Proxmox nodes
5. **Ansible**: Version 2.14+ installed locally

## Quick Start

### 1. Install Ansible Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Configure Vault (Passwords)

```bash
cp group_vars/vault.yml.example group_vars/vault.yml
# Edit vault.yml with your passwords
ansible-vault encrypt group_vars/vault.yml
```

### 3. Update Inventory

Edit `inventory/hosts.yml` to match your environment:
- Update Proxmox node IPs
- Verify VM IP assignments
- Adjust resource allocations if needed

### 4. Deploy the Cluster

```bash
# Full deployment (provisions VMs and installs everything)
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

# Skip VM provisioning (if VMs already exist)
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass -e provision_vms=false

# Deploy only specific components
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-kubernetes.yml --ask-vault-pass
ansible-playbook -i inventory/hosts.yml playbooks/04-install-rancher.yml --ask-vault-pass
```

## Configuration Options

### group_vars/all.yml

Key configuration variables:

- `vm_template_id`: Proxmox VM template ID (default: 9000)
- `vm_storage`: Storage pool for VMs (default: ceph-vm-storage)
- `k8s_version`: Kubernetes version (default: 1.28.5)
- `rancher_version`: Rancher version (default: 2.8.1)
- `rancher_hostname`: FQDN for Rancher access
- `install_monitoring`: Deploy Prometheus/Grafana (default: false)
- `configure_ceph_storage`: Setup Ceph CSI driver (default: false)

## Playbook Structure

1. **01-provision-vms.yml**: Creates VMs on Proxmox from template
2. **02-prepare-nodes.yml**: Configures OS, installs containerd, kubelet
3. **03-deploy-kubernetes.yml**: Initializes K8s cluster, joins nodes
4. **04-install-rancher.yml**: Deploys cert-manager and Rancher
5. **05-post-deploy.yml**: Optional monitoring, backups, validation

## VM Specifications

| VM | CPU | RAM | Disk | Proxmox Node | IP |
|---|---|---|---|---|---|
| rancher1 | 4 | 8GB | 100GB | pve1 | 192.168.100.60 |
| rancher2 | 4 | 8GB | 100GB | pve2 | 192.168.100.61 |
| rancher3 | 4 | 8GB | 100GB | pve3 | 192.168.100.62 |

## Post-Deployment

### Access Rancher

1. Add to `/etc/hosts`:
   ```
   192.168.100.60 rancher.homelab.local
   ```

2. Browse to: https://rancher.homelab.local

3. Login with bootstrap password from vault

### kubectl Access

SSH to any master node:
```bash
ssh ubuntu@192.168.100.60
kubectl get nodes
kubectl get pods -A
```

### Next Steps

1. Complete Rancher initial setup
2. Import Harvester cluster as downstream cluster
3. Create additional K3s/RKE2 clusters as needed
4. Configure backup schedules
5. Setup monitoring and alerting

## Troubleshooting

### VM Provisioning Issues
- Verify template ID exists: `qm list` on Proxmox
- Check Ceph storage pool: `pvesm status`
- Ensure VLAN 100 is configured on bridge

### Kubernetes Installation
- Check containerd: `systemctl status containerd`
- Verify kubelet: `systemctl status kubelet`
- Review logs: `journalctl -u kubelet -f`

### Rancher Access
- Check pods: `kubectl get pods -n cattle-system`
- Review logs: `kubectl logs -n cattle-system deployment/rancher`
- Verify ingress: `kubectl get ingress -n cattle-system`

## Security Considerations

1. **Change default passwords** in vault.yml
2. **Use strong passwords** for Rancher and Grafana
3. **Configure firewall rules** for cluster access
4. **Enable RBAC** and configure user permissions
5. **Regular backups** of etcd and persistent data
6. **Keep components updated** with security patches

## License

MIT