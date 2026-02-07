# Service Catalog Definition

## Overview

The **Service Catalog** serves as the Single Source of Truth (SSoT) for the entire infrastructure's security and identity architecture. It defines the identity, runtime environment, lifecycle stage, and dependency chain for every service in the ecosystem.

This catalog drives the automated generation of:

1. **Vault PKI Roles**: For both internal components and external dependencies.
2. **Security Policies**: TTL (Time-To-Live) strategies based on lifecycle stages.
3. **Identity Metadata**: Organizational Unit (OU) injection into certificates for auditability.

## Schema Reference

The catalog is structured as a map of service objects. The following fields define the "DNA" of each service:

| Field              | Description                                                                                    | Purpose (Architectural Dimension)                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **`runtime`**      | The technology stack hosting the service (e.g., `kubeadm`, `microk8s`, `docker`, `baremetal`). | **Service Polymorphism**: Allows the same service identity to run across different infrastructures.     |
| **`stage`**        | The lifecycle environment (e.g., `production`, `dev`, `staging`).                              | **Policy-as-Code**: Determines certificate TTL (e.g., Prod = 1 Year, Dev = 1 Day).                      |
| **`components`**   | Internal parts of the service requiring frontend/ingress certificates.                         | **Ingress/Access Control**: Generates roles like `gitlab-frontend-role`.                                |
| **`dependencies`** | External backing services required for operation (e.g., Postgres, Redis).                      | **Dependency Composition**: Defines the vertical stack and generates roles like `gitlab-postgres-role`. |

---

## Registered Services

The following services are currently defined in the catalog:

### 1. GitLab Helm Chart

- **Identity**: `gitlab`
- **Context**: Production workload running on a **Kubeadm** cluster.
- **Access Points**:
    - Subdomains: `gitlab`, `kas`, `minio`

- **Dependencies**:
    - Relies on baremetal infrastructure for persistence.
    - **Postgres** (Runtime: `baremetal`)
    - **Redis** (Runtime: `baremetal`)
    - **MinIO** (Runtime: `baremetal`)

### 2. Harbor (Production)

- **Identity**: `harbor`
- **Context**: Production workload running on a **MicroK8s** cluster.
- **Access Points**:
    - Subdomains: `harbor`, `notary.harbor`

- **Dependencies**:
    - Relies on baremetal infrastructure for persistence.
    - **Postgres** (Runtime: `baremetal`)
    - **Redis** (Runtime: `baremetal`)
    - **MinIO** (Runtime: `baremetal`)

### 3. Harbor (Development)

- **Identity**: `dev-harbor`
- **Context**: Development workload running on a **Docker** host.
- **Access Points**:
    - Subdomains: `dev-harbor`, `notary.dev-harbor`

- **Dependencies**:
    - **None** (Standalone). This service uses internal/embedded databases. No external Vault roles are generated for backing services.

## Automated Vault Behavior

Based on the configurations above, Layer 10 automatically provisions the following resources:

### Role Naming Convention

Vault Roles are generated using a strict naming pattern to ensure identity persistence across infrastructure migrations:

- **Format**: `${service}-${component}-role`
- **Example**: `gitlab-postgres-role` (Note: `kubeadm` or `baremetal` is excluded from the name).

### Certificate Metadata (OU Injection)

All certificates issued via these roles will include specific metadata in the **Organizational Unit (OU)** field for auditing:

- **GitLab Certs**: `OU=production`, `OU=kubeadm`
- **Dev-Harbor Certs**: `OU=development`, `OU=docker`

### TTL Policy Assignment

| Service Environment      | Max TTL | Default TTL |
| ------------------------ | ------- | ----------- |
| **Production Services**  | 1 Year  | 30 Days     |
| **Staging Services**     | 30 Days | 7 Days      |
| **Development Services** | 7 Days  | 1 Day       |
| **Default**              | 1 Day   | 1 Hour      |
