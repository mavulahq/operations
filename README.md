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
requires an existing running profile and reuses images already present in that
profile. Image loading and rebuilding are disabled by default. Set
`MINIKUBE_LOAD_IMAGES=true` to load existing local images, or set both
`MINIKUBE_REBUILD_IMAGES=true` and an explicit immutable
`MINIKUBE_IMAGE_TAG` to rebuild them.

`ledger-core` uses separate runtime and migration credentials. Existing
databases without Prisma history are not adopted automatically; set
`LEDGER_CORE_ACCEPT_BASELINE=true` only for the verified one-time baseline
operation. Migration credentials are never injected into the runtime pod.

`legacy-connectors` also uses a dedicated schema and restricted runtime role.
Workbench executes it as a domain package; no separate deployment is created.
Workbench receipts and settlement processes use their own schemas and runtime
credentials. Schema migrations and role provisioning run with migration-only
credentials before the Workbench rollout.

Prometheus scraping for `ledger-core` and `workbench` uses dedicated bearer
tokens from Kubernetes secrets. API and metrics traffic still share the
service port, so token enforcement remains part of the application boundary.

License: Apache-2.0.
