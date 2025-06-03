
# Getting started

## Building Talos OS Images

Before deploying the cluster, you need Talos OS images in Hetzner Cloud. Use the provided Packer configuration:

```bash
./_packer/create.sh
```

This will build ARM and x86 Talos images and upload snapshots to Hetzner. You can customize the Talos version and extensions via the Talos Image Factory.

For custom images with extensions, generate schematic IDs and override image URLs in `hcloud.auto.pkrvars.hcl`.

---

## Define cluster configuration

Read through and edit [main.tf](./main.tf) accordingly.


## Deploy the cluster

Just init/apply and you should be good to go, tho keep in mind that before that you need to create `terraform.tfvars` with required values such as API keys or export them as environment variables.

```bash
terraform init
terraform apply
```

## Retrieving Configs

After deployment, export the generated kubeconfig and Talos configs:

```bash
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```

Use `kubectl` and `talosctl` to manage your cluster.



# Getting Started

## 1. Build Talos OS Images

Before deploying, build Talos OS images for Hetzner Cloud using Packer:

```bash
./_packer/create.sh
````

This creates both ARM and x86 Talos images and uploads them as Hetzner snapshots. You can customize the Talos version and extensions using the Talos Image Factory.

To build custom images with extensions, generate schematic IDs and override image URLs in `hcloud.auto.pkrvars.hcl`.

---

## 2. Configure the Cluster

Edit [main.tf](./main.tf) to suit your needs.

---

## 3. Deploy the Cluster

Create a `terraform.tfvars` file with required values (e.g. API keys), or export them as environment variables.

Then run:

```bash
terraform init
terraform apply
```

---

## 4. Retrieve Configuration Files

After deployment, export the kubeconfig and Talos config:

```bash
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```

Use `kubectl` and `talosctl` with these configs to manage your cluster.


