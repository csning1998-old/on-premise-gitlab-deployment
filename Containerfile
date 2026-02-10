# Stage 1: Get binaries
FROM docker.io/hashicorp/terraform:1.13.0 AS terraform
FROM docker.io/hashicorp/packer:1.14.1 AS packer
FROM docker.io/hashicorp/vault:1.20.2 AS vault
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install basic tools and Libvirt client
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client git curl jq ca-certificates \
    python3 python3-pip \
    libvirt-clients qemu-system-x86 qemu-utils \
    xorriso genisoimage \
    software-properties-common \
    && add-apt-repository --yes --update ppa:ansible/ansible \
    && apt-get install -y ansible \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set QEMU Bridge permissions
RUN mkdir -p /etc/qemu && \
    echo 'allow virbr0' > /etc/qemu/bridge.conf && \
    chmod u+r /etc/qemu/bridge.conf

# Copy binaries
COPY --from=terraform /bin/terraform /usr/local/bin/terraform
COPY --from=packer /bin/packer /usr/local/bin/packer
COPY --from=vault /bin/vault /usr/local/bin/vault

# User and Group Mapping
ARG HOST_UID
ARG HOST_GID
ARG USERNAME
ARG LIBVIRT_GID

RUN \
    # 1. Process the Libvirt Group: Ensure a group in the container has a GID equal to the Host's LIBVIRT_GID
    if ! getent group ${LIBVIRT_GID} > /dev/null 2>&1; then \
        groupadd -g ${LIBVIRT_GID} libvirt; \
    else \
        # If GID exists (e.g., occupied), rename it to libvirt for identification
        EXISTING_GROUP=$(getent group ${LIBVIRT_GID} | cut -d: -f1); \
        if [ "${EXISTING_GROUP}" != "libvirt" ]; then \
            groupmod -n libvirt ${EXISTING_GROUP}; \
        fi; \
    fi && \
    \
    # 2. Process the Primary Group of user
    if ! getent group ${HOST_GID} > /dev/null 2>&1; then \
        groupadd -g ${HOST_GID} ${USERNAME}; \
    else \
        EXISTING_GROUP=$(getent group ${HOST_GID} | cut -d: -f1); \
        if [ "${EXISTING_GROUP}" != "${USERNAME}" ]; then \
            groupmod -n ${USERNAME} ${EXISTING_GROUP}; \
        fi; \
    fi && \
    \
    # 3. Establish the user
    if ! getent passwd ${HOST_UID} > /dev/null 2>&1; then \
        useradd -u ${HOST_UID} -g ${HOST_GID} -m -s /bin/bash ${USERNAME}; \
    else \
        EXISTING_USER=$(getent passwd ${HOST_UID} | cut -d: -f1); \
        usermod -l ${USERNAME} -u ${HOST_UID} -g ${HOST_GID} -d /home/${USERNAME} -m ${EXISTING_USER}; \
    fi && \
    \
    # 4. Add user into Libvirt Group
    usermod -a -G libvirt ${USERNAME}

# Switch to the user and no longer using Root
USER ${USERNAME}

# Final container setup
WORKDIR /app
CMD ["/bin/bash"]
