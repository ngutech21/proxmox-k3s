variable "proxmox_api_url" {
  description = "Proxmox API endpoint, for example https://pve.lab.local:8006/api2/json"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID, for example terraform@pve!k3s"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure_tls" {
  description = "Set to true when Proxmox uses a self-signed certificate"
  type        = bool
  default     = true
}

variable "cluster_nodes" {
  description = "Explicit VM definitions for the k3s cluster"
  type = list(object({
    name          = string
    role          = string
    proxmox_node  = string
    vm_id         = number
    template_id   = number
    ip            = string
    cores         = optional(number)
    memory_mb     = optional(number)
    memory_max_mb = optional(number)
    tags          = optional(list(string))
    enabled       = optional(bool, true)
  }))

  validation {
    condition = length([
      for n in var.cluster_nodes : n
      if contains(["control_plane", "worker"], n.role)
    ]) == length(var.cluster_nodes)
    error_message = "Each cluster_nodes.role must be one of: control_plane, worker."
  }

  validation {
    condition     = length(distinct([for n in var.cluster_nodes : n.name])) == length(var.cluster_nodes)
    error_message = "Each cluster_nodes.name must be unique."
  }

  validation {
    condition     = length(distinct([for n in var.cluster_nodes : n.vm_id])) == length(var.cluster_nodes)
    error_message = "Each cluster_nodes.vm_id must be unique."
  }

  validation {
    condition     = length(distinct([for n in var.cluster_nodes : n.ip])) == length(var.cluster_nodes)
    error_message = "Each cluster_nodes.ip must be unique."
  }

  validation {
    condition = length([
      for n in var.cluster_nodes : n
      if n.role == "control_plane" && try(n.enabled, true)
    ]) > 0
    error_message = "At least one enabled control_plane node is required in cluster_nodes."
  }

  validation {
    condition = length([
      for n in var.cluster_nodes : n
      if try(n.enabled, true)
    ]) > 0
    error_message = "At least one enabled node is required in cluster_nodes."
  }
}

variable "vm_cores" {
  description = "Number of vCPU cores"
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Guaranteed RAM in MiB (ballooning minimum)"
  type        = number
  default     = 4096
}

variable "vm_memory_max_mb" {
  description = "Maximum RAM in MiB when ballooning is enabled"
  type        = number
  default     = 8192
}

variable "vm_disk_datastore" {
  description = "Datastore used for VM disk"
  type        = string
  default     = "local-zfs"
}

variable "vm_cloudinit_datastore" {
  description = "Datastore used for cloud-init drive"
  type        = string
  default     = "local-zfs"
}

variable "vm_disk_size_gb" {
  description = "VM disk size in GB"
  type        = number
  default     = 40
}

variable "vm_longhorn_disk_size_gb" {
  description = "Dedicated Longhorn data disk size in GB"
  type        = number
  default     = 300
}

variable "vm_longhorn_disk_datastore" {
  description = "Datastore for Longhorn data disk (defaults to vm_disk_datastore when null)"
  type        = string
  default     = null
}

variable "vm_network_bridge" {
  description = "Bridge to attach the VM NIC to"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip_cidr" {
  description = "CIDR prefix length used for cloud-init IPv4 addresses"
  type        = number
  default     = 24

  validation {
    condition     = var.vm_ip_cidr >= 1 && var.vm_ip_cidr <= 32
    error_message = "vm_ip_cidr must be between 1 and 32."
  }
}

variable "vm_gateway" {
  description = "Default gateway for the VM"
  type        = string
  default     = "192.168.178.1"
}

variable "vm_dns_servers" {
  description = "DNS servers for the VM"
  type        = list(string)
  default     = ["1.1.1.1"]
}

variable "vm_username" {
  description = "Cloud-init user"
  type        = string
  default     = "ubuntu"
}

variable "vm_ssh_public_key" {
  description = "SSH public key injected through cloud-init"
  type        = string
}
