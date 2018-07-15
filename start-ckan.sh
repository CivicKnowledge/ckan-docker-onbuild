
##
## Postgres
## 

service postgresql start
pg_pid=$!


##
## Solr
###

service tomcat6 start
solr_pid=$!

##
## CKAN 
##

config=/etc/ckan/default/production.ini

## Expects to be called with these envvars set
##  ADMIN_USER_PASS
##  ADMIN_USER_EMAIL
##  ADMIN_USER_KEY
##  SITE_URL

if [ ! -f '/var/run/ckan-initialized' ]; then
  echo "Initializing on first run"
  app_id=$(cat /proc/sys/kernel/random/uuid) 
  sed -i "s/app_instance_uuid.*/app_instance_uuid = $app_id/"  $config
  sed -i "s/ckan.site_url.*/ckan.site_url = http:\/\/$SITE_URL/"  $config

  session_secret=$(cat /proc/sys/kernel/random/uuid) 
  sed -i "s/beaker.session.secret.*/beaker.session.secret = $session_secret/"  $config
  
  echo "Creating User: username=$ADMIN_USER_NAME apikey=$ADMIN_USER_KEY"
  
  paster user add $ADMIN_USER_NAME apikey=$ADMIN_USER_KEY password=$ADMIN_USER_PASS email=$ADMIN_USER_EMAIL -c $config 
  paster sysadmin add $ADMIN_USER_NAME -c $config 
  touch  /var/run/ckan-initialized
  
  cp $config /etc/ckan/default/development.ini
  sed -i "s/debug.*/debug = true/"  /etc/ckan/default/development.ini
  
  # THis is supposed to be done in the Dockerfile, but it doesn't work. 
  # the 'less' command fails without running it again. 
  npm install less nodewatch
else
  echo "Skipping Initlization; already run"
fi



if [ ! -z "$SSH" ]; then
    # From http://docs.docker.com/examples/running_ssh_service/#build-an-eg_sshd-image
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    echo "root:$SSH" | chpasswd
    service ssh start
    
    ckpaster () { /usr/local/bin/paster --plugin=ckan $@  -c /etc/ckan/default/development.ini; }
fi
    
if [ -z "$DEBUG" ]; then
  gunicorn_paster --debug -b :80 --worker-class gevent -w 5 $config &
  ckan_pid=$!
else
  ./bin/less &
  paster serve --reload /etc/ckan/default/development.ini
fi


wait $ckan_pid
wait $solr_pid
wait $pg_pid