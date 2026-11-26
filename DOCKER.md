# Docker

Balance uses Docker Compose for local development. Production deployment uses
the production image and Kamal configuration; the local production profile is
only an image-validation path.

## Requirements

- Docker Engine or Docker Desktop with Compose
- An OpenAI-compatible provider when exercising AI features

## Development

Start the application from the repository root:

```sh
docker compose up --build
```

Open [http://localhost:8080](http://localhost:8080). The development container
bind-mounts the repository, prepares the databases, and runs Rails, Tailwind,
and Solid Queue through `bin/dev`.

Run Compose in the background and wait for health checks with:

```sh
docker compose up --build --detach --wait
```

Check the application and service state:

```sh
curl --fail http://localhost:8080/up
docker compose ps
docker compose logs web-dev
```

Open a Rails console with:

```sh
docker compose exec web-dev bin/rails console
```

## Configuration

Development works without an environment file. To override the database
password or AI provider, create one from the example:

```sh
cp .env.example .env
```

The default provider is an OpenAI-compatible LM Studio endpoint at
`http://host.docker.internal:1234/v1`. Never commit `.env`, credentials, API
keys, production data, or generated secrets.

## Services

`postgres` runs PostgreSQL 17 inside the Compose network. It is not published on
the host. `web-dev` exposes Rails at host port `8080` while Rails listens on
container port `3000`.

The named `postgres_data` volume preserves local data between restarts.

## Stopping and resetting

Stop containers while retaining data:

```sh
docker compose down
```

Delete containers and the local database volume only when intentionally
resetting all Docker-managed data:

```sh
docker compose down --volumes
```

## Production image validation

Copy `.env.example` to `.env` and set `RAILS_MASTER_KEY`, then run:

```sh
docker compose --profile prod up --build
```

This builds the root `Dockerfile` and serves it through Thruster at
`http://localhost:8080`. It does not configure a production host, TLS, backups,
monitoring, or external secrets and is not a deployment procedure.

## Troubleshooting

- If Rails is unhealthy, inspect `docker compose logs web-dev` and confirm the
  PostgreSQL health check passes.
- If the AI assistant cannot connect, verify the provider is listening and the
  `OPENAI_API_BASE` host is reachable from the container.
- If **Link bank** shows "Couldn't start bank linking", read the `Bank linking
  failed` line in `docker compose logs web-dev`. Inside the container,
  `connect.localhost` does not resolve, so set `BEERUS_API_URL` to a Beerus
  address the container can reach. Register
  `http://localhost:8080/bank_transactions` as a redirect URI with
  `beerus partner add`, or set `BEERUS_REDIRECT_URI` to a URI you registered.
- If port `8080` is occupied, stop the conflicting process or change the host
  side of the port mapping in `compose.yaml`.
- Registry DNS or timeout failures originate outside the application; confirm
  Docker networking before changing the image definitions.
