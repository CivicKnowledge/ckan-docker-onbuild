##
## Docker configuration for CKAN 2.3a, with both Postgres and Solr in the same container. 
## With the DEBUG env var set, it will run in development mode, and it exports both the data
## directory and the source directory, for developing extensions. 
##

## Mostly from the Package install instructions at: 
## http://docs.ckan.org/en/latest/maintaining/installing/install-from-package.html

## Env Vars:
##  ADMIN_USER_PASS
##  ADMIN_USER_EMAIL
##  ADMIN_USER_KEY

FROM ubuntu:14.04
MAINTAINER Eric Busboom <eric@sandiegodata.org>

##
## Clean and prepare for installing other packages. 
##

RUN apt-get update && \ 
apt-get upgrade -y && \
apt-get install -y language-pack-en git-core gunicorn wget  && \
apt-get install -y nodejs npm openssh-server openjdk-6-jdk solr-tomcat && \
apt-get install -y python-dev postgresql libpq-dev python-pip python-virtualenv && \
apt-get clean && rm -r /var/lib/apt/lists/*
                            
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

RUN mkdir /usr/java && ln -s /usr/lib/jvm/java-7-openjdk-amd64 /usr/java/default
         
# And the confusion b/t node and nodejs is crazy .. .
RUN cp /usr/bin/nodejs /usr/bin/node
RUN npm install less nodewatch 

# Arg, pip is broken on 14.04 .. 

WORKDIR /tmp
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

##
## Installing CKAN
##

RUN mkdir -p /opt/ckan
WORKDIR /opt/ckan 

#RUN pip install -e 'git+https://github.com/okfn/ckan.git@ckan-2.5.2#egg=ckan'
RUN pip install -e 'git+https://github.com/okfn/ckan.git@ckan-2.5.5#egg=ckan'

RUN pip install -r /opt/ckan/src/ckan/requirements.txt

RUN pip install gevent

RUN mkdir -p /etc/ckan/default

RUN chown -R `whoami` /etc/ckan/

RUN ln -s /opt/ckan/src/ckan/who.ini  /etc/ckan/default/who.ini

RUN cp  /opt/ckan/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml 

##
## Install Postgis
##


#RUN echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/9.3/main/pg_hba.conf
#RUN service postgresql start && \
#    /bin/su postgres -c "createuser -d -s -r -l ckan" && \
#    /bin/su postgres -c "psql postgres -c \"ALTER USER ckan WITH ENCRYPTED PASSWORD 'ckan'\"" && \
#    /bin/su postgres -c "createdb --template template0 -O ckan ckan -E utf-8" && \
#    service postgresql stop
    
#RUN echo "listen_addresses = '*'" >> /etc/postgresql/9.3/main/postgresql.conf
#RUN echo "port = 5432" >> /etc/postgresql/9.3/main/postgresql.conf

RUN service postgresql start && \
    /bin/su postgres -c "createuser -S -D -R ckan" && \
    /bin/su postgres -c "psql postgres -c \"ALTER USER ckan WITH ENCRYPTED PASSWORD 'ckan'\"" && \
    /bin/su postgres -c "createuser -S -D -R ckands" && \
    /bin/su postgres -c "psql postgres -c \"ALTER USER ckands WITH ENCRYPTED PASSWORD 'ckands'\"" && \
    /bin/su postgres -c "createdb --template template0 -O ckan ckan -E utf-8" && \
    /bin/su postgres -c "createdb --template template0 -O ckan ckands -E utf-8" && \
    service postgresql stop
##
## Expose and run
##

# For flagging runtime-initialization completed. 
RUN mkdir /var/run/initialized

RUN mkdir /data

VOLUME /data
VOLUME /opt

# Tomcat / solr
EXPOSE 8080 

# Postgres
EXPOSE 5432 

# CKAN Production
EXPOSE 80

# CKAN Development
EXPOSE 5000

# For SSH, but must be started by setting $SSH envvar to root password
EXPOSE 22

ADD start-ckan.sh /opt/ckan/src/ckan/

# Late in file because it changes a lot. 
ADD production.ini /etc/ckan/default/production.ini
ADD production.ini /etc/ckan/default/development.ini

# Setup the default config file ( it's a copy of the production file ) so you don't 
# have to set it with the paster admin commands. 
ENV CKAN_INI /etc/ckan/default/development.ini

WORKDIR /opt/ckan/src/ckan

# easier than creating a theme plugin

ONBUILD ADD promoted.html /opt/ckan/src/ckan/ckan/templates/home/snippets/promoted.html 

ONBUILD ADD database.sql /opt/ckan/src/ckan/dump.db


ONBUILD RUN service tomcat6 start ; \
    service postgresql start && \
    paster --plugin=ckan db clean --config=/etc/ckan/default/production.ini && \
    paster --plugin=ckan db load /opt/ckan/src/ckan/dump.db  --config=/etc/ckan/default/production.ini && \
    paster --plugin=ckan db init --config=/etc/ckan/default/production.ini && \
    paster --plugin=ckan datastore set-permissions  -c /etc/ckan/default/production.ini | /bin/su postgres -c 'psql --set ON_ERROR_STOP=1' && \
    service postgresql stop && \
    service tomcat6 stop

CMD sh start-ckan.sh
