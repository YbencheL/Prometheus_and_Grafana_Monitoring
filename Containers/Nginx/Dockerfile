FROM nginx:1.29.8

RUN apt update && apt install -y nginx && \
    mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -days 365 -nodes -out /etc/nginx/ssl/inception.crt \
    -keyout /etc/nginx/ssl/inception.key -subj \
    "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=135.225.128.201/UID=ybenchel"

COPY files/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443 80