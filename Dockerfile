FROM alpine

MAINTAINER frjaraur@gmail.com

# Just for debugging and Developing

ENV DATA=/DATA CONFDIR=/CONF

RUN addgroup -g 1000 openvpn && adduser -H -G openvpn -u 1000 -D openvpn

RUN apk --update --no-progress --no-cache add curl openvpn openssl zip && \
  mkdir -p ${DATA}/conf

ADD conf ${CONFDIR}

ADD entrypoint.sh /entrypoint.sh

EXPOSE 1194 1194/udp

WORKDIR ${DATA}

VOLUME ["${DATA}"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]
