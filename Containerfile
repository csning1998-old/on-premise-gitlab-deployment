# Stage 1. Base Image
FROM ubuntu:24.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Python optimization
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Define ARGS (Defaults can be overridden by compose.yml)
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG LIBVIRT_GID=999
ARG USERNAME=iac-user

# Stage 2: Install dependencies and tools
# Use /etc/os-release instead of installing lsb-release, use gnupg explicitly, and clean up in the same layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    jq \
    openssh-client \
    genisoimage \
    python3 \
    python3-pip \
    python3-venv \
    libvirt-clients \
    qemu-utils \
    qemu-system-x86 \
    ca-certificates \
    gnupg \
    # Setup HashiCorp Repo (Robust way using os-release)
    && . /etc/os-release \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" | tee /etc/apt/sources.list.d/hashicorp.list \
    # Install HashiCorp Tools
    && apt-get update && apt-get install -y --no-install-recommends \
    packer \
    terraform \
    vault \
    # Install Ansible
    && pip3 install ansible passlib --break-system-packages \
    && ansible-galaxy collection install \
        ansible.posix \
        community.general \
        community.docker \
        community.kubernetes \
        community.crypto \
        community.hashi_vault \
    # Cleanup to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 3: User permission configuration: Remove default ubuntu user (UID 1000) to allow reusing UID 1000
RUN userdel -r ubuntu || true && \
    # Create libvirt group matching Host GID (for socket permission)
    groupadd -g ${LIBVIRT_GID} libvirt-host && \
    # Create User matching Host UID/GID for 1:1 file mapping
    # Using --force on groupadd just in case of system group conflict
    groupadd -g ${HOST_GID} -f ${USERNAME} && \
    useradd -u ${HOST_UID} -g ${HOST_GID} -m -s /bin/bash ${USERNAME} && \
    usermod -aG libvirt-host ${USERNAME}

# Finalization
USER ${USERNAME}
WORKDIR /home/${USERNAME}
CMD ["/bin/bash"]
