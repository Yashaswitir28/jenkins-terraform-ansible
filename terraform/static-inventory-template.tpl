cat << EOF >> ../static_inventory
[amazon_linux]
%{ for ip in amazon ~}
${ip}
%{ endfor ~}

[ubuntu]
%{ for ip in ubuntu ~}
${ip}
%{ endfor ~}

[linux:children]
amazon_linux
ubuntu

EOF