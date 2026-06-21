# finfra

`finfra` contains the local and deployment infrastructure for Fluxo, the Banking as a Service (BaaS) platform by getfluxo.io.

## Responsibilities

- Docker image and local PostgreSQL/Redis lifecycle scripts.
- Kubernetes manifests and a complete Minikube development environment.
- Deployment, health-check, database backup, schema migration, and Terraform foundations.

## Development

Use Node.js `22.22.3`, pnpm `10.33.0`, Docker `24+`, and Kubernetes CLI `1.28+`. Run commands from the root of the `getfluxo` workspace:

```bash
pnpm --filter @getfluxo/finfra dev:services:up
pnpm --filter @getfluxo/finfra minikube:deploy
pnpm --filter @getfluxo/finfra minikube:status
pnpm --filter @getfluxo/finfra tf:plan
```

Minikube is the supported complete local cluster. Terraform remains a foundation and must be reviewed and completed before production use.

## Repository

The canonical workspace is `git@github.com:getfluxo-io/getfluxo.git`.

Copyright (c) 2026 getfluxo.io. Proprietary software. See `LICENSE`.
