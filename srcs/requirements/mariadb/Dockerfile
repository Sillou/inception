FROM debian:bookworm

RUN apt-get update \
 && apt-get install -y mariadb-server \
 && mkdir -p /run/mysqld \
 && chown mysql:mysql /run/mysqld

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["mariadbd", "--user=mysql"]
