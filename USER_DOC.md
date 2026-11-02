# User documentation

This guide explains how to use the Inception stack: a WordPress website that
runs in Docker containers. No knowledge of Docker is needed.

To install the project for the first time, see [DEV_DOC.md](DEV_DOC.md).

## 1. Services provided

| Service | What it does | Reachable by you? |
|---|---|---|
| **NGINX** | Web server. It is the only entry point of the stack and only accepts secure connections (HTTPS, port 443). | Yes, through your browser |
| **WordPress** | The website and its administration panel. | Through NGINX only |
| **MariaDB** | The database that stores posts, comments, users and settings. | No, internal only |

## 2. Starting and stopping the project

Open a terminal in the project folder, then:

| Action | Command |
|---|---|
| Start the website | `make` |
| Stop the website (your content is kept) | `make down` |

`make` takes longer the first time, because it has to download and build
everything. Wait a few seconds after it finishes before opening the site.

**Warning:** `make fclean` and `make re` **permanently delete** the website
content (posts, comments, uploaded images). Do not use them unless you want to
start again from an empty site.

## 3. Accessing the website

| Page | Address |
|---|---|
| Website | <https://alubrano.42.fr> |
| Administration panel | <https://alubrano.42.fr/wp-admin> |

Always type `https://`: plain `http://` is disabled on purpose.

The first time, your browser shows a security warning such as "Your connection
is not private". This is expected, because the site uses a self-signed
certificate. The connection is still encrypted. Click **Advanced**, then
**Continue to alubrano.42.fr**.

## 4. Accounts and credentials

| Account | Login | Password stored in | Can do |
|---|---|---|---|
| WordPress administrator | `alub` | `secrets/wp_admin_password.txt` | everything: settings, themes, plugins, users, moderating comments |
| WordPress user | `bob` | `secrets/wp_user_password.txt` | write and publish their own posts, comment |
| Database administrator | `root` | `secrets/db_root_password.txt` | direct access to the database, for maintenance only |

Logins and e-mail addresses are set in `srcs/.env`.

To read a password:

```bash
cat secrets/wp_admin_password.txt
```

**Keep these files private.** The `secrets/` folder must never be shared or
added to git.

### Changing a password

Log in to the administration panel, open **Users > Profile**, then click
**Set New Password**.

Editing a file in `secrets/` does not change the password of a site that is
already installed. If you change a password in the panel, update the matching
file too, so that it stays correct.

## 5. Checking that everything works

### Status of the services

```bash
docker compose -f srcs/docker-compose.yml ps
```

You should see three lines, `mariadb`, `nginx` and `wordpress`, each with the
status `Up`. MariaDB also shows `(healthy)`, and NGINX shows port `443`.

### Quick test

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" https://alubrano.42.fr
```

`200` means the site is working.

### Reading the logs

If something is wrong, display the messages of a service:

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

### Common problems

| Problem | Solution |
|---|---|
| The browser cannot find the site | Check that the services are running (`make`) and that you typed `https://`. |
| Security warning in the browser | Normal, see section 3. |
| "Error establishing a database connection" | MariaDB is still starting: wait a few seconds and reload the page. |
| A service is missing from the list | Run `make` again, then read its logs. |
