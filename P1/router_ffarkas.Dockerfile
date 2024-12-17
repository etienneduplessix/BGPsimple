FROM frrouting/frr:latest

RUN apk update && apk upgrade

RUN apk add --no-cache busybox

COPY ./config/vtysh /etc/frr/vtysh.conf

COPY ./config/daemons /etc/frr/daemons
