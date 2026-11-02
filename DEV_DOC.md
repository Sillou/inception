# Developer documentation

This document explains how to set up, build, run and maintain the Inception
stack from a fresh clone of the repository.

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| Linux virtual machine (Debian recommended) | The user should be named after the 42 login (`alubrano`), so that `/home/alubrano` exists and belongs to them. |
| Docker Engine + Docker Compose v2 plugin | Install from Docker's official repository (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`). |
| Docker without `sudo` | `sudo usermod -aG docker $USER`, then log out and back in. |
| `make`, `git`, `openssl` | `sudo apt-get install -y make git openssl` |
| Free TCP port 443 | NGINX publishes port 443 on the host. |

Check the installation:

```bash
docker run --rm hello-world
docker compose version
```

## 2. Project structure

```
.
├── Makefile                      # entry point: builds and runs everything
├── secrets/                      # passwords, NOT tracked by git (see section 3.3)
└── srcs/
    ├── .env                      # non-sensitive configuration
    ├── docker-compose.yml        # services, network, volumes, secrets
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf      # bind-address = 0.0.0.0
        │   └── tools/entrypoint.sh     # creates database, user, root password
        ├── wordpress/
        │   ├── Dockerfile              # php-fpm (port 9000) + WP-CLI
        │   └── tools/entrypoint.sh     # downloads, configures and installs WordPress
        └── nginx/
            ├── Dockerfile              # nginx + self-signed TLS certificate
            └── conf/nginx.conf         # HTTPS on 443, TLSv1.2/1.3, PHP -> wordpress:9000
```

All images are built from `debian:bookworm` (penultimate stable Debian).
No ready-made image (e.g. `wordpress`, `mariadb`, `nginx` from Docker Hub) is used.

## 3. Setting up the environment from scratch

### 3.1 Clone the repository

```bash
git clone <repository-url> inception
cd inception
```

### 3.2 Domain name

The site is served at `https://alubrano.42.fr`. Point this name to the local machine:

```bash
echo "127.0.0.1 alubrano.42.fr" | sudo tee -a /etc/hosts
getent hosts alubrano.42.fr      # must print 127.0.0.1
```

### 3.3 Secrets (mandatory)

Passwords are never stored in git, in the Dockerfiles or in `.env`.
They live in the `secrets/` folder, which is listed in `.gitignore`, so it is
**not** present after a clone and must be created:

```bash
mkdir -p secrets
openssl rand -hex 16 > secrets/db_password.txt
openssl rand -hex 16 > secrets/db_root_password.txt
echo "choose-an-admin-password" > secrets/wp_admin_password.txt
echo "choose-a-user-password"   > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

| File | Used by | Purpose |
|---|---|---|
| `db_password.txt` | mariadb, wordpress | password of the MariaDB user used by WordPress |
| `db_root_password.txt` | mariadb | password of the MariaDB `root` account |
| `wp_admin_password.txt` | wordpress | password of the WordPress administrator |
| `wp_user_password.txt` | wordpress | password of the second WordPress user |

Avoid the characters `' " $ \` `` ` `` and spaces in passwords: they are inserted
into SQL statements and shell commands.

Docker Compose mounts each secret as a read-only file in
`/run/secrets/<name>` inside the containers that declare it. The secrets are
not part of the images and do not appear in `docker inspect`.

### 3.4 Configuration file `srcs/.env`

This file is tracked by git and contains **no password**.

| Variable | Description |
|---|---|
| `MYSQL_DATABASE` | name of the WordPress database |
| `MYSQL_USER` | MariaDB user used by WordPress |
| `DOMAIN_NAME` | site domain, used for the WordPress URL |
| `WP_TITLE` | site title |
| `WP_ADMIN_USER` | WordPress administrator login (must not contain `admin`) |
| `WP_ADMIN_EMAIL` | administrator e-mail |
| `WP_USER` | second WordPress user (role `author`) |
| `WP_USER_EMAIL` | second user e-mail (must differ from the admin e-mail) |

The domain is also written in `srcs/requirements/nginx/conf/nginx.conf`
(`server_name`) and in the NGINX `Dockerfile` (certificate `CN`): change all
three places together.

## 4. Building and launching

All commands are run from the repository root.

| Command | Effect |
|---|---|
| `make` | creates the data folders, builds the images and starts the stack in the background |
| `make down` | stops and removes the containers and the network, **keeps the data** |
| `make clean` | `down` + removes the project images |
| `make fclean` | `clean` + removes the volumes **and deletes all data** (`sudo` required) |
| `make re` | `fclean` then `make`: full reinstall from scratch |

`make` runs:

```bash
mkdir -p /home/alubrano/data/mariadb /home/alubrano/data/wordpress
docker compose -f srcs/docker-compose.yml up -d --build
```

### Start-up order

1. **mariadb** starts. On the first run, `entrypoint.sh` creates the database,
   the WordPress user and sets the root password (`mariadbd --bootstrap`), then
   `exec`s the server as PID 1.
2. A **healthcheck** (`mariadb-admin ping`) reports when MariaDB accepts
   connections. **wordpress** waits for it (`depends_on: condition: service_healthy`).
3. **wordpress**: on the first run, `entrypoint.sh` downloads WordPress with
   WP-CLI, creates `wp-config.php`, installs the site and creates both users,
   then `exec`s `php-fpm8.2 -F` as PID 1. Each step is skipped if already done.
4. **nginx** starts and serves `https://alubrano.42.fr` on port 443.

The first build downloads all Debian packages and WordPress: it can take
several minutes on a slow machine. Later builds use the Docker build cache.

## 5. Managing containers and volumes

Run from the repository root (or from `srcs/` without the `-f` option).

```bash
# shortcut used below
alias dc='docker compose -f srcs/docker-compose.yml'
```

| Command | Purpose |
|---|---|
| `dc ps` | status of the services (MariaDB shows `(healthy)`) |
| `dc logs <service>` | logs of a service; add `-f` to follow them live |
| `dc exec <service> sh` | open a shell inside a running container |
| `dc up -d --build <service>` | rebuild and restart a single service |
| `dc restart <service>` | restart a service |
| `dc config` | validate the compose file and show the resolved configuration |
| `docker volume ls` | list volumes (`srcs_mariadb_volume`, `srcs_wordpress_volume`) |
| `docker volume inspect srcs_mariadb_volume` | show where the volume stores its data |
| `docker network ls` | list networks (`srcs_inception`) |
| `docker images` | list images (`mariadb:inception`, `wordpress:inception`, `nginx:inception`) |

### Database access

```bash
# as root (password: secrets/db_root_password.txt)
dc exec mariadb mariadb -u root -p

# as the WordPress user (password: secrets/db_password.txt)
dc exec mariadb mariadb -u wpuser -p
```

Useful queries: `SHOW DATABASES;`, `USE wordpress; SHOW TABLES;`,
`SELECT user_login FROM wordpress.wp_users;`.

### WordPress administration with WP-CLI

```bash
dc exec wordpress wp user list --allow-root --path=/var/www/html
dc exec wordpress wp user update <login> --user_pass=<new-password> --allow-root --path=/var/www/html
dc exec wordpress wp option get siteurl --allow-root --path=/var/www/html
```

Changing a file in `secrets/` does **not** change a password of an already
installed site: secrets are only used on the first installation. Use the
commands above, or `make re` to reinstall from scratch.

## 6. Data storage and persistence

The project uses two Docker **named volumes**, configured with the `local`
driver so that their data is stored in a fixed folder on the host:

| Volume | Mounted in | Host folder | Content |
|---|---|---|---|
| `mariadb_volume` | `mariadb:/var/lib/mysql` | `/home/alubrano/data/mariadb` | the whole MariaDB data directory: users, `wordpress` database (posts, comments, settings) |
| `wordpress_volume` | `wordpress:/var/www/html` and `nginx:/var/www/html` | `/home/alubrano/data/wordpress` | WordPress files, `wp-config.php`, uploaded media (`wp-content/uploads`) |

NGINX mounts the WordPress volume to serve static files (CSS, JS, images)
directly; PHP files are forwarded to `wordpress:9000` (FastCGI).

| Action | Data kept? |
|---|---|
| `make down`, `make clean`, container restart, VM reboot | yes |
| `docker compose down -v` | yes, the files remain in `/home/alubrano/data` |
| `make fclean`, `make re` | **no**, `/home/alubrano/data` is deleted |

Files in `/home/alubrano/data/mariadb` belong to the `mysql` user of the
container (shown with another name or a number on the host): use `sudo` to
read or delete them.

## 7. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Browser cannot reach the site | `alubrano.42.fr` missing from `/etc/hosts`; use `https://` (port 80 is closed) |
| Browser security warning | expected: the TLS certificate is self-signed |
| `Error establishing a database connection` | MariaDB not ready or wrong password: check `dc logs mariadb` and `secrets/db_password.txt` |
| `make` fails on `mkdir` | `/home/alubrano` does not exist or is not writable: create it with `sudo` and `chown` it |
| `no such file or directory` for a secret | the `secrets/` folder or one of its files is missing (section 3.3) |
| Port 443 already in use | another web server runs on the host: stop it |
