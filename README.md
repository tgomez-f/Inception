# Inception

*This project has been created as part of the 42 curriculum by tgomez-f.*

---

## Table of Contents

- [Description](#description)
- [Project Architecture](#project-architecture)
- [Key Design Choices](#key-design-choices)
  - [Virtual Machines vs Docker](#virtual-machines-vs-docker)
  - [Secrets vs Environment Variables](#secrets-vs-environment-variables)
  - [Docker Network vs Host Network](#docker-network-vs-host-network)
  - [Docker Volumes vs Bind Mounts](#docker-volumes-vs-bind-mounts)
- [Instructions](#instructions)
- [Resources](#resources)

---

## Description

**Inception** is a system administration project from the 42 curriculum. The goal is to set up a small but complete web infrastructure using **Docker** and **Docker Compose**, entirely inside a virtual machine.

The infrastructure consists of three services, each running in its own dedicated container:

- **NGINX** — acts as the only entry point to the infrastructure, handling HTTPS traffic on port 443 using TLSv1.2 or TLSv1.3.
- **WordPress + PHP-FPM** — the web application, running without a web server (Nginx handles that part).
- **MariaDB** — the relational database that stores all WordPress data.

All images are built from scratch using custom `Dockerfiles` based on **Debian Bullseye**. No pre-built images from Docker Hub are used (except the base OS image).

The project is a hands-on introduction to containerization, networking, persistent storage, and security best practices in a DevOps context.

---

## Project Architecture

```
                        Internet / Browser
                               │
                               │ HTTPS :443
                               ▼
                        ┌─────────────┐
                        │    NGINX    │  ← Only entry point
                        │  container  │    TLSv1.2 / TLSv1.3
                        └──────┬──────┘
                               │ FastCGI (port 9000)
                               ▼
                        ┌─────────────┐
                        │  WordPress  │  ← PHP-FPM application
                        │  container  │
                        └──────┬──────┘
                               │ TCP (port 3306)
                               ▼
                        ┌─────────────┐
                        │   MariaDB   │  ← Database
                        │  container  │
                        └─────────────┘

        All containers communicate through a Docker bridge network.
        Data is persisted via two named Docker volumes:
          - wordpress_data  →  WordPress files
          - mariadb_data    →  Database files
```

---

## Key Design Choices

### Virtual Machines vs Docker

Both technologies provide **isolation**, but they work very differently.

**A Virtual Machine (VM):**
- Emulates a complete physical machine, including its own OS kernel.
- Requires a **hypervisor** (e.g. VirtualBox, VMware) to manage hardware resources.
- Takes several minutes to boot.
- Is heavy: each VM typically uses several gigabytes of disk and RAM.
- Provides very strong isolation (separate kernel per VM).

**Docker (containers):**
- Does **not** emulate hardware. Containers share the host's OS kernel.
- Uses Linux kernel features (`namespaces` for isolation, `cgroups` for resource limits).
- Starts in milliseconds.
- Is lightweight: a container image can be just a few megabytes.
- Isolation is lighter than VMs (shared kernel), but sufficient for most use cases.

> **In this project:** Docker is used because we need to run multiple isolated services efficiently on the same VM. Each service (NGINX, WordPress, MariaDB) gets its own container with its own filesystem and network interface, without the overhead of running full virtual machines.

---

### Secrets vs Environment Variables

Both are ways to pass configuration data to a container, but they serve different purposes.

**Environment Variables (`.env` file):**
- Stored as plain text in the environment of the process.
- Visible via `docker inspect`, in logs, or if the app crashes.
- Fine for **non-sensitive** config: domain names, database names, usernames, etc.
- Example: `SQL_DATABASE=wordpress_db`, `DOMAIN_NAME=tgomez-f.42.fr`

**Docker Secrets:**
- Stored securely and mounted as files inside the container at `/run/secrets/<name>`.
- Never exposed in `docker inspect` or environment listings.
- Designed specifically for **sensitive data**: passwords, API keys, certificates.
- Read in code via `file_get_contents('/run/secrets/db_password')` (PHP) or `$(cat /run/secrets/db_password)` (bash).

> **In this project:** We use environment variables for general configuration and Docker secrets for all passwords (database password, root password, WordPress admin password, user password). This follows the principle of **least exposure**: sensitive data is never stored in plain text in the image or visible in the environment.

---

### Docker Network vs Host Network

Containers need to communicate with each other and with the outside world. Docker offers different network modes.

**Host Network (`network_mode: host`):**
- The container shares the **host machine's network stack** directly.
- No isolation: the container can see and bind to all host interfaces.
- Simpler but less secure, and **forbidden** in this project.
- Example: a container using port 80 would directly use the host's port 80.

**Docker Bridge Network (custom named network):**
- Docker creates a **virtual private network** between containers.
- Each container gets its own IP on this internal network.
- Containers can reach each other **by service name** (DNS resolution built-in).
- The host can only access containers through explicitly **published ports**.
- This is the default and recommended approach.

> **In this project:** We use a custom bridge network called `inception`. NGINX publishes port 443 to the host. WordPress and MariaDB are **not** exposed to the host — they are only reachable from within the Docker network. This means the only way in is through NGINX, exactly as required.

---

### Docker Volumes vs Bind Mounts

Persistent storage in Docker can be managed in different ways.

**Bind Mounts:**
- You specify an **exact path on the host** that is mounted into the container.
- Example: `/home/tgomez-f/data/wordpress:/var/www/wordpress`
- Tightly coupled to the host filesystem structure.
- Useful for development (live code reload), but less portable and **forbidden** in this project.

**Named Docker Volumes:**
- Docker manages the storage location internally (under `/var/lib/docker/volumes/` by default).
- Referenced by name in `docker-compose.yml`, not by path.
- Portable, managed by Docker, and the recommended approach for production.
- Can be configured to store data at a specific host path using the `driver_opts`.

> **In this project:** We use two named Docker volumes configured to store their data under `/home/tgomez-f/data/` on the host:
> - `wordpress_data` → stores the WordPress PHP files (`/home/tgomez-f/data/wordpress`)
> - `mariadb_data` → stores the MariaDB database files (`/home/tgomez-f/data/mariadb`)
>
> This ensures data **persists** even if containers are stopped or recreated.

---

## Instructions

### Prerequisites

- A Linux virtual machine (Debian recommended)
- Docker and Docker Compose installed
- `make` installed
- `sudo` access

### 1. Clone the repository

```bash
git clone https://github.com/tgomez-f/inception.git
cd inception
```

### 2. Configure your host's DNS resolution

Add the following line to `/etc/hosts` on the machine where you will open the browser:

```bash
sudo sh -c 'echo "127.0.0.1 tgomez-f.42.fr" >> /etc/hosts'
```

> If you are accessing from a machine **outside** the VM, replace `127.0.0.1` with the VM's IP address (find it with `hostname -I` inside the VM).

### 3. Create the secrets files

The project uses Docker secrets for sensitive data. Create the required secret files:

```bash
mkdir -p secrets
echo "your_db_password"        > secrets/db_password.txt
echo "your_db_root_password"   > secrets/db_root_password.txt
echo "your_wp_admin_password"  > secrets/wp_admin_password.txt
echo "your_wp_user_password"   > secrets/wp_user_password.txt
```

> These files must **never** be committed to Git. They are listed in `.gitignore`.

### 4. Configure environment variables

Edit the `.env` file at the root of the project:

```env
# Domain
DOMAIN_NAME=tgomez-f.42.fr

# MariaDB
SQL_DATABASE=wordpress_db
SQL_USER=wp_user
SQL_HOST=mariadb

# WordPress
SITE_NAME=My Inception Site
WP_ADMIN_USER=myadmin
WP_ADMIN_EMAIL=admin@tgomez-f.42.fr
WP_USER=visitor
WP_USER_EMAIL=visitor@tgomez-f.42.fr
```

> Note: `WP_ADMIN_USER` must **not** contain `admin` or `administrator` in any form.

### 5. Build and run

```bash
make
```

This will:
1. Create the required data directories under `/home/tgomez-f/data/`
2. Build all Docker images from their respective `Dockerfiles`
3. Start all containers with `docker compose up`

### 6. Access the site

Open your browser and navigate to:

```
https://tgomez-f.42.fr
```

> Your browser will show a certificate warning because we use a self-signed TLS certificate. This is expected — click "Advanced" and proceed.

### 7. Stop the project

```bash
make down
```

### 8. Full cleanup (removes volumes and data)

```bash
make fclean
```

---

## Resources

### Official Documentation

- [Docker Documentation](https://docs.docker.com/) — Complete reference for Docker and Docker Compose
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/) — All options for `docker-compose.yml`
- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/) — All Dockerfile instructions
- [MariaDB Docker documentation](https://mariadb.com/kb/en/documentation/) — MariaDB configuration
- [NGINX documentation](https://nginx.org/en/docs/) — NGINX configuration reference
- [WordPress WP-CLI documentation](https://wp-cli.org/) — Command-line interface for WordPress
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php) — PHP FastCGI Process Manager

### Articles & Tutorials

- [Docker networking overview](https://docs.docker.com/network/) — How Docker networks work
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) — Official best practices
- [Understanding PID 1 in Docker](https://cloud.google.com/architecture/best-practices-for-building-containers#signal-handling) — Why `exec` matters in entrypoints
- [Docker secrets documentation](https://docs.docker.com/engine/swarm/secrets/) — How Docker secrets work
- [TLS/SSL explained](https://www.cloudflare.com/learning/ssl/what-is-ssl/) — Cloudflare's introduction to TLS

### AI Usage

**Claude (Anthropic)** was used as a debugging and guidance assistant throughout this project. Specifically:

- **Debugging entrypoint scripts** — Identifying race conditions in the MariaDB startup script (socket not ready when `mysqladmin ping` was called too early).
- **Nginx configuration** — Diagnosing why the default Nginx page was served instead of WordPress (missing `root` and `index` directives at server block level).
- **Docker best practices** — Verifying compliance with 42's rules (no infinite loops, no `tail -f`, proper use of `exec` for PID 1).
- **WordPress setup** — Recommending `wp config create` over a static `wp-config.php` for cleaner and more secure configuration.
- **README writing** — Structuring and writing this document.

All suggestions were reviewed, understood, and adapted manually. AI was used as a learning tool, not as a replacement for understanding the concepts.