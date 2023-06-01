#!/bin/bash

bastion_sessions_list=$(oci bastion session list --bastion-id ocid1.bastion.oc1.eu-milan-1.amaaaaaajaynoiyamxctl4uppewemroor5n2wfevbzhhbumniphsj2s773zq --session-lifecycle-state ACTIVE)
bastion_session_id=$(echo "$bastion_sessions_list" | jq -r '.data[0].id')
#echo $bastion_session_id
bastion_session=$(oci bastion session get --session-id $bastion_session_id)
#echo $bastion_session
bastion_session_command=$(echo "$bastion_session" | jq -r '.data."ssh-metadata"."command"')
#echo $bastion_session_command
to_replace="ssh -i <privateKey> -N -D 127.0.0.1:<localPort> -p 22"
replace="ssh -i bastion_GC3_sshkey -o \"ProxyCommand=nc -X connect -x www-proxy-ams.nl.oracle.com:80 %h %p\"  -N -D 127.0.0.1:20000 -p 22"
echo -e "Use this bastion proxy socks5\n"
echo $bastion_session_command | sed -e "s/${to_replace}/${replace}/g"
