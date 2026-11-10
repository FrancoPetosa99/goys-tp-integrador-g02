FROM alpine:3.24.4

RUN apk add --no-cache iproute2 iptables

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY firewall.sh /usr/local/bin/firewall.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/firewall.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
