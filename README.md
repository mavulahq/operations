# MAVULA Operations

`@mavula/operations` contains local and deployment infrastructure for MAVULA.

Legacy alias: `finfra`.

## Responsibilities

- Docker image and local PostgreSQL/Redis lifecycle scripts.
- Kubernetes runtime configuration for `identity-access`, `ledger-core`, and `workbench`.
- Kubernetes manifests and Minikube development environment.
- Deployment, health-check, database backup and schema migration scripts.
- Terraform starter infrastructure.

## Development

```bash
pnpm --filter @mavula/operations dev:services:up
MINIKUBE_PROFILE=<existing-profile> pnpm --filter @mavula/operations minikube:deploy
MINIKUBE_PROFILE=<existing-profile> pnpm --filter @mavula/operations minikube:status
pnpm --filter @mavula/operations tf:plan
```

Local runtime secrets are loaded from the untracked root `.env`. Minikube
reuses existing `mavula/*:<tag>` images unless
`MINIKUBE_REBUILD_IMAGES=true` is set explicitly.

License: Apache-2.0.
