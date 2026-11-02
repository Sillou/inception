FROM debian:bookworm

RUN apt-get update \
 && apt-get install -y nginx openssl \
 && mkdir -p /etc/nginx/ssl \
 && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/CN=alubrano.42.fr" \
 && rm /etc/nginx/sites-enabled/default

COPY conf/nginx.conf /etc/nginx/conf.d/inception.conf

CMD ["nginx", "-g", "daemon off;"]
