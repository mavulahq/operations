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

`ledger-core` uses separate runtime and migration credentials. Existing
databases without Prisma history are not adopted automatically; set
`LEDGER_CORE_ACCEPT_BASELINE=true` only for the verified one-time baseline
operation. Migration credentials are never injected into the runtime pod.

`legacy-connectors` also uses a dedicated schema and restricted runtime role.
Workbench executes it as a domain package; no separate deployment is created.

License: Apache-2.0.
