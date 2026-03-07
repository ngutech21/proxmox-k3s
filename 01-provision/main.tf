terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure_tls
}

locals {
  enabled_nodes = [
    for n in var.cluster_nodes : n
    if try(n.enabled, true)
  ]
}

resource "proxmox_virtual_environment_vm" "k3s_node_1" {
  for_each      = { for n in local.enabled_nodes : n.name => n }
  name          = each.value.name
  node_name     = each.value.proxmox_node
  vm_id         = each.value.vm_id
  scsi_hardware = "virtio-scsi-single"

  tags = distinct(concat(["terraform", "k3s"], coalesce(each.value.tags, [])))

  clone {
    vm_id = each.value.template_id
    full  = true
  }

  cpu {
    cores = coalesce(each.value.cores, var.vm_cores)
    type  = "host"
  }

  memory {
    dedicated = max(coalesce(each.value.memory_mb, var.vm_memory_mb), coalesce(each.value.memory_max_mb, var.vm_memory_max_mb))
    floating  = min(coalesce(each.value.memory_mb, var.vm_memory_mb), coalesce(each.value.memory_max_mb, var.vm_memory_max_mb))
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.vm_disk_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    discard      = "on"
    iothread     = true
  }

  dynamic "disk" {
    for_each = each.value.role == "worker" ? [1] : []
    content {
      datastore_id = coalesce(var.vm_longhorn_disk_datastore, var.vm_disk_datastore)
      interface    = "scsi1"
      size         = var.vm_longhorn_disk_size_gb
      serial       = "longhorn-${each.value.vm_id}"
      discard      = "on"
      iothread     = true
    }
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.vm_ip_cidr}"
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = var.vm_dns_servers
    }

    user_account {
      username = var.vm_username
      keys     = [var.vm_ssh_public_key]
    }
  }

  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }

  on_boot = true
}
