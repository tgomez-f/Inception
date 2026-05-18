# Inception

*This project has been created as part of the 42 curriculum by tgomez-f.*

---

## Table of Contents

- [Description](#description)
- [Architecture](#architecture)
- [Design Choices](#design-choices)
  - [Virtual Machines vs Docker](#virtual-machines-vs-docker)
  - [Secrets vs Environment Variables](#secrets-vs-environment-variables)
  - [Docker Network vs Host Network](#docker-network-vs-host-network)
  - [Docker Volumes vs Bind Mounts](#docker-volumes-vs-bind-mounts)
- [Documentation](#documentation)
- [Resources](#resources)

---

## Description

**Inception** is a system administration project from the 42 curriculum. The goal is to build a small but complete web infrastructure using **Docker** and **Docker Compose**, running entirely inside a virtual machine.

The infrastructure hosts a **WordPress** website backed by a **MariaDB** database, exposed securely through an **NGINX** reverse proxy. Every service runs in its own dedicated container, built from a custom `Dockerfile` based on Debian Bullseye. No pre-built application images from Docker Hub are used.

---

## Architecture

```
                        Browser / Client
                               │
                               │ HTTPS port 443 (TLSv1.2 / TLSv1.3)
                               ▼
                     ┌─────────────────┐
                     │      NGINX      │  ← Only entry point into the infra
                     │    container    │    Terminates TLS, proxies PHP requests
                     └────────┬────────┘
                              │
                              │ FastCGI protocol (port 9000)
                              ▼
                     ┌─────────────────┐
                     │   WordPress     │  ← PHP-FPM application server
                     │   + PHP-FPM     │    No web server inside this container
                     │    container    │
                     └────────┬────────┘
                              │
                              │ MySQL protocol (port 3306)
                              ▼
                     ┌─────────────────┐
                     │    MariaDB      │  ← Relational database
                     │    container    │    Stores all WordPress content
                     └─────────────────┘

     ┌──────────────────────────────────────────────────────┐
     │               Docker bridge network: inception        │
     │   All inter-container traffic is isolated here        │
     └──────────────────────────────────────────────────────┘

     Persistent storage (named Docker volumes):
       wordpress_data  →  /home/tgomez-f/data/wordpress  (PHP files)
       mariadb_data    →  /home/tgomez-f/data/mariadb    (database files)
```

NGINX is the **only** container with a published port (443). WordPress and MariaDB are unreachable from outside the Docker network.

---

## Design Choices

### Virtual Machines vs Docker

Both technologies provide isolation, but at a fundamentally different level.

**A Virtual Machine:**
- Emulates a complete physical computer, including its own OS kernel, virtual CPU, RAM, and disk.
- Requires a **hypervisor** (e.g. VirtualBox, VMware) to manage the hardware emulation.
- Boots in minutes, consumes several gigabytes of RAM and disk per instance.
- Offers very strong isolation: each VM has a completely separate kernel.

**A Docker container:**
- Does **not** emulate hardware. It shares the host's Linux kernel directly.
- Uses two Linux kernel features: **namespaces** (each container has its own process tree, network, filesystem) and **cgroups** (CPU and RAM limits).
- Starts in milliseconds. A container image can be just a few megabytes.
- Isolation is lighter than a VM (shared kernel), but sufficient for separating services.

> **In this project:** Docker runs three isolated services on the same VM without the overhead of three separate virtual machines. Each container has its own filesystem and network identity, but remains lightweight and fast.

---

### Secrets vs Environment Variables

Both inject configuration into a container, but they serve different purposes.

**Environment variables** (`.env` file):
- Stored as plain text in the container's process environment.
- Visible via `docker inspect <container>`, in crash logs, and to any process inside the container.
- Appropriate for **non-sensitive** config: database name, domain name, usernames, site title.

**Docker secrets** (mounted at `/run/secrets/<name>`):
- Stored as files inside the container, never exposed in the environment or in `docker inspect`.
- Designed specifically for **sensitive data**: passwords, API keys, private keys.
- Read in bash via `$(cat /run/secrets/secret_name)` and in PHP via `file_get_contents('/run/secrets/secret_name')`.

> **In this project:** All passwords use Docker secrets. General config uses environment variables. No password is ever visible in plain text in the compose file or container environment.

---

### Docker Network vs Host Network

**Host network (`network_mode: host`, forbidden in this project):**
- The container shares the host machine's network stack directly.
- No isolation: the container can bind to any port on the host and see all interfaces.
- Simple, but fundamentally insecure.

**Docker bridge network (used in this project):**
- Docker creates a virtual private network between containers.
- Each container gets its own IP on this internal network.
- Containers discover each other by **service name** via Docker's embedded DNS (`mariadb` resolves to the MariaDB container automatically).
- The host can only reach containers through **explicitly published ports**.

> **In this project:** A custom bridge network named `inception` is used. Only NGINX publishes port 443 to the host. All external traffic must pass through NGINX first.

---

### Docker Volumes vs Bind Mounts

Both allow data to persist beyond the lifecycle of a container.

**Bind mounts:**
- You specify an **exact absolute path on the host** mounted into the container.
- Tightly coupled to the host's directory structure. Fragile in production.
- Useful for development (live code reload), **forbidden** in this project.

**Named Docker volumes (used in this project):**
- Docker manages the storage by logical name, not by hardcoded path.
- The actual host path is configured via `driver_opts` in the compose file.
- Portable and properly managed by Docker's lifecycle.

> **In this project:** `wordpress_data` stores PHP files and `mariadb_data` stores the database, both under `/home/tgomez-f/data/`. Data persists across container restarts and rebuilds.

---

## Documentation

| File | Audience | Content |
|---|---|---|
| [USER_DOC.md](./USER_DOC.md) | End users, administrators | Start/stop, access the site, manage credentials, check service health |
| [DEV_DOC.md](./DEV_DOC.md) | Developers, evaluators | Setup from scratch, build pipeline, advanced Docker commands, data persistence |

---

## Resources

### Official Documentation

- [Docker Documentation](https://docs.docker.com/) — Complete Docker and Docker Compose reference
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/) — All `docker-compose.yml` options
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/) — How Docker volumes work
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) — How Docker secrets work
- [Docker networking](https://docs.docker.com/network/) — Network drivers and concepts
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/) — Server configuration reference
- [MariaDB documentation](https://mariadb.com/docs/server/server-management/variables-and-modes/server-system-variables) — Variables server system for the file configuration
- [NGINX documentation](https://nginx.org/en/docs/) — Directives and configuration guide
- [WP-CLI documentation](https://wp-cli.org/) — WordPress command-line tool
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php) — FastCGI Process Manager

### Articles & Concepts

- [Understanding PID 1 in Docker](https://cloud.google.com/architecture/best-practices-for-building-containers#signal-handling) — Why `exec` matters in entrypoints
- [Linux namespaces explained](https://man7.org/linux/man-pages/man7/namespaces.7.html) — The kernel feature behind container isolation
- [TLS/SSL explained](https://www.cloudflare.com/learning/ssl/what-is-ssl/) — How HTTPS works
- [FastCGI and PHP-FPM](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/) — How NGINX communicates with PHP

### AI Usage

**Claude (Anthropic)** was used as a debugging and helping identify misconfigurations in Dockerfiles, also guidance assistant throughout this project:

- **MariaDB entrypoint** — Diagnosing a race condition where `mysqladmin ping` ran before the socket was created.
- **NGINX configuration** — Identifying why the default NGINX page was served instead of WordPress.
- **Documentation** — Structuring and writing README.md, USER_DOC.md, and DEV_DOC.md.

All suggestions were reviewed, tested, and adapted manually. AI was used as a learning and debugging tool, not as a replacement for understanding the concepts.