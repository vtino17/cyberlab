/ip firewall filter
add chain=input connection-state=invalid action=drop
add chain=input connection-state=established action=accept
add chain=input connection-state=related action=accept
add chain=input protocol=tcp dst-port=22 src-address-list=mgmt-hosts action=accept
add chain=input action=drop

/ip firewall nat
add chain=srcnat out-interface=pppoe-out action=masquerade
