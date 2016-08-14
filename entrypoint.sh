#!/bin/sh -x

ACTION="$(echo $1|tr '[A-Z]' '[a-z]')"

# COLORS
RED='\033[0;31m' # Red
BLUE='\033[0;34m' # Blue
GREEN='\033[0;32m' # Green
CYAN='\033[0;36m' # Cyan
NC='\033[0m' # No Color

ErrorMessage(){
	printf "${RED}ERROR: $* ${NC}\n"
	exit 1
}

InfoMessage(){
	printf "${CYAN}INFO: $* ${NC}\n"
}

Help(){
	printf "${GREEN}HELP:\n"
	printf "\t${RED}start${GREEN} - \n"
	printf "\t${RED}generate-ca${GREEN} - \n"
	printf "\t${RED}generate-servercert${GREEN} - \n"
	printf "\t${RED}generate-clientcert${GREEN} - \n"
	printf "\t${RED}create-dh${GREEN} - \n"
	printf "\t${RED}get-clientcfg${GREEN} - \n"
	printf "\t${RED}help${GREEN} - This help ;)\n"


	printf "${NC}\n"
}



CreateCA(){
  [ ! -d ${DATA}/ca ] && mkdir -p ${DATA}/ca

  touch ${DATA}/ca/index.txt

  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passout pass:${PASSPHRASE} "

  openssl req -new \
    -config ${CONFDIR}/ca.cnf  \
    ${PASSPOPTS} \
    -keyout ${DATA}/ca/ca.key \
    -out ${DATA}/ca/ca.req

  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  openssl ca -batch \
    -config ${CONFDIR}/ca-sign.cnf  \
    ${PASSPOPTS} \
    -extensions X509_ca \
    -days 3650  \
    -create_serial -selfsign \
    -keyfile ${DATA}/ca/ca.key \
    -in ${DATA}/ca/ca.req \
    -out ${DATA}/ca/ca.crt

  chmod 400 ${DATA}/ca/ca.key

  chmod 444 ${DATA}/ca/ca.crt

	rm -f ${DATA}/ca/ca.req
}

CreateServerCert(){

  SERVERNAME=${SERVERNAME:=server}

  sed -e "s/__SERVERNAME__/${SERVERNAME}/g" ${CONFDIR}/server.cnf >${DATA}/conf/server.cnf


  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/server ] && mkdir -p ${DATA}/server

  cp -p ${DATA}/ca/ca.crt ${DATA}/server

  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  openssl req -new \
    -config ${CONFDIR}/server.cnf \
    ${PASSPOPTS} \
    -keyout ${DATA}/server/server.key \
    -out ${DATA}/server/server.req

  chmod 400 ${DATA}/server/server.key

  openssl ca  -batch \
    -config ${CONFDIR}/ca-sign.cnf \
    -extensions X509_server \
    ${PASSPOPTS} \
    -in ${DATA}/server/server.req \
    -out ${DATA}/server/server.crt

  chmod 444 ${DATA}/server/server.crt

	rm -f ${DATA}/server/server.req

}

CreateClientCert(){

  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/client ] && mkdir -p ${DATA}/client


  CLIENTNAME=${CLIENTNAME:=client}

  sed -e "s/__CLIENTNAME__/${CLIENTNAME}/g" ${CONFDIR}/client.cnf >${DATA}/conf/client.cnf


  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  openssl req -new \
    -config ${CONFDIR}/client.cnf \
    ${PASSPOPTS} \
    -keyout ${DATA}/client/client.key \
    -out ${DATA}/client/client.req

  chmod 400 ${DATA}/client/client.key

  openssl ca  -batch \
    -config ${CONFDIR}/ca-sign.cnf \
    ${PASSPOPTS} \
    -in ${DATA}/client/client.req \
    -out ${DATA}/client/client.crt

  chmod 444 ${DATA}/client/client.crt

	rm -f ${DATA}/client/client.req

}

CreateDH(){

  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/server ] && mkdir -p ${DATA}/server

  openssl dhparam -out ${DATA}/server/dh2048.pem 2048

}

StartOpenVPN(){
	mkdir -p /dev/net
	mknod /dev/net/tun c 10 200


	ln -s /dev/stdout /var/log/openvpn.log
	ln -s /dev/stdout /var/log/openvpn-status.log

#	/usr/sbin/openvpn --config /DATA/conf/openvpn.conf --key /DATA/server/server.key

	sed -e "s/__DATA__/\\${DATA}/g" ${CONFDIR}/openvpn.conf >${DATA}/conf/openvpn.conf

	/usr/sbin/openvpn --config ${DATA}/conf/openvpn.conf
}


GetClientCfg(){
	[ ! -d ${DATA}/client ] && ErrorMessage "Can not find client config, please use 'create-clientcert'."

	[ ! -n ${SAVECFG} ] && ErrorMessage "You must specify 'SAVECFG' variable for using a volume mapped to your filesystem."

	cp -R ${DATA}/client ${SAVECFG}
	cp ${DATA}/ca/ca.crt ${SAVECFG}

	PUBLICIP="$(curl http://ipinfo.io/ip)"

	VPNSERVER=${VPNSERVER:=${PUBLICIP}}

	sed -e "s/__VPNSERVER__/${VPNSERVER}/g" ${CONFDIR}/openvpn-client.cfg >${SAVECFG}/openvpn-client.cfg

}



case $ACTION in

  start)
		StartOpenVPN
  ;;

  create-ca)
    CreateCA

  ;;

  create-servercert)
    CreateServerCert
  ;;

  create-clientcert)
    CreateClientCert
  ;;

  create-dh)
		[ ! -d ${DATA}/openvpn ] && mkdir -p ${DATA}/openvpn
	  openssl dhparam -out ${DATA}/openvpn/dh2048.pem 2048
  ;;

	get-clientcfg)
		GetClientCfg
  ;;

  help)
		Help
  ;;


  *)
    exec "$@"

  ;;

esac
