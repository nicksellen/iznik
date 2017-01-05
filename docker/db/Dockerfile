#FROM orchardup/mysql
FROM percona:5.7

ADD docker/db/my.cnf /etc/mysql/my.cnf
RUN rm -r /etc/mysql/conf.d # remove as everything is in my.cnf