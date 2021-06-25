FROM nginx
LABEL maintainer=priotix

COPY ./ /tmp/nginx-conf

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
