# User Documentation

This document is intended for **end users and administrators** of the Inception stack. It covers everything you need to know to run the project, access the services, and keep an eye on their health — without needing to understand the internals.

> For setup from scratch and developer commands, see [DEV_DOC.md](./DEV_DOC.md).

---

## Table of Contents

- [What Services Are Provided](#what-services-are-provided)
- [Starting and Stopping the Project](#starting-and-stopping-the-project)
- [Accessing the Website](#accessing-the-website)
- [Accessing the WordPress Admin Panel](#accessing-the-wordpress-admin-panel)
- [Managing Credentials](#managing-credentials)
- [Checking That Services Are Running](#checking-that-services-are-running)

---

## What Services Are Provided

The stack runs three services, each in its own container:

| Service | Role | Accessible from outside? |
|---|---|---|
| **NGINX** | HTTPS reverse proxy — the front door of the infrastructure | Yes, via `https://tgomez-f.42.fr` (port 443) |
| **WordPress + PHP-FPM** | The web application that serves the website | No — only reachable through NGINX |
| **MariaDB** | The database that stores all website content | No — only reachable by WordPress |

All traffic from the outside world **must pass through NGINX**. The other two services are internal and cannot be reached directly.

---

## Starting and Stopping the Project

### Start the project

From the root of the repository, inside the virtual machine:

```bash
make
```

This builds all images (if not already built) and starts all three containers. Wait until you see no more log output — the stack is ready when WordPress and MariaDB finish their initialization.

### Stop the project (keeps your data)

```bash
make down
```

This stops and removes the containers. Your data (database, WordPress files) is **preserved** in the Docker volumes and will be available next time you run `make`.

### Restart the project

```bash
make down && make
```

---

## Accessing the Website

### Prerequisites

The domain `tgomez-f.42.fr` does not exist on public DNS. You need to tell your machine where to find it by editing the **hosts file** of the machine where your browser runs.

**On the VM itself (or on any Linux/Mac machine):**

```bash
sudo sh -c 'echo "127.0.0.1 tgomez-f.42.fr" >> /etc/hosts'
```

**If your browser runs on a host machine outside the VM**, replace `127.0.0.1` with the VM's IP address. Find it inside the VM with:

```bash
hostname -I
```

Then add on your host machine:

```bash
# Example if the VM's IP is 192.168.1.42
sudo sh -c 'echo "192.168.1.42 tgomez-f.42.fr" >> /etc/hosts'
```

### Open the website

Once the hosts file is configured, open your browser and go to:

```
https://tgomez-f.42.fr
```

> **Certificate warning:** Your browser will warn you about an untrusted certificate. This is expected — the project uses a self-signed TLS certificate. Click **"Advanced"** then **"Proceed to site"** (or equivalent in your browser). This is safe in this local context.

---

## Accessing the WordPress Admin Panel

The administration panel lets you manage posts, users, settings, themes, and plugins.

**URL:**

```
https://tgomez-f.42.fr/wp-admin
```

Log in with the **administrator credentials** (see [Managing Credentials](#managing-credentials) below).

From the admin panel you can:
- Create, edit, and delete posts and pages.
- Manage registered users.
- Install themes and plugins.
- Configure WordPress settings.

---

## Managing Credentials

All sensitive credentials are stored as **Docker secrets** — plain text files located in the `secrets/` directory at the root of the repository. They are never committed to Git.

| Secret file | What it contains |
|---|---|
| `secrets/db_password.txt` | Password for the WordPress database user |
| `secrets/db_root_password.txt` | Root password for MariaDB |
| `secrets/wp_admin_password.txt` | Password for the WordPress administrator account |
| `secrets/wp_user_password.txt` | Password for the secondary WordPress user |

Non-sensitive configuration (usernames, database name, domain, site title) is stored in the `.env` file at the root of the repository.

**To change a password:**
1. Edit the corresponding file in `secrets/`.
2. Run `make down && make` to recreate the containers with the new credentials.

> If the WordPress database already exists, changing the DB password also requires updating it inside MariaDB manually, or wiping the volumes with `make fclean` and starting fresh.

---

## Checking That Services Are Running

### Quick status check

```bash
docker ps
```

All three containers should show status `Up`:

```
CONTAINER ID   IMAGE            STATUS          NAMES
xxxxxxxxxxxx   srcs-nginx       Up X seconds    nginx
xxxxxxxxxxxx   srcs-wordpress   Up X seconds    wordpress
xxxxxxxxxxxx   srcs-mariadb     Up X seconds    mariadb
```

If any container shows `Exited`, check its logs (see below).

### Read container logs

```bash
# All containers at once
docker compose -f srcs/docker-compose.yml logs

# A specific container
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

### Test NGINX is responding

```bash
curl -k https://tgomez-f.42.fr
```

You should receive HTML from the WordPress site. If you get a connection error, NGINX is not running or the hosts file is not configured.

### Test MariaDB is accepting connections

```bash
docker exec mariadb mysqladmin -u root -p"$(cat srcs/secrets/db_root_password.txt)" ping
```

Expected output: `mysqld is alive`