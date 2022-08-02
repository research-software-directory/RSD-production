FROM postgres:14.2
RUN chmod a+rwx /docker-entrypoint-initdb.d
COPY --chown=postgres:postgres *.sh /docker-entrypoint-initdb.d/
COPY --chown=postgres:postgres *.sql /docker-entrypoint-initdb.d/
