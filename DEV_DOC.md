# Developer Documentation

This document is intended for **developers and evaluators** who need to set up the project from scratch, understand the build pipeline, and manage containers and data at a technical level.

> For end-user instructions (accessing the site, starting/stopping), see [USER_DOC.md](./USER_DOC.md).

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Configuration Files](#configuration-files)
- [Setting Up Secrets](#setting-up-secrets)
- [Environment Variables](#environment-variables)
- [Building and Launching](#building-and-launching)
- [Makefile Targets](#makefile-targets)
- [Container Management Commands](#container-management-commands)
- [Data Storage and Persistence](#data-storage-and-persistence)

---

## Prerequisites

The following must be installed on the virtual machine before running the project:

| Tool | Purpose | Install |
|---|---|---|
| Docker Engine | Container runtime | `sudo apt install docker.io` |
| Docker Compose v2 | Multi-container orchestration | `sudo apt install docker-compose-v2` |
| Make | Build automation | `sudo apt install make` |
| openssl | TLS certificate generation | `sudo apt install openssl` |

Ensure your user is in the `docker` group to avoid using `sudo` for every docker command:

```bash
sudo usermod -aG docker $USER
# Log out and back in for the group change to take effect
```

---

## Repository Structure

```
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                          # Non-sensitive environment variables
    ├── docker-compose.yml
    ├── secrets/                      # Sensitive credentials (NOT committed to Git)
    │   ├── db_password.txt
    │   ├── db_root_password.txt
    │   ├── wp_admin_password.txt
    │   └── wp_user_password.txt
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/
        │       ├── nginx.conf
        │       └── ssl/              # Generated TLS certificate (not committed)
        ├── wordpress/
        │   ├── Dockerfile
        │   └── conf/
        │       ├── script.sh         # Entrypoint script
        │       └── www.conf          # PHP-FPM pool config
        └── mariadb/
            ├── Dockerfile
            └── conf/
                ├── mariadb_init.sh   # Entrypoint script
                └── 50-server.cnf    # MariaDB server config
```

---

## Configuration Files

### NGINX (`nginx.conf`)

Configures the HTTPS server:
- Listens on port 443 with TLSv1.2 and TLSv1.3 only.
- Points `root` to `/var/www/wordpress` (the WordPress volume mount point).
- Passes all `.php` requests to WordPress via FastCGI on `wordpress:9000`.
- `try_files $uri $uri/ /index.php?$args` ensures WordPress permalinks work correctly.

### PHP-FPM (`www.conf`)

Configures the PHP-FPM worker pool:
- Sets `listen = 9000` so PHP-FPM accepts TCP connections (required for Docker networking — Unix sockets do not work across containers).
- Sets `listen.allowed_clients` to accept connections from the NGINX container.

### MariaDB (`50-server.cnf`)

Configures the MariaDB server:
- `bind-address = 0.0.0.0` — listens on all network interfaces so WordPress can connect from its container.
- `port = 3306` — standard MySQL port.
- `socket = /run/mysqld/mysqld.sock` — path used for local socket communication during initialization.
- `datadir = /var/lib/mysql` — path mapped to the `mariadb_data` Docker volume.

---

## Setting Up Secrets

Secrets are plain text files containing passwords. They must be created manually and are **never committed to Git** (listed in `.gitignore`).

Create the `secrets/` directory and populate it:

```bash
mkdir -p srcs/secrets

echo "a_strong_db_password"       > srcs/secrets/db_password.txt
echo "a_strong_root_password"     > srcs/secrets/db_root_password.txt
echo "a_strong_admin_password"    > srcs/secrets/wp_admin_password.txt
echo "a_strong_user_password"     > srcs/secrets/wp_user_password.txt
```

At runtime, Docker mounts each file inside containers at `/run/secrets/<filename_without_.txt>`. Scripts read them with:

```bash
$(cat /run/secrets/db_password)
```

And PHP reads them with:

```php
trim(file_get_contents('/run/secrets/db_password'))
```

---

## Environment Variables

The `.env` file at `srcs/.env` contains all non-sensitive configuration. Docker Compose reads it automatically.

```env
# Domain name (must match your /etc/hosts entry)
DOMAIN_NAME=tgomez-f.42.fr

# MariaDB
SQL_DATABASE=wordpress_db
SQL_USER=wp_user
SQL_HOST=mariadb          # Docker service name, resolved by Docker DNS

# WordPress
SITE_NAME=My Inception Site
WP_ADMIN_USER=myadmin     # Must NOT contain "admin" or "administrator"
WP_ADMIN_EMAIL=admin@tgomez-f.42.fr
WP_USER=visitor
WP_USER_EMAIL=visitor@tgomez-f.42.fr
```

These variables are injected into containers via the `environment:` section of `docker-compose.yml` and are available as standard shell environment variables inside each container.

---

## Building and Launching

### Generate the TLS certificate

The NGINX container requires a self-signed TLS certificate. Generate it before the first build:

```bash
mkdir -p srcs/requirements/nginx/conf/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout srcs/requirements/nginx/conf/ssl/nginx.key \
  -out srcs/requirements/nginx/conf/ssl/nginx.crt \
  -subj "/CN=tgomez-f.42.fr"
```

This creates a private key and a self-signed certificate valid for 365 days. The Dockerfile copies them into the image at build time.

### Build and start

```bash
make
```

Internally, `make` runs:

1. `mkdir -p /home/tgomez-f/data/wordpress /home/tgomez-f/data/mariadb` — creates host data directories.
2. `docker compose -f srcs/docker-compose.yml build` — builds all three images from their Dockerfiles.
3. `docker compose -f srcs/docker-compose.yml up -d` — starts all containers in detached mode.

### Force a complete rebuild (no cache)

Use this when you modify a Dockerfile or a config file and want to ensure nothing is cached:

```bash
docker compose -f srcs/docker-compose.yml build --no-cache
docker compose -f srcs/docker-compose.yml up -d
```

---

## Makefile Targets

| Target | Description |
|---|---|
| `make` | Build images and start containers |
| `make down` | Stop and remove containers (data preserved) |
| `make fclean` | Stop containers, remove images, delete all volume data |
| `make re` | `fclean` then full rebuild from scratch |

---

## Container Management Commands

### Inspect a running container

```bash
docker exec -it nginx bash
docker exec -it wordpress bash
docker exec -it mariadb bash
```

### View real-time logs

```bash
docker compose -f srcs/docker-compose.yml logs -f
# Or for a single service:
docker compose -f srcs/docker-compose.yml logs -f mariadb
```

### Inspect the Docker network

```bash
docker network inspect srcs_inception
```

This shows all containers attached to the network, their internal IP addresses, and their DNS names.

### Inspect volumes

```bash
# List all volumes
docker volume ls

# Inspect a specific volume
docker volume inspect srcs_wordpress_data
docker volume inspect srcs_mariadb_data
```

### Connect to MariaDB directly

```bash
docker exec -it mariadb mysql -u root -p"$(cat srcs/secrets/db_root_password.txt)"
```

Useful SQL commands once connected:

```sql
SHOW DATABASES;
USE wordpress_db;
SHOW TABLES;
SELECT user, host FROM mysql.user;
```

### Run a WP-CLI command inside WordPress

```bash
docker exec -it wordpress wp --allow-root user list
docker exec -it wordpress wp --allow-root post list
```

---

## Data Storage and Persistence

### Where data lives

The project uses two named Docker volumes, both configured to store data on the host under `/home/tgomez-f/data/`:

| Volume name | Host path | Container mount point | Contents |
|---|---|---|---|
| `srcs_wordpress_data` | `/home/tgomez-f/data/wordpress` | `/var/www/wordpress` | WordPress PHP files, themes, uploads, plugins |
| `srcs_mariadb_data` | `/home/tgomez-f/data/mariadb` | `/var/lib/mysql` | MariaDB database files |

### What persists and what doesn't

| Action | Data preserved? |
|---|---|
| `make down` then `make` | ✅ Yes — volumes are not removed |
| Container crash and restart | ✅ Yes — `restart: always` recreates the container, volumes unchanged |
| `docker compose build --no-cache` + `up` | ✅ Yes — rebuilding images does not touch volumes |
| `make fclean` | ❌ No — volumes and host data directories are deleted |

### Initialization logic

- **MariaDB:** On first start, the entrypoint script creates the database and user only if they do not already exist (`CREATE DATABASE IF NOT EXISTS`, `CREATE USER IF NOT EXISTS`). On subsequent starts, it detects the existing data and skips initialization.
- **WordPress:** The entrypoint runs `wp config create` and `wp core install` on every start. `wp core install` is idempotent — it does nothing if WordPress is already installed.