# docker-ckan

Docker build directory for a single-machine instance of CKAN

## Dump the database

docker exec ckan /bin/bash -c '/usr/local/bin/paster --plugin=ckan db dump  -c /etc/ckan/default/development.ini /tmp/database-dump.sql; cat /tmp/database-dump.sql '