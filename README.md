# MAVULA Operations

`@mavula/operations` contains local and deployment infrastructure for MAVULA.

Legacy alias: `finfra`.

## Responsibilities

- Docker image and local PostgreSQL/Redis lifecycle scripts.
- Kubernetes manifests and Minikube development environment.
- Deployment, health-check, database backup and schema migration scripts.
- Terraform starter infrastructure.

## Development

```bash
pnpm --filter @mavula/operations dev:services:up
pnpm --filter @mavula/operations minikube:deploy
pnpm --filter @mavula/operations minikube:status
pnpm --filter @mavula/operations tf:plan
```

License: Apache-2.0.
