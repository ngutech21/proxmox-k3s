# Ansible bootstrap

## 1) Generate inventory from Terraform

From the repository root, in `01-provision`:

```bash
terraform init
terraform apply
```

This writes inventory to:

- `ansible/inventory/hosts.yml`

If VMs already exist and you only want to refresh inventory:

```bash
terraform apply -target=local_file.ansible_inventory
```

## 2) Run base OS prep for k3s nodes

From the repository root:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook 02-configure/playbooks/base-prep.yml
```

This installs core packages (`qemu-guest-agent`, `open-iscsi`, `nfs-common`, etc.) and applies k3s node prerequisites (swap off, kernel modules, sysctl).
It also enables unattended upgrades and automatic security updates via APT.
It partitions, formats, and mounts the dedicated Longhorn disk at `/var/lib/longhorn`.

If your Longhorn disk device is different than `/dev/sdb`, override it:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook 02-configure/playbooks/base-prep.yml -e longhorn_disk_device=/dev/sdc -e longhorn_disk_partition=/dev/sdc1
```

## 3) Reboot all k3s nodes sequentially

From the repository root:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook 02-configure/playbooks/restart-nodes.yml
```

This reboots all nodes in the inventory one by one and waits for each host to return
before continuing with the next node.
