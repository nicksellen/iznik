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

WORKDIR /app/http

RUN ln -s /app/docker/app/iznik.conf.php /etc/iznik.conf

CMD hhvm -m server -p 9000
