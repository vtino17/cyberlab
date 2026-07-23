/interface bridge
add name=bridge-local vlan-filtering=yes

/interface bridge port
add bridge=bridge-local interface=ether2
add bridge=bridge-local interface=ether3

/interface vlan
add name=vlan-mgmt vlan-id=10 interface=bridge-local
add name=vlan-server vlan-id=20 interface=bridge-local
add name=vlan-iot vlan-id=30 interface=bridge-local
add name=vlan-guest vlan-id=40 interface=bridge-local

/ip address
add address=10.0.10.1/24 interface=vlan-mgmt
add address=10.0.20.1/24 interface=vlan-server
add address=10.0.30.1/24 interface=vlan-iot
add address=10.0.40.1/24 interface=vlan-guest
