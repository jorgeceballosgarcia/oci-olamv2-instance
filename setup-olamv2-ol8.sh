#!/bin/bash

main_function() {

set -x

USER_AWX='awx'

# resize boot volume
/usr/libexec/oci-growfs -y 

# update packages
# dnf update -y

# Enable the Oracle Linux DNF Repository and Set the Firewall Rules 

dnf config-manager --enable ol8_baseos_latest
dnf -y install oraclelinux-automation-manager-release-el8

dnf config-manager --disable ol8_automation
dnf config-manager --enable ol8_automation2 ol8_addons ol8_UEKR7 ol8_appstream

firewall-cmd --add-service=https --permanent
firewall-cmd --reload

# Install a Local Postgresql Database

dnf module reset postgresql
dnf -y module enable postgresql:13

dnf -y install postgresql-server

postgresql-setup --initdb

sed -i "s/#password_encryption.*/password_encryption = scram-sha-256/" /var/lib/pgsql/data/postgresql.conf

systemctl enable --now postgresql

su - postgres -c "createuser -S awx"

su - postgres -c "createdb -O awx awx"

su - postgres -c "psql -d awx -c \"alter user awx with encrypted password 'Welcome1#'\""

su - postgres -c "psql -d awx -c \"grant all privileges on database awx to awx\""

echo "host  all  all 0.0.0.0/0 scram-sha-256" | tee -a /var/lib/pgsql/data/pg_hba.conf > /dev/null

sed -i "/^#port = 5432/i listen_addresses = '"$(hostname -i)"'" /var/lib/pgsql/data/postgresql.conf

systemctl restart postgresql

# Install and Configure Oracle Linux Automation Manager

dnf -y install ol-automation-manager

sed -i '/^# unixsocketperm/a unixsocket /var/run/redis/redis.sock\nunixsocketperm 775' /etc/redis.conf

cat << EOF | tee -a /etc/tower/conf.d/olam.py > /dev/null
CLUSTER_HOST_ID = '$(hostname -i)'
EOF

chown awx.awx /etc/tower/conf.d/olam.py
chmod 0640 /etc/tower/conf.d/olam.py

cat << EOF | tee /etc/tower/conf.d/db.py > /dev/null
DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'awx.main.db.profiled_pg',
        'NAME': 'awx',
        'USER': 'awx',
        'PASSWORD': 'Welcome1#',
        'HOST': '$(hostname -i)',
        'PORT': '5432',
    }
}
EOF

chown awx.awx /etc/tower/conf.d/db.py
chmod 0640 /etc/tower/conf.d/db.py

#su -l awx -s /bin/bash
su -l awx -s /bin/bash -c "podman system migrate"
su -l awx -s /bin/bash -c "podman pull container-registry.oracle.com/oracle_linux_automation_manager/olam-ee:latest"

su -l awx -s /bin/bash -c "awx-manage migrate"
su -l awx -s /bin/bash -c "awx-manage createsuperuser --username admin --no-input --email admin@oracle.com" 
su -l awx -s /bin/bash -c "awx-manage update_password --username=admin --password=Welcome1#"
#exit

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=ES/ST=Madrid/L=Madrid/O=OCS/CN=www.oracle.com" -keyout /etc/tower/tower.key -out /etc/tower/tower.crt

cat << EOF | tee /etc/nginx/nginx.conf > /dev/null
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF

cat << EOF | tee /etc/receptor/receptor.conf > /dev/null
---
- node:
    id: $(hostname -i)

- log-level: debug

- tcp-listener:
    port: 27199

- control-service:
    service: control
    filename: /var/run/receptor/receptor.sock

- work-command:
    worktype: local
    command: /var/lib/ol-automation-manager/venv/awx/bin/ansible-runner
    params: worker
    allowruntimeparams: true
    verifysignature: false
EOF

#su -l awx -s /bin/bash
su -l awx -s /bin/bash -c "awx-manage provision_instance --hostname=$(hostname -i) --node_type=hybrid"
su -l awx -s /bin/bash -c "awx-manage register_default_execution_environments"
su -l awx -s /bin/bash -c "awx-manage register_queue --queuename=default --hostnames=$(hostname -i)"
su -l awx -s /bin/bash -c "awx-manage register_queue --queuename=controlplane --hostnames=$(hostname -i)"
#su -l awx -s /bin/bash -c "awx-manage create_preload_data"
#exit

systemctl enable --now ol-automation-manager.service

set +x

}

main_function 2>&1 >> /var/log/olamv2_install.log

