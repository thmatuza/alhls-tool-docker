FROM nginx:1.16.0-alpine

RUN mkdir -p /var/www/html

RUN apk add --virtual curl \
    && curl https://ssl-config.mozilla.org/ffdhe2048.txt > /etc/ssl/dhparam.pem \
    && chmod 755 -R /var/www/html