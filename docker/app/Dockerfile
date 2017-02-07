FROM hhvm/hhvm

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  curl

RUN \
  curl -sS https://getcomposer.org/installer | \
  php -- \
  --install-dir=/usr/local/bin \
  --filename=composer

RUN mkdir -p /usr/local/share/GeoIP && \
  curl \
  http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz > \
  /usr/local/share/GeoIP/GeoLite2-Country.mmdb.gz && \
  gzip -d /usr/local/share/GeoIP/GeoLite2-Country.mmdb.gz

WORKDIR /var/www/iznik/http

CMD hhvm \
  --mode server \
  --config /etc/hhvm/php.ini \
  --config /etc/hhvm/server.ini
