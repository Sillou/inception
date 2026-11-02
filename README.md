*This project has been created as part of the 42 curriculum by alubrano.*

# Inception

## Description

Inception is a system administration project. Its goal is to build a small web
infrastructure with Docker Compose, inside a virtual machine, using custom
Docker images.

The stack serves a WordPress website at `https://alubrano.42.fr`. It is made of
three services, each running in its own container:

- **NGINX**: the only entry point, on port 443, with TLSv1.2 or TLSv1.3 only.
- **WordPress + php-fpm**: runs the website, without a web server.
- **MariaDB**: stores the website data.

## Instructions

### Requirements

- A Linux virtual machine
- Docker Engine and the Docker Compose v2 plugin
- `make`, `git` and `openssl`

### Setup

1. Point the domain name to the local machine:

   ```bash
   echo "127.0.0.1 alubrano.42.fr" | sudo tee -a /etc/hosts
   ```

2. Create the secrets, which are not stored in git:

   ```bash
   mkdir -p secrets
   openssl rand -hex 16 > secrets/db_password.txt
   openssl rand -hex 16 > secrets/db_root_password.txt
   echo "choose-an-admin-password" > secrets/wp_admin_password.txt
   echo "choose-a-user-password"   > secrets/wp_user_password.txt
   ```

### Usage

| Command | Effect |
|---|---|
| `make` | build the images and start the stack |
| `make down` | stop the stack, keep the data |
| `make clean` | stop the stack and remove the images |
| `make fclean` | remove the images, the volumes and all the data |
| `make re` | reinstall from scratch |

Then open <https://alubrano.42.fr>. The browser shows a warning because the TLS
certificate is self-signed.

See [USER_DOC.md](USER_DOC.md) to use the website and
[DEV_DOC.md](DEV_DOC.md) for the full developer setup.

## Project description

### Use of Docker

Docker packages each service with its dependencies in an isolated container.
Docker Compose describes the whole infrastructure in a single file and starts
it with one command.

Requests travel as follows:

```
Browser --HTTPS:443--> NGINX --FastCGI:9000--> WordPress/php-fpm --SQL:3306--> MariaDB
```

### Sources included in the project

| Path | Content |
|---|---|
| `Makefile` | builds and runs the stack |
| `srcs/docker-compose.yml` | services, network, volumes, secrets |
| `srcs/.env` | non-sensitive configuration |
| `srcs/requirements/mariadb/` | Dockerfile, server configuration, initialization script |
| `srcs/requirements/wordpress/` | Dockerfile, installation script using WP-CLI |
| `srcs/requirements/nginx/` | Dockerfile, HTTPS configuration |

### Main design choices

- **Base image**: `debian:bookworm`, the penultimate stable Debian release, for
  its familiar tooling and documentation. No ready-made service image is used.
- **PID 1**: each service runs in the foreground as PID 1. The entrypoint
  scripts end with `exec "$@"`, so that services receive stop signals directly.
- **Idempotent start-up**: the entrypoint scripts can run on every start without
  breaking an existing installation.
- **Start-up order**: a healthcheck on MariaDB makes WordPress wait until the
  database accepts connections, with no loop or `sleep` in the scripts.
- **TLS certificate**: a self-signed certificate is generated when the NGINX
  image is built.
- **Least privilege**: WordPress connects with a dedicated database user that
  only has access to its own database, and it does not receive the MariaDB root
  password.

### Virtual Machines vs Docker

| | Virtual machine | Docker container |
|---|---|---|
| Isolation | Strong: its own kernel on virtualized hardware | Lighter: isolated processes sharing the host kernel |
| Size | Several GB | A few MB to a few hundred MB |
| Start-up | Tens of seconds or more | Usually about a second |
| Runs | A full operating system | Ideally one main process |

A virtual machine is the better choice to run another operating system or to
get strong isolation. Containers are lighter and better suited to deploying
services. This project uses both: Docker runs inside a virtual machine.

### Secrets vs Environment Variables

| | Environment variables | Docker secrets |
|---|---|---|
| Form | Variables of the process | Files in `/run/secrets/` |
| Visibility | Shown by `docker inspect`, inherited by child processes | Only available to the services that declare them |
| Use | Non-sensitive configuration | Passwords and keys |

This project keeps its configuration in `srcs/.env` and its passwords in the
`secrets/` folder, which is ignored by git.

### Docker Network vs Host Network

| | Docker network (bridge) | Host network |
|---|---|---|
| Isolation | Private network for the containers | None: the container shares the host network |
| Name resolution | Containers reach each other by service name | Uses the host's network configuration |
| Exposure | Only explicitly published ports are reachable | Every listening port is exposed on the host |
| Port conflicts | Avoided | Possible with host services |

This project uses a bridge network called `inception`. Only NGINX publishes a
port (443).

### Docker Volumes vs Bind Mounts

| | Named volume | Bind mount |
|---|---|---|
| Managed by | Docker (`docker volume ls`) | The user: any host folder |
| Default location | `/var/lib/docker/volumes/` | The chosen path |
| Empty on first use | Filled with the image content at the mount point | Hides the image content |
| Typical use | Application data | Sharing source code during development |

This project uses two named volumes, one for the database and one for the
website files. Their `local` driver options store the data in
`/home/alubrano/data`, as required by the subject.

## Resources

### Documentation

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### Use of AI

AI  was used as a learning assistant throughout the project: explaining
Docker, TLS, PHP-FPM and MariaDB concepts, helping to debug, and helping to
write and correct configuration files, Dockerfiles and scripts. It also drafted
README.md, USER_DOC.md and DEV_DOC.md.
