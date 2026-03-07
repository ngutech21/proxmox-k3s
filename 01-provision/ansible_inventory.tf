locals {
  inventory_nodes = [
    for n in var.cluster_nodes : {
      name                 = n.name
      ip                   = n.ip
      role                 = n.role
      longhorn_disk_serial = n.role == "worker" ? "longhorn-${n.vm_id}" : null
    }
    if try(n.enabled, true)
  ]

  control_plane_nodes = [
    for n in local.inventory_nodes : n
    if n.role == "control_plane"
  ]

  worker_nodes = [
    for n in local.inventory_nodes : n
    if n.role == "worker"
  ]

  kube_vip_version                = "v0.8.2"
  kube_vip_cloud_provider_version = "v0.0.12"
  cert_manager_selfsigned_issuer  = "selfsigned-bootstrap"
  cert_manager_ca_issuer          = "homelab-ca"
  cert_manager_root_cert          = "homelab-root-ca"
  cert_manager_root_secret        = "homelab-root-ca-key-pair"
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.yml"
  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    control_plane_nodes = local.control_plane_nodes
    worker_nodes        = local.worker_nodes
    ansible_user        = var.vm_username
  })
}

resource "local_file" "bootstrap_vars" {
  filename = "${path.module}/../.generated/bootstrap.vars.yml"
  content = templatefile("${path.module}/templates/bootstrap.vars.yml.tftpl", {
    k3s_version                     = var.k3s_version
    api_endpoint                    = var.api_endpoint
    kube_vip_service_range          = var.kube_vip_service_range
    kube_vip_version                = local.kube_vip_version
    kube_vip_cloud_provider_version = local.kube_vip_cloud_provider_version
  })
}

resource "local_file" "core_values" {
  filename = "${path.module}/../.generated/core.values.yaml"
  content = templatefile("${path.module}/templates/core.values.yaml.tftpl", {
    domain_suffix                  = var.domain_suffix
    longhorn_host                  = "longhorn.${var.domain_suffix}"
    cert_manager_enable_smoke_test = var.cert_manager_enable_smoke_test
    cert_manager_smoke_host        = "smoke.${var.domain_suffix}"
    cert_manager_selfsigned_issuer = local.cert_manager_selfsigned_issuer
    cert_manager_ca_issuer         = local.cert_manager_ca_issuer
    cert_manager_root_cert         = local.cert_manager_root_cert
    cert_manager_root_secret       = local.cert_manager_root_secret
  })
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "bootstrap_vars_path" {
  description = "Path to generated bootstrap variables"
  value       = local_file.bootstrap_vars.filename
}

output "core_values_path" {
  description = "Path to generated Helmfile state values"
  value       = local_file.core_values.filename
}

output "cluster_bootstrap_token" {
  description = "Shared k3s bootstrap token"
  value       = var.cluster_bootstrap_token
  sensitive   = true
}

output "node_ips" {
  description = "IPs assigned to created nodes"
  value       = [for n in local.inventory_nodes : n.ip]
}

output "control_plane_ips" {
  description = "IPs assigned to control-plane nodes"
  value       = [for n in local.control_plane_nodes : n.ip]
}

output "worker_ips" {
  description = "IPs assigned to worker nodes"
  value       = [for n in local.worker_nodes : n.ip]
}

output "node_details" {
  description = "Details for all enabled nodes"
  value = [
    for n in var.cluster_nodes : {
      name                 = n.name
      role                 = n.role
      proxmox_node         = n.proxmox_node
      vm_id                = n.vm_id
      ip                   = n.ip
      longhorn_disk_serial = n.role == "worker" ? "longhorn-${n.vm_id}" : null
    }
    if try(n.enabled, true)
  ]
}
