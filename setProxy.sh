#!/bin/bash

oracle_proxy=http://www-proxy-ams.nl.oracle.com:80
bastion_proxy=socks5://127.0.0.1:20000

if [[ "$1" == "oracle" ]]; then
    echo "Set ORACLE Proxy"
    export http_proxy=$oracle_proxy
    export https_proxy=$oracle_proxy
else
    echo "Set BASTION Proxy"
    export http_proxy=$bastion_proxy
    export https_proxy=$bastion_proxy
fi
