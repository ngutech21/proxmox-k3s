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
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.yml"
  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    control_plane_nodes = local.control_plane_nodes
    worker_nodes        = local.worker_nodes
    ansible_user        = var.vm_username
  })

  depends_on = [proxmox_virtual_environment_vm.k3s_node_1]
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
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
