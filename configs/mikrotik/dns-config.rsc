/ip dns
set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes cache-size=4096

/ip dns static
add name=wazuh.internal address=10.0.20.5
add name=grafana.internal address=10.0.20.11
add name=prometheus.internal address=10.0.20.10
