# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.

## Section 0. Introduction

This repository (hereinafter referred to as "this repo") is a Proof of Concept (PoC) for Infrastructure as Code. It primarily achieves automated deployment of a High Availability (HA) Kubernetes cluster (Kubeadm / microk8s) in a purely on-premise environment using QEMU-KVM.
This repo was developed based on personal exercises conducted during an internship at Cathay General Hospital. The objective is to establish an on-premise GitLab instance capable of automated infrastructure deployment, with the aim of creating a reusable IaC pipeline for legacy systems.
(This repository has been approved for public release by the relevant company department as part of a technical portfolio.)
The machine specifications used for development are listed below for reference only:

- Chipset: Intel® HM770
- CPU: Intel® Core™ i7 processor 14700HX
- RAM: Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
- SSD: WD PC SN560 SDDPNQE-1T00-1032

The project can be cloned using the following command:

```shell
git clone https://github.com/csning1998/on-premise-gitlab-deployment.git
```

This repo features the following resource allocation, subject to inherent RAM constraints, provided for reference only:

| Network Segment (CIDR) | Service Tier  | Usage (Service)  | Storage Pool Name   | VIP (HAProxy/Ingress) | Node IP Allocation                                 | Component (Role) | Quantity | Unit vCPU | Unit RAM | Subtotal RAM  | Notes                                                            |
| ---------------------- | ------------- | ---------------- | ------------------- | --------------------- | -------------------------------------------------- | ---------------- | -------- | --------- | -------- | ------------- | ---------------------------------------------------------------- |
| 172.16.134.0/24        | App (GitLab)  | Kubeadm Cluster  | iac-kubeadm         | 172.16.134.250        | `.200` (Master), `.21x` (Worker)                   | Kubeadm Master   | 1        | 2         | 6 GB     | 6,144 MB      | Used for GitLab Helm Chart deployment; Control Plane 建議 4-6 GB |
|                        |               |                  |                     |                       |                                                    | Kubeadm Worker   | 2        | 4         | 8 GB     | 16,384 MB     | For Rails/Sidekiq, GitLab Runner, etc.                           |
| 172.16.135.0/24        | App (Harbor)  | MicroK8s Cluster | iac-harbor          | 172.16.135.250        | `.20x` (Nodes)                                     | MicroK8s Node    | 1        | 4         | 6 GB     | 6,144 MB      | Full Harbor consumes ~4-5 GB                                     |
| 172.16.136.0/24        | Shared        | Vault HA         | iac-vault           | 172.16.136.250        | `.20x` (Vault), `.21x` (HAProxy)                   | Vault (Raft)     | 1        | 1         | 1 GB     | 1,024 MB      | Raft is lightweight; Shared secrets management center            |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      | TCP forwarding only                                              |
| 172.16.137.0/24        | Data (Harbor) | Postgres HA      | iac-postgres-harbor | 172.16.137.250        | `.20x` (Postgres), `.21x` (Etcd), `.22x` (HAProxy) | Postgres         | 1        | 2         | 4 GB     | 4,096 MB      | `shared_buffers` set to 512MB; Instantiated via Module 21        |
|                        |               |                  |                     |                       |                                                    | Etcd             | 1        | 1         | 1.5 GB   | 1,536 MB      | Patroni low usage                                                |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| 172.16.138.0/24        | Data (Harbor) | Redis HA         | iac-redis-harbor    | 172.16.138.250        | `.20x` (Redis), `.21x` (HAProxy)                   | Redis            | 1        | 1         | 1 GB     | 1,024 MB      | `maxmemory` set to 512MB                                         |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| 172.16.139.0/24        | Data (Harbor) | MinIO HA         | iac-minio-harbor    | 172.16.139.250        | `.20x` (MinIO), `.21x` (HAProxy)                   | MinIO            | 1        | 1         | 3 GB     | 3,072 MB      | Java/Go heap not that heavy                                      |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| 172.16.140.0/24        | Data (GitLab) | Postgres HA      | iac-postgres-gitlab | 172.16.140.250        | `.20x` (Postgres), `.21x` (Etcd), `.22x` (HAProxy) | Postgres         | 1        | 2         | 4 GB     | 4,096 MB      | Replication of Layer 20                                          |
|                        |               |                  |                     |                       |                                                    | Etcd             | 1        | 1         | 1.5 GB   | 1,536 MB      | Same as Harbor Postgres                                          |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| 172.16.141.0/24        | Data (GitLab) | Redis HA         | iac-redis-gitlab    | 172.16.141.250        | `.20x` (Redis), `.21x` (HAProxy)                   | Redis            | 1        | 1         | 1 GB     | 1,024 MB      | Same as Harbor Redis                                             |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| 172.16.142.0/24        | Data (GitLab) | MinIO HA         | iac-minio-gitlab    | 172.16.142.250        | `.20x` (MinIO), `.21x` (HAProxy)                   | MinIO            | 1        | 1         | 3 GB     | 3,072 MB      | Same as Harbor MinIO                                             |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 1.5 GB   | 1,536 MB      |                                                                  |
| **Total**              |               |                  |                     |                       |                                                    |                  | **30**   |           |          | **55,808 MB** | ≈ 54.5 GB                                                        |

### A. Disclaimer

- This repo currently only supports Linux devices with CPU virtualization functionality. It has not been tested on other distributions such as Fedora, Arch, CentOS, WSL2, etc. The following command can be used to check whether the development machine supports virtualization:

    ```shell
    lscpu | grep Virtualization
    ```

    Possible outputs include:
    - Virtualization: VT-x (Intel).
    - Virtualization: AMD-V (AMD).
    - If there is no output, virtualization may not be supported.

> [!WARNING]
> **Compatibility Warning**
>
> This repo currently only supports Linux devices with CPU virtualization functionality. If the CPU of the device in use does not support virtualization (for example, lacking VT-x/AMD-V), please switch to the `legacy-workstation-on-ubuntu` branch with minimum HA kubeadm cluster support.
>
> In addition, this repo is currently developed independently by an individual and may contain edge-case issues. Any issues discovered will be fixed immediately.

### B. Prerequisites

Before starting, confirm that the device meets the following conditions:

- One Linux host, with RHEL 10 or Ubuntu 24 recommended.
- The CPU must support virtualization, i.e., have VT-x or AMD-V.
- `sudo` privileges are required to operate Libvirt.
- `podman` and `podman compose` are installed, used for containerized mode.
- The `whois` package is installed, primarily needed for the `mkpasswd` command.
- The `jq` package is installed, used for parsing JSON.

### C. Progress

This project is currently capable of provisioning the following Services 1 to 5, where individual services are paired with HAProxy and Keepalived:

1. HA HashiCorp Vault with Raft Storage.
2. Postgres / Patroni including etcd..
3. Redis / Sentinel.
4. MinIO (S3) / Distributed MinIO.
5. Harbor as the container image Registry.
6. **[WIP]** GitLab / Runner / Gitaly etc.
7. Private Key Encryption.
8. [OpenTofu](https://github.com/opentofu/opentofu.git) Migration for `*.tfstates` files.

### D. The Entrypoint: `entry.sh`

> [!NOTE]
> The content of Section 1 and Section 2 consists of pre-execution setup tasks. See the explanation below for details

All service pre-setup tasks and lifecycle management in this repo are handled through the `entry.sh` script located in the root directory. After switching to the root directory of this repo in the terminal, executing `./entry.sh` will display the following content:

```text
➜  on-premise-gitlab-deployment git:(main) ✗ ./entry.sh
... (Some preflight check)

======= IaC-Driven Virtualization Management =======

[INFO] Environment: NATIVE
--------------------------------------------------
[OK] Development Vault (Local): Running (Unsealed)
[OK] Production Vault (Layer10): Running (Unsealed)
------------------------------------------------------------

1) [DEV] Set up TLS for Dev Vault (Local)          9) Build Packer Base Image
2) [DEV] Initialize Dev Vault (Local)             10) Provision Terraform Layer
3) [DEV] Unseal Dev Vault (Local)                 11) Rebuild Layer via Ansible
4) [PROD] Unseal Production Vault (via Ansible)   12) Verify SSH
5) Generate SSH Key                               13) Switch Environment Strategy
6) Setup KVM / QEMU for Native                    14) Purge All Libvirt Resources
7) Setup Core IaC Tools                           15) Purge All Packer and Terraform Resources
8) Verify IaC Environment                         16) Quit

[INPUT] Please select an action:
```

Selecting options `9`, `10`, `11` will dynamically generate a submenu based on the `packer/output` and `terraform/layers` directories. The submenu under the complete configuration is as follows:

1. When selecting `9) Build Packer Base Image`.

    ```text
    [INPUT] Please select an action: 9
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.

    1) 01-base-docker           4) 04-base-postgres         7) 07-base-vault
    2) 02-base-kubeadm          5) 05-base-redis            8) Build ALL Packer Images
    3) 03-base-microk8s         6) 06-base-minio            9) Back to Main Menu

    [INPUT] Select a Packer build to run:
    ```

2. When selecting `10) Provision Terraform Layer`.

    ```text
    [INPUT] Please select an action: 10
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) 10-vault-core          5) 20-harbor-minio       9) 30-harbor-microk8s    13) 90-github-meta
    2) 20-gitlab-minio        6) 20-harbor-postgres    10) 40-gitlab-platform   14) Back to Main Menu
    3) 20-gitlab-postgres     7) 20-harbor-redis       11) 40-harbor-platform
    4) 20-gitlab-redis        8) 30-gitlab-kubeadm     12) 50-harbor-provision

    [INPUT] Select a Terraform layer to REBUILD:
    ```

3. When selecting `11) Rebuild Layer via Ansible`.

    ```text
    [INPUT] Please select an action: 11
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) inventory-10-vault-core.yaml         6) inventory-20-harbor-postgres.yaml
    2) inventory-20-gitlab-minio.yaml       7) inventory-20-harbor-redis.yaml
    3) inventory-20-gitlab-postgres.yaml    8) inventory-30-gitlab-kubeadm.yaml
    4) inventory-20-gitlab-redis.yaml       9) inventory-30-harbor-microk8s.yaml
    5) inventory-20-harbor-minio.yaml      10) Back to Main Menu

    [INPUT] Select a Cluster Inventory to run its Playbook:
    ```

**The following provides the usage instructions for `entry.sh`.**

## Section 1. Environmental Setup

### A. Required. KVM / QEMU

The QEMU/KVM environment can be automatically installed via option `6` in `entry.sh`. Note that this has currently only been tested on Ubuntu 24 and RHEL 10. Alternatively, relevant resources can be referenced to configure the KVM and QEMU environment according to the platform of the development machine.

### B. Option 1. Install IaC tools on Native

1. **Install HashiCorp Toolkit - Terraform and Packer**

    Subsequently, execute `entry.sh` in the project root directory and select option `7` _"Setup Core IaC Tools for Native"_ to install Terraform, Packer, and Ansible. Official installation instructions can be referenced:

    > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_  
    > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_  
    > _Reference: [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)_

    ```text
    ...
    [INPUT] Please select an action: 7
    [STEP] Verifying Core IaC Tools (HashiCorp/Ansible)...
    [STEP] Setting up core IaC tools...
    [TASK] Installing OS-specific base packages for RHEL...
    ...
    [TASK] Installing Ansible Core using pip...
    ...
    [INFO] Installing HashiCorp Toolkits (Terraform, Packer, Vault)...
    [TASK] Installing terraform...
    ...
    [TASK] Installing packer...
    ...
    [TASK] Installing vault...
    ...
    [TASK] Installing to /usr/local/bin/vault
    [INFO] Verifying installed tools...
    [STEP] Verifying Core IaC Tools (HashiCorp/Ansible)...
    [INFO] HashiCorp Packer: Installed
    [INFO] HashiCorp Terraform: Installed
    [INFO] HashiCorp Vault: Installed
    [INFO] Red Hat Ansible: Installed
    [OK] Core IaC tools setup and verification completed.
    ```

2. To confirm that Podman / Docker has been correctly installed, select the corresponding installation method by referring to the following URLs based on the operating system of the development device.

    > _Reference: [Podman Installation](https://podman.io/getting-started/installation)_  
    > _Reference: [Docker Installation](https://docs.docker.com/get-docker/)_

3. Taking Podman as an example, after Podman installation is complete, switch to the project root directory:
    1. The default memlock limit (`ulimit -l`) is typically low, which causes the mlock system call of HashiCorp Vault to fail. Additionally, in general Rootless Podman scenarios, it is merely mapped via `uid` to an ordinary user on the Host and directly inherits permission restrictions. To resolve this issue, execute the following commands to modify:

        ```shell
        sudo tee -a /etc/security/limits.conf <<EOT
        ${USER}    soft    memlock    unlimited
        ${USER}    hard    memlock    unlimited
        EOT
        ```

        This allows the Vault process within the user namespace to truly lock memory. The modifications require a reboot to take effect, in order to prevent sensitive data from being swapped out to unencrypted swap space.

    2. If this is the first time using, execute:

        ```shell
        podman compose up --build
        ```

    3. After the container is established, execute the following command to start it:

        ```shell
        podman compose up -d
        ```

    4. The current default setting is `DEBIAN_FRONTEND=noninteractive`. If entry into the container is required for modification or inspection, the following can be executed:

        ```shell
        podman exec -it iac-controller-base bash
        ```

        where `iac-controller-base` is the root container name for this project.

    5. The default container output after executing `podman compose --profile all up -d` and `podman ps -a` resembles the following:

        ```text
        CONTAINER ID  IMAGE                                            COMMAND               CREATED         STATUS                   PORTS       NAMES
        61be68ae276e  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  15 minutes ago  Up 15 minutes (healthy)  8200/tcp    iac-vault-server
        79b918f440f1  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-base
        0a4eb3495697  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-packer
        482f58b67295  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-terraform
        aa8d17213095  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-ansible
        ```

> [!CAUTION]
> **Data Loss Warning**
>
> When switching between the Podman container and Native environments, all Libvirt resources established by Terraform will be **automatically deleted** to avoid permission and context conflicts with the Libvirt UNIX socket.

### C. Miscellaneous

- **Recommended VSCode Plugins:** Primarily provide support for related syntax highlighting only:
    1. Ansible language support extension. [Marketplace Link of Ansible](https://marketplace.visualstudio.com/items?itemName=redhat.ansible)

        ```shell
        code --install-extension redhat.ansible
        ```

    2. HCL language support extension for Terraform. [Marketplace Link of HashiCorp HCL](https://marketplace.visualstudio.com/items?itemName=HashiCorp.HCL)

        ```shell
        code --install-extension HashiCorp.HCL
        ```

    3. Packer tool extension. [Marketplace Link of Packer Powertools](https://marketplace.visualstudio.com/items?itemName=szTheory.vscode-packer-powertools)

        ```shell
        code --install-extension szTheory.vscode-packer-powertools
        ```

## Section 2. Configuration

### Step A. Project Overview

> [!IMPORTANT]
> To ensure that this repo can execute smoothly, it is essential to complete the initialization settings in the following order.

0. **Environment Variables File:** `entry.sh` will automatically generate a `.env` environment variables file, primarily for use by other shell scripts. This can be ignored.

1. **Generate SSH Key:** During the execution of Terraform and Ansible, the SSH key is primarily used to allow services to log in to virtual machines for automated configuration. Executing option `5` _"Generate SSH Key"_ in `./entry.sh` will generate an SSH key, with the default name `id_ed25519_on-premise-gitlab-deployment`. The public and private keys generated in this step will be stored in the `~/.ssh/` directory.

2. **Switch Environment:** Option `13` in `./entry.sh` can be used to switch between _"Container"_ and _"Native"_ environments

    This repo uses Podman as the container runtime. The reason for avoiding Docker is primarily to prevent SELinux permission conflict issues. On systems with SELinux enabled (such as Fedora, RHEL, CentOS Stream, etc.), Docker containers execute by default in the `container_t` SELinux domain. Even after correctly mounting `/var/run/libvirt/libvirt-sock`, the SELinux policy will still prohibit `container_t` from connecting to the UNIX socket of `virt_var_run_t`, resulting in **Permission denied** errors from the Terraform libvirt provider or `virsh`, even if file permissions include `0770` and the `libvirt` group has been correctly configured.

    In contrast, the process context (`task_struct`) of **rootless Podman** is typically the user's `unconfined_t` or a similar SELinux type, without being forcibly applied to `container_t`. Therefore, provided the user has been added to the `libvirt` group, connection to the `libvirt` socket can proceed smoothly without additional SELinux policy adjustments. If the user environment mandates the use of Docker, options include disabling SELinux (not recommended), creating a custom SELinux module, or using TCP connections to `libvirtd` (though with lower security)

### Step B. Set up Variables

#### **Step B.0. Examine the Permissions of Libvirt**

> [!NOTE]
> Issues with Libvirt file permission settings can directly affect the execution permissions of the [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest). Therefore, some permission checks need to be performed first.

1. Ensure that the user account has been added to the `libvirt` group.

    ```shell
    sudo usermod -aG libvirt $(whoami)
    ```

    After completion, a full logout and login is required, or a reboot. This ensures that the group change takes effect in the shell session.

2. Modify the `libvirtd` configuration file to explicitly specify that the `libvirt` group manages the socket.

    ```shell
    # If vim is preferred
    sudo vim /etc/libvirt/libvirtd.conf

    # If nano is preferred
    sudo nano /etc/libvirt/libvirtd.conf
    ```

    Locate the following two lines and remove the leading `#` to uncomment them.

    ```toml
    unix_sock_group = "libvirt"
    # ...
    unix_sock_rw_perms = "0770"
    ```

3. Override the systemd socket unit settings, as systemd socket settings take precedence over `libvirtd.conf`.
    1. Execute the following command to open the nano editor.

        ```shell
        sudo systemctl edit libvirtd.socket
        ```

    2. Paste the following content in the editor, ensuring it is placed above the line `### Edits below this comment will be discarded` to prevent the configuration file from becoming invalid.

        ```toml
        [Socket]
        SocketGroup=libvirt
        SocketMode=0770
        ```

        After completion, press `Ctrl+O` to save and `Ctrl+X` to exit.

4. Restart the services in the correct order to apply all settings.
    1. Reload the `systemd` configuration:

        ```shell
        sudo systemctl daemon-reload
        ```

    2. Stop all `libvirtd`-related services to ensure a clean state:

        ```shell
        sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
        ```

    3. Disable `libvirtd.service` to fully delegate management to Socket Activation:

        ```shell
        sudo systemctl disable libvirtd.service
        ```

    4. Restart `libvirtd.socket`.

        ```shell
        sudo systemctl restart libvirtd.socket
        ```

5. Verify.
    1. Check the socket permissions: the output should show the group as `libvirt` and permissions as `srwxrwx---`.

        ```shell
        ls -la /var/run/libvirt/libvirt-sock
        ```

    2. Execute the `virsh` command as a **non-root** user.

        ```shell
        virsh list --all
        ```

        If the command executes successfully and lists virtual machines (even if the list is empty), all necessary permissions have been correctly configured.

#### **Step B.1. Prepare GitHub Credentials for Self-Management**

> [!NOTE]
> This project uses the [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) by default to manage the repository. Therefore, a Fine-grained Personal Access Token must be configured. If the cloned repository is not managed using Terraform GitHub Integration, the `terraform/layers/90-github-meta` layer can be skipped or deleted, and subsequent executions will not be affected.

1. Navigate to [GitHub Developer Settings](https://github.com/settings/personal-access-tokens) to apply for a Fine-grained Personal Access Token.
2. Click the `Generate new token` button on the top right of the page and set the token name, expiration period, and repository access scope.
3. In the Permissions section, select the following permissions:

    | Permission                     | Access Level   | Description                               |
    | ------------------------------ | -------------- | ----------------------------------------- |
    | Metadata                       | Read-only      | Mandatory                                 |
    | Administration                 | Read and Write | For modifying Repo settings and Ruleset   |
    | Contents                       | Read and Write | For reading Ref and Git information       |
    | Repository security advisories | Read and Write | For managing security advisories          |
    | Dependabot alerts              | Read and Write | For managing dependency alert             |
    | Secrets                        | Read and Write | (Optional) for managing Actions Secrets   |
    | Variables                      | Read and Write | (Optional) for managing Actions Variables |
    | Webhooks                       | Read and Write | (Optional) for managing Webhooks          |

4. Click `Generate token` and copy the generated token for use in the next step.

#### **Step B.2. Create Confidential Variable File for HashiCorp Vault**

> [!IMPORTANT]
> **All confidential data is integrated into HashiCorp Vault and divided into Development mode and Production mode. The Vault used by default in this repo employs HTTPS transmission with certificates from a Self-signed CA. Follow the steps below for correct configuration.**

0. **The Development Vault must be created before the Production Vault can be established. The Dev Vault is used only for creating the Prod Vault and Packer Images, after which all sensitive project data is managed by the Prod Vault.**

1. First, execute `entry.sh` and select option `1` to generate the files required for TLS handshake. When creating the Self-signed CA, some fields can be left blank. If regeneration of TLS files is needed, execute option `1` again.

2. Switch to the project root directory and execute the following command to start the Development mode Vault server. This repo defaults to running in side-car mode within the container:

    ```shell
    podman compose up -d iac-vault-server
    ```

    After starting the server, the Dev Vault will generate `vault.db` and Raft-related files in the `vault/data/` path. If recreation of the Dev Vault is required, all files in `vault/data/` must be manually deleted.

    Open a new terminal window or tab for subsequent operations to avoid contamination of environment variables in the shell session.

3. After completing the previous steps, execute `entry.sh` and select option 2 to initialize the Dev Vault. This process will also automatically perform Unseal.

4. Next, manually modify the following variables used by the project. Passwords must be replaced with unique content to ensure security.
    - **It is strongly recommended to clear sensitive variables from Shell History after executing any `vault kv put` command to prevent leakage. See Note 0 below for details.**

    - **For Development Vault**
        - The following variables are used to create the production HashiCorp Vault in Packer and Terraform Layer `10`.
            - `github_pat`: The GitHub Personal Access Token obtained in the previous step.
            - `ssh_username`, `ssh_password`: SSH username and password.
            - `vm_username`, `vm_password`: VM username and password.
            - `ssh_public_key_path`, `ssh_private_key_path`: Paths to the SSH public and private keys located on the host.

        ```shell
        export VAULT_ADDR="https://127.0.0.1:8200"
        export VAULT_CACERT="${PWD}/vault/tls/ca.pem"
        export VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt)
        vault secrets enable -path=secret kv-v2
        ```

        ```shell
        vault kv put \
            secret/on-premise-gitlab-deployment/variables \
            github_pat="your-github-personal-access-token" \
            ssh_username="some-user-name-for-ssh" \
            ssh_password="some-user-password-for-ssh" \
            ssh_password_hash=$(echo -n "$ssh_password" | mkpasswd -m sha-512 -P 0) \
            vm_username="some-user-name-for-vm" \
            vm_password="some-user-password-for-vm" \
            ssh_public_key_path="~/.ssh/some-ssh-key-name.pub" \
            ssh_private_key_path="~/.ssh/some-ssh-key-name"
        ```

        If `90-github-meta` is not used to manage GitHub repository settings, the `github_pat` secret can be deleted.

    - **For Production Vault**
        - The following variables are used to establish the Terraform Layer for Patroni / Sentinel / MinIO (S3) / Harbor / GitLab clusters.
            - `ssh_username`, `ssh_password`: SSH login credentials.
            - `vm_username`, `vm_password`: Virtual machine login credentials.
            - `ssh_public_key_path`, `ssh_private_key_path`: Paths to the SSH public and private keys on the host machine.
            - `pg_superuser_password`: Password for the PostgreSQL superuser (`postgres`). Used for initializing the database (`initdb`), Patroni management operations, and manual database maintenance.
            - `pg_replication_password`: Password for the Streaming Replication user. This is the password used by Patroni when creating standby nodes, allowing the standby to connect to the primary for WAL synchronization.
            - `pg_vrrp_secret`: VRRP authentication key for Keepalived nodes. Primarily ensures that only authorized nodes participate in Virtual IP (VIP) election and failover, preventing malicious interference on the local network.
            - `redis_requirepass`: Authentication password for Redis clients. Any client connecting to Redis, such as GitLab or Harbor, must use this password via the `AUTH` command to access data.
            - `redis_masterauth`: Authentication password used by Redis replicas when connecting to the master for synchronization. During failover, new replicas use this password to handshake with the node promoted to master. Although Redis allows different passwords, it is typically set the same as `redis_requirepass` to avoid replication failure after failover in Sentinel + HA scenarios.
            - `redis_vrrp_secret`: VRRP authentication key for the Redis load balancing layer (HAProxy/Keepalived), with the same principle as `pg_vrrp_secret`.
            - `minio_root_user`: MinIO root administrator account (formerly known as Access Key), primarily used for logging into the MinIO Console or managing buckets and policies via the MinIO Client (`mc`).
            - `minio_root_password`: MinIO root administrator password (formerly known as Secret Key).
            - `minio_vrrp_secret`: VRRP authentication key for the MinIO load balancing layer (HAProxy/Keepalived), with the same principle as `pg_vrrp_secret`.
            - `vault_haproxy_stats_pass`: Login password for the HAProxy Stats Dashboard, primarily used to protect the Web UI (typically on port `8404`), displaying backend server health status and traffic statistics.
            - `vault_keepalived_auth_pass`: VRRP authentication key for the Vault cluster load balancer, used to protect the Vault service VIP.
            - `harbor_admin_password`: Default password for the Harbor Web Portal `admin` account, used for initial login to Harbor to create projects and configure robot accounts.
            - `harbor_pg_db_password`: Dedicated password for Harbor services (Core, Notary, Clair) to connect to PostgreSQL. This is an application-level password (typically corresponding to DB user `harbor`), with lower privileges than `pg_superuser_password`.

        ```shell
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
        export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)
        vault secrets enable -path=secret kv-v2
        ```

        ```shell
        vault kv put secret/on-premise-gitlab-deployment/variables \
            ssh_username="some-username-for-ssh-for-production-mode" \
            ssh_password="some-password-for-ssh-for-production-mode" \
            ssh_password_hash='$some-password-for-ssh-for-production-mode' \
            ssh_public_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment.pub" \
            ssh_private_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment" \
            vm_username="some-username-for-vm-for-production-mode" \
            vm_password="some-password-for-vm-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/infrastructure \
            vault_haproxy_stats_pass="some-password-for-vault-haproxy-stats-pass-for-production-mode" \
            vault_keepalived_auth_pass="some-password-for-vault-keepalived-auth-pass-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/gitlab/databases \
            pg_superuser_password="some-password-for-gitlab-pg-superuser-for-production-mode" \
            pg_replication_password="some-password-for-gitlab-pg-replication-for-production-mode" \
            pg_vrrp_secret="some-password-for-gitlab-pg-vrrp-for-production-mode" \
            redis_requirepass="some-password-for-gitlab-redis-requirepass-for-production-mode" \
            redis_masterauth="some-password-for-gitlab-redis-masterauth-for-production-mode" \
            redis_vrrp_secret="some-password-for-gitlab-redis-vrrp-secret-for-production-mode" \
            minio_root_password="some-password-for-gitlab-minio-root-password-for-production-mode" \
            minio_vrrp_secret="some-password-for-gitlab-minio-vrrp-secret-for-production-mode" \
            minio_root_user="some-username-for-gitlab-minio-root-user-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/harbor/databases \
            pg_superuser_password="some-password-for-harbor-pg-superuser-for-production-mode" \
            pg_replication_password="some-password-for-harbor-pg-replication-for-production-mode" \
            pg_vrrp_secret="some-password-for-harbor-pg-vrrp-for-production-mode" \
            redis_requirepass="some-password-for-harbor-redis-requirepass-for-production-mode" \
            redis_masterauth="some-password-for-harbor-redis-masterauth-for-production-mode" \
            redis_vrrp_secret="some-password-for-harbor-redis-vrrp-secret-for-production-mode" \
            minio_root_password="some-password-for-harbor-minio-root-password-for-production-mode" \
            minio_vrrp_secret="some-password-for-harbor-minio-vrrp-secret-for-production-mode" \
            minio_root_user="some-username-for-harbor-minio-root-user-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/harbor/app \
            harbor_admin_password="some-password-for-harbor-admin-password-for-production-mode" \
            harbor_pg_db_password="some-password-for-harbor-pg-db-password-for-production-mode"
        ```

    - **Note 0. Security Notice**： After executing the `vault kv put` command, it is strongly recommended to clear the shell history to prevent leakage of sensitive information.

    - **Note 1. How to retrieve secrets**
        1. Use the following command to retrieve confidential information from Vault. For example, to retrieve the PostgreSQL superuser password:

            ```shell
            export VAULT_ADDR="https://172.16.136.250:443"
            export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
            export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)
            vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases
            ```

        2. To avoid leakage of confidential information, the following can be used:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        3. To keep the shell environment clean, a one-line command can be used:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt" VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        The operation method is the same for the Development Vault and other secrets.

    - **Note 2:**

        `ssh_username` and `ssh_password` are the username and password used for logging into virtual machines. `ssh_password_hash` is the hashed password required for automatic installation by cloud-init, which must be generated using the original string of `ssh_password`. For example, if the password is `HelloWorld@k8s`, the following command is used to generate the corresponding hash:

        ```shell
        mkpasswd -m sha-512 HelloWorld@k8s
        ```

        - If the `mkpasswd` command not found error appears, the `whois` package may be missing.
        - The `ssh_public_key_path` must be changed to the name of the previously generated **public key**. The public key file name is in the `*.pub` format.

    - **Note 3:**

        The current SSH identity variables (`ssh_`) are primarily used in Packer's single-use scenarios, while the VM identity variables (`vm_`) are used by Terraform during VM cloning. In principle, both can be set to the same values. If different names are required for different VMs, the objects and related code in the HCL can be directly modified. Typically, the `ansible_runner.vm_credentials` variable and its related passing methods are modified, followed by iteration using a `for_each` loop. However, this approach increases complexity. Therefore, if there are no other requirements, it is recommended to keep the SSH and VM identity variables identical.

5. In this repo, Vault requires an unseal operation after every startup. The following methods can be used:
    - Option `3` in `entry.sh` performs Unseal for Development mode Vault. It is executed using the Shell Script `vault_dev_unseal_handler()`.
    - Option `4` in `entry.sh` performs Unseal for Production mode Vault. It is operated using the Ansible Playbook `90-operation-vault-unseal.yaml`.

    Alternatively, using containers as described in B.1-2 is more convenient.

#### **Step B.3. Create Variable File for Terraform:**

> [!NOTE]
> These are the variable files to establish clusters.

1. Rename `terraform/layers/*/terraform.tfvars.example` to `terraform/layers/*/terraform.tfvars` using the following command:

    ```shell
    for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
    ```

    1. In HA mode,
        - Services such as Vault (Production mode), Patroni including etcd, Sentinel, Microk8s (Harbor), and Kubeadm Master (GitLab) must comply with the `n%2 != 0` configuration.
        - MinIO Distributed must comply with the `n%4 == 0` configuration.

    2. The IPs assigned during node creation must correspond to the host-only network segment.

2. This project currently defaults to using Ubuntu Server 24.04.3 LTS (Noble) as the Guest OS.
    - The latest version can be obtained from <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/>.
    - The version tested for this project can be obtained from <https://old-releases.ubuntu.com/releases/noble/>.
    - After selecting the version, verify the checksum.
        - Latest Noble version: <https://releases.ubuntu.com/noble/SHA256SUMS>
        - "Noble-old-release" version: <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

    If time permits in the future, support for other Linux Guest OS such as Fedora 43 or RHEL 10 will be added.

3. **Independent Testing and Development**: The following can be used.
    - Menu option `9) Build Packer Base Image` to create a Packer image.
    - Menu option `10) Provision Terraform Layer` for independent testing or rebuilding specific Terraform module layers (such as Harbor or Postgres, etc.).

        Occasionally, when rebuilding Harbor during the Service Provision phase of Layer 50, a `module.harbor_config.harbor_garbage_collection.gc` Resource not found error may occur. This can be resolved by removing `terraform.tfstate` and `terraform.tfstate.backup` from `terraform/layers/50-harbor-platform` and re-executing `terraform apply`.

    If repeated testing of Ansible Playbooks on existing machines is required without rebuilding virtual machines, `11) Rebuild Layer via Ansible` can be used.

4. **Resource Cleanup**:
    - **`14) Purge All Libvirt Resources`** is primarily used in scenarios where virtualization resources need to be cleaned while preserving project state.

        This option executes `libvirt_resource_purger "all"`, which **deletes only** all guest VMs, networks, and storage pools created by this project, but **preserves** the Packer output images and Terraform local state files.

    - **`15) Purge All Packer and Terraform Resources`** is primarily used to clear all artifacts.

        This option deletes **all** Packer output images and **all** Terraform Layer local states, returning the Packer and Terraform states to nearly pristine condition.

#### **Step B.4. Provision the GitHub Repository with Terraform:**

> [!NOTE]
> If this repository is cloned for personal use, this step (B.4) can be executed by selecting `90-github-meta` via `10) Provision Terraform Layer`. The following content is provided only as a reference for imperative manual procedures.

1. Use the Shell Bridge Pattern to inject the Token from Vault. Execute in the project root directory to ensure that `${PWD}` points to the correct Vault credential path.

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/variables)
    ```

2. Since the repository already exists, import is required before the first execution of the governance layer.

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. Initialization and Import
    - **Scenario A (Existing Repo):** If managing an existing repository (such as this project), import **must** be performed first.
    - **Scenario B (New Repo):** If creating a new repository from scratch, the import step can be skipped.

    ```shell
    terraform init
    terraform import github_repository.this on-premise-gitlab-deployment
    ```

4. Apply Ruleset: It is recommended to first execute `terraform plan` to preview changes before apply.

    ```shell
    terraform apply -auto-approve
    ```

    The output resembles the following:

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

#### **Step B.5. Export Certs of Services:**

Exporting service certificates allows direct browsing of the following services from the Host side without encountering certificate errors.

- Prod Vault: `https://vault.iac.local`
- Harbor: `https://harbor.iac.local`
- Harbor MinIO Console: `https://s3.harbor.iac.local`
- GitLab: `https://gitlab.iac.local` (**WIP**)
- GitLab MinIO Console: `https://s3.gitlab.iac.local` (**WIP**)

This requires performing two tasks in the following sequence:

1. Handle DNS resolution in `/etc/hosts` by adding the following content (the default for this repo) to the host's `/etc/hosts`. Note that this must be adjusted according to the actual IPs output by Terraform.

    ```text
    172.16.134.250  gitlab.iac.local
    172.16.135.250  harbor.iac.local notary.harbor.iac.local
    172.16.136.250  vault.iac.local
    172.16.139.250  s3.harbor.iac.local
    172.16.142.250  s3.gitlab.iac.local
    ```

2. Import the Vault Root CA to allow the Host to trust the TLS certificates of all services.
    1. Layer 10 Vault must be created first to generate `vault-root-ca.crt`. This file will be stored in `terraform/layers/10-vault-core/tls/`.

    2. Import the CA into the system trust chain.
        - RHEL / CentOS：

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /etc/pki/ca-trust/source/anchors/
            sudo update-ca-trust
            ```

        - Ubuntu / Debian：

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /usr/local/share/ca-certificates/
            sudo update-ca-certificates
            ```

    3. Access MinIO from the host for a simple test to verify the Trust Store.

        ```shell
        curl -I https://s3.harbor.iac.local:9000/minio/health/live
        ```

        If the output shows `HTTP/1.1 200 OK`, the Trust Store has been correctly configured.

    4. Access Harbor from the host to verify the Trust Store.

        ```shell
        curl -vI https://harbor.iac.local
        ```

        If `SSL certificate verify ok` and `HTTP/2 200` are displayed, the complete PKI Chain—from certificate issuance by Vault, signing via cert-manager, deployment through Ingress, to trust by the host—has been successfully established.

## Section 3. System Architecture

This repo utilizes Packer, Terraform, and Ansible tools. Based on the immutable infrastructure paradigm, it implements an automated workflow from creating virtual machine images to provisioning a complete Kubernetes cluster.

### A. Deployment Workflow

1. **Core Bootstrap Workflow**: The Development Vault is used to store initial secrets, followed by the creation of the Production Vault.

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant Entry as entry.sh
        participant DevVault as Dev Vault<br>(Local)
        participant TF as Terraform<br>(Layer 10)
        participant Libvirt
        participant Ansible
        participant ProdVault as Prod Vault<br>(Layer 10)

        %% Step 1: Bootstrap
        Note over User, DevVault: [Bootstrap Phase]
        User->>Entry: [DEV] Initialize Dev Vault
        Entry->>DevVault: Init & Unseal
        Entry->>DevVault: Enable KV Engine (secret/)
        User->>DevVault: Write Initial Secrets (SSH Keys, Root Pass)

        %% Step 2: Infrastructure
        Note over User, ProdVault: [Layer 10: Infrastructure]
        User->>Entry: Provision Layer 10
        Entry->>TF: Apply (Stage 1)
        TF->>DevVault: Read SSH Keys/Creds
        TF->>Libvirt: Create Vault VMs (Active/Standby)
        TF->>Ansible: Trigger Provisioning
        Ansible->>ProdVault: Install Vault Binary & Config

        %% Step 3: Operation
        Note over User, ProdVault: [Layer 10: Operation]
        User->>Entry: [PROD] Unseal Production Vault
        Entry->>Ansible: Run Playbook (90-operation-unseal)
        Ansible->>ProdVault: Init (if new) & Unseal
        Ansible-->>Entry: Return Root Token (Saved to Artifacts)

        %% Step 4: Configuration
        Note over User, ProdVault: [Layer 10: Configuration]
        Entry->>TF: Apply (Stage 2 - Vault Provider)
        TF->>ProdVault: Enable PKI Engine (Root CA)
        TF->>ProdVault: Configure Roles (postgres, redis, minio)
        TF->>ProdVault: Enable AppRole Auth
    ```

2. **Data Services and PKI**: Automated deployment of data services. MinIO is used as an example, while Postgres and Redis are similar.

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant TF as Terraform<br>(Layer 20)
        participant ProdVault as Prod Vault<br>(Layer 10)
        participant Libvirt
        participant Ansible
        participant Agent as Vault Agent<br>(On Guest)
        participant Service as MinIO Service

        Note over User, Service: [Layer 20: Provisioning MinIO]

        %% Terraform Phase
        User->>TF: Apply Layer 20 (MinIO)
        TF->>ProdVault: 1. Create AppRole 'harbor-minio'
        ProdVault-->>TF: Return RoleID & SecretID
        TF->>Libvirt: 2. Create MinIO VMs & LBs

        %% Ansible Phase
        TF->>Ansible: 3. Trigger Playbook (Pass AppRole Creds)

        Ansible->>Agent: 3a. Install Vault Agent
        Ansible->>Agent: 3b. Write RoleID/SecretID to /etc/vault.d/approle/
        Ansible->>Agent: 3c. Configure Agent Templates (public.crt, private.key)
        Ansible->>Agent: 3d. Start Vault Agent Service

        %% Runtime Phase
        Agent->>ProdVault: 4. Auth (AppRole Login)
        ProdVault-->>Agent: Return Client Token
        Agent->>ProdVault: 5. Request Cert (pki/prod/issue/minio-role)
        ProdVault-->>Agent: Return Signed Cert & Key

        Agent->>Service: 6. Render Certs to /etc/minio/certs/
        Agent->>Service: 7. Restart/Reload MinIO Service

        Service->>Service: 8. Start with TLS (HTTPS)

        %% Client Config
        Ansible->>Service: 9. Trust CA & Configure 'mc' Client
    ```

### B. Toolchain Roles and Responsibilities

> The cluster setups in this project reference the following articles:

> 1. Bibin Wilson, B. (2025). _How To Setup Kubernetes Cluster Using Kubeadm._ devopscube. <https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests>
> 2. Aditi Sangave (2025). _How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._ Velotio Tech Blog. <https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft>
> 3. Dickson Gathima (2025). _Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._ Medium. <https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f>
> 4. Deniz TÜRKMEN (2025). _Redis Cluster Provisioning — Fully Automated with Ansible._ Medium. <https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75>

> [!TIP]
> Cluster setup steps that strictly follow official documentation are not included in the list above.

_**(To be continued...)**_
