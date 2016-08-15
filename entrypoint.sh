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
	printf "\n${GREEN}HELP:\n"
	printf "\t${RED}start${GREEN} - \n"
	printf "\t${RED}generate-ca${GREEN} - \n"
	printf "\t${RED}generate-servercert${GREEN} - \n"
	printf "\t${RED}generate-clientcert${GREEN} - \n"
	printf "\t${RED}create-dh${GREEN} - \n"
	printf "\t${RED}get-clientcfg${GREEN} - \n"
	printf "\t${RED}help${GREEN} - This help ;)\n"


	printf "\n${GREEN}VARIABLES:\n"
	printf "\t${RED}CANAME${GREEN} - (defaults to 'OPENVPN_SelfSigned'). Used for creating CA (generate-ca) and for sign server and client certificates.\n"
	printf "\t${RED}LOCATION${GREEN} - (defaults to 'ES:HOME:HOME'). Location with the following notation 'COUNTRY:LOCATION:ORGANIZATION' needed for CA and Server and Client Certificates Generation.\n"
	printf "\t${RED}PASSPHRASE${GREEN} - Used for creating CA (generate-ca) and for sign server and client certificates.\n"
	printf "\tIf you want to be asked for passwrod, leave empty and run container in interactive mode (-ti).\n"
	printf "\t${RED}DATA${GREEN} - (defaults to container's /DATA) This volume will be used for storing  openvpn runtime data and certificates.\n"
	printf "\tYou can choose one dir of your host if you want, but keep safe this data as it will store ca.key and server.key,\n"
	printf "\tOpenVPN server configuration as well as all client certificates.\n"
	printf "\t${RED}CONFDIR${GREEN} - (defaults to container's /CONF) This directory has all templates for creating certificates and configurations.\n"
	printf "\tYou can choose one dir of your host with all needed configuration files and generation of certificates and OpenVPN Server execution\n"
	printf "\twill avoid default values (use if you don't want use many variables to defineyour service).\n"
	printf "\t${RED}SERVERNAME${GREEN} - (defaults to 'server') This is the name that will be used as 'distinguished_name' and 'commonName' for server certificates generation.\n"
	printf "\t${RED}CLIENTNAME${GREEN} - (defaults to 'client') This is the name that will be used as 'distinguished_name' and 'commonName' for client certificates generation.\n"
	printf "\tUse as many many client names as you wish if you want to have different configurations for each client.\n"
	printf "\t${RED}DNS${GREEN} - (defaults to '8.8.8.8') This is the DNS that will be injected to you clients for VPN connection.\n"
	printf "\t${RED}NETWORKS${GREEN} - (NEEDED VARIABLE FOR STARTING OPENVPN) These variable will contain all networks that must be routed through VPN.\n"
	printf "\tUse CIDR NetworkIP/NetworkMask notation and use 'space' as delimiter (example: '192.168.1.0/24 10.0.0.0/16' ).\n"
	printf "\t${RED}VPNSERVER${GREEN} - (defaults to your public ip) This variable will be the IP or FQDN reacheable for clients to connect to your OpenVPN Server.\n"


	printf "\n${GREEN}USAGE WORKFLOW (example will use volume 'openvpn'):\n"
	printf "\t${RED}Create CA${GREEN} (for auto-sign certificates).\n"
	printf "\t\t${CYAN}RUN: docker run --rm -e 'PASSPHRASE=YourSecuredPassphrase' -e 'CANAME=JustForOpenVPN' -v openvpn:/DATA openvpn create-ca ${NC}\n"
	printf "\t${RED}Create Server Certificate${GREEN} (auto-signed by your own CA).\n"
	printf "\t\t${CYAN}RUN: docker run --rm -e 'PASSPHRASE=YourSecuredPassphrase' -e 'SERVERNAME=MyOpenVPNServer'-v openvpn:/DATA openvpn create-servercert\n"
	printf "\t${RED}Create Client's Certificates${GREEN} (auto-signed by your own CA).\n"
	printf "\t\t${CYAN}RUN: docker run --rm -e 'PASSPHRASE=YourSecuredPassphrase' -e 'CLIENTNAME=FirstClient'-v openvpn:/DATA openvpn create-clientcert\n"
	printf "\t${RED}Start OpenVPN Server${GREEN} (****Note that you are using NET_ADMIN privileges and your host network on container***).\n"
	printf "\t\t${CYAN}RUN: docker run --cap-add=NET_ADMIN --net=host --rm  --name openvpn -e 'DNS=8.8.4.4' -e 'NETWORKS=192.168.1.0/24 10.0.0.0/16' -v openvpn:/DATA openvpn start\n"
	printf "\t${RED}Get Your Client's Files${GREEN} (You will mount a host directory in OpenVPN Server container for accessing your files (password protected zip file) in SAVECFG).\n"
	printf "\t\t${CYAN}RUN: docker run --rm -v openvpn:/DATA -e 'CLIENTNAME=MyUser' -e 'SAVECFG=/tmp' -v /home/MyUser:/tmp openvpn get-clientcfg\n"

	printf "${NC}\n"
}



CreateCA(){
  [ ! -d ${DATA}/ca ] && mkdir -p ${DATA}/ca

  touch ${DATA}/ca/index.txt

  CANAME=${CANAME:=OPENVPN_SelfSigned}

  
  LOCATION=${LOCATION:=ES:HOME:HOME}

  #COUNTRY:LOCATION:ORGANIZATION
  COUNTRY="$(echo ${LOCATION}|cut -d ":" -f1)"
  LOCATION="$(echo ${LOCATION}|cut -d ":" -f2)"
  ORGANIZATION="$(echo ${LOCATION}|cut -d ":" -f3)"

  [ ! -d ${DATA}/conf ] && mkdir -p ${DATA}/conf

  sed -e "s/__CANAME__/${CANAME}/g" ${CONFDIR}/ca.cnf >${DATA}/conf/ca.cnf

  
  sed -i "s/__COUNTRY__/${COUNTRY}/g" ${DATA}/conf/ca.cnf
  sed -i "s/__LOCATION__/${LOCATION}/g" ${DATA}/conf/ca.cnf
  sed -i "s/__ORGANIZATION__/${ORGANIZATION}/g" ${DATA}/conf/ca.cnf


  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passout pass:${PASSPHRASE} "

  openssl req -new \
    -config ${DATA}/conf/ca.cnf  \
    ${PASSPOPTS} \
    -keyout ${DATA}/ca/ca.key \
    -out ${DATA}/ca/ca.req

  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  cp ${CONFDIR}/ca-sign.cnf ${DATA}/conf/ca-sign.cnf

  openssl ca -batch \
    -config ${DATA}/conf/ca-sign.cnf  \
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

  LOCATION=${LOCATION:=ES:HOME:HOME}

  #COUNTRY:LOCATION:ORGANIZATION
  COUNTRY="$(echo ${LOCATION}|cut -d ":" -f1)"
  LOCATION="$(echo ${LOCATION}|cut -d ":" -f2)"
  ORGANIZATION="$(echo ${LOCATION}|cut -d ":" -f3)"

  [ ! -d ${DATA}/conf ] && mkdir -p ${DATA}/conf

  sed -e "s/__SERVERNAME__/${SERVERNAME}/g" ${CONFDIR}/server.cnf >${DATA}/conf/server.cnf


  sed -i "s/__COUNTRY__/${COUNTRY}/g" ${DATA}/conf/server.cnf
  sed -i "s/__LOCATION__/${LOCATION}/g" ${DATA}/conf/server.cnf
  sed -i "s/__ORGANIZATION__/${ORGANIZATION}/g" ${DATA}/conf/server.cnf



  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/server ] && mkdir -p ${DATA}/server

  cp -p ${DATA}/ca/ca.crt ${DATA}/server

  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  openssl req -new \
    -config ${DATA}/conf/server.cnf \
    ${PASSPOPTS} \
    -keyout ${DATA}/server/server.key \
    -out ${DATA}/server/server.req

  chmod 400 ${DATA}/server/server.key

  openssl ca  -batch \
    -config ${DATA}/conf/ca-sign.cnf \
    -extensions X509_server \
    ${PASSPOPTS} \
    -in ${DATA}/server/server.req \
    -out ${DATA}/server/server.crt

  chmod 444 ${DATA}/server/server.crt

  rm -f ${DATA}/server/server.req

}

CreateClientCert(){

  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/clients/${CLIENTNAME} ] && mkdir -p ${DATA}/clients/${CLIENTNAME}


  CLIENTNAME=${CLIENTNAME:=client}
  LOCATION=${LOCATION:=ES:HOME:HOME}

  #COUNTRY:LOCATION:ORGANIZATION
  COUNTRY="$(echo ${LOCATION}|cut -d ":" -f1)"
  LOCATION="$(echo ${LOCATION}|cut -d ":" -f2)"
  ORGANIZATION="$(echo ${LOCATION}|cut -d ":" -f3)"

  [ ! -d ${DATA}/conf ] && mkdir -p ${DATA}/conf

  sed -e "s/__CLIENTNAME__/${CLIENTNAME}/g" ${CONFDIR}/client.cnf >${DATA}/conf/client.cnf

  sed -i "s/__COUNTRY__/${COUNTRY}/g" ${DATA}/conf/client.cnf
  sed -i "s/__LOCATION__/${LOCATION}/g" ${DATA}/conf/client.cnf
  sed -i "s/__ORGANIZATION__/${ORGANIZATION}/g" ${DATA}/conf/client.cnf




  [ -n "${PASSPHRASE}" ]  && PASSPOPTS="-passin pass:${PASSPHRASE}"

  openssl req -new \
    -config ${DATA}/conf/client.cnf \
    ${PASSPOPTS} \
    -keyout ${DATA}/clients/${CLIENTNAME}/client.key \
    -out ${DATA}/clients/${CLIENTNAME}/client.req

  chmod 400 ${DATA}/clients/${CLIENTNAME}/client.key

  openssl ca  -batch \
    -config ${DATA}/conf/ca-sign.cnf \
    ${PASSPOPTS} \
    -in ${DATA}/clients/${CLIENTNAME}/client.req \
    -out ${DATA}/clients/${CLIENTNAME}/client.crt

  chmod 444 ${DATA}/clients/${CLIENTNAME}/client.crt

  rm -f ${DATA}/clients/${CLIENTNAME}/client.req

  rm -f ${DATA}/conf/client.cnf
}

CreateDH(){

  [ ! -d ${DATA}/ca ] && ErrorMessage "Can not find ca.crt, please use 'create-ca' or add your ca.crt in ${DATA}/ca dir."

  [ ! -d ${DATA}/openvpn ] && mkdir -p ${DATA}/openvpn

  openssl dhparam -rand /dev/urandom -out ${DATA}/openvpn/dh2048.pem 2048

}

StartOpenVPN(){

	DNS=${DNS:=8.8.8.8}

	[ ! -n "${NETWORKS}" ] && ErrorMessage "At least you must add one network to route or you will be living in an island ;P ."



	needed_files="${DATA}/server/server.crt ${DATA}/server/server.key ${DATA}/ca/ca.crt"

	for file in ${needed_files}
	do
		[ ! -f ${file} ] && ErrorMessage "Can not find ${file}, OpenVPN Server can not start."
	done

	[ ! -f ${DATA}/openvpn/dh2048.pem ] && CreateDH

	mkdir -p /dev/net

	mknod /dev/net/tun c 10 200

	ln -s /dev/stdout /var/log/openvpn.log

	ln -s /dev/stdout /var/log/openvpn-status.log

	if [ ! -f ${DATA}/conf/openvpn.conf ]
	then

		sed -e "s/__DATA__/\\${DATA}/g" ${CONFDIR}/openvpn.conf >${DATA}/conf/openvpn.conf

		sed -i "s/__DNS__/${DNS}/g" ${DATA}/conf/openvpn.conf

		nets=0

		#NETWORKS="$(echo "${NETWORKS}"|sed -e "s/ /@/g")"
		#NETWORKS="$(echo "${NETWORKS}"|sed -e "s/;/ /g")"

		for net in ${NETWORKS}
		do
			[ $(echo ${net}|grep -c "/") -ne 1 ] && InfoMessage "Can not add ${net} route, please use CIDR notation NETIP/MASK." && continue
			IpCalc "$net"
			echo "push \"route ${route}\"" >>${DATA}/conf/openvpn.conf
			nets=$(( ${nets} + 1 ))
		done

		[ ${nets} -eq 0 ] && ErrorMessage "At least you must add one network to route or you will be living in an island ;P ."

	fi

	## Start OpenVPN Server !!!
	/usr/sbin/openvpn --config ${DATA}/conf/openvpn.conf

}

IpCalc(){
	route=""
	ipcalc -v 2>/dev/null && route="$(ipcalc ${net}|awk '/Address/ || /Netmask/ { printf "%s ", $2 }')"  && return

	# Raspberry busybox version
	#  ipcalc -nm 192.168.1.0/24
	#NETMASK=255.255.255.0
	#NETWORK=192.168.1.0
	network="$(ipcalc -n ${net}|cut -d "=" -f2)"
	netmask="$(ipcalc -m ${net}|cut -d "=" -f2)"
	route="$(echo ${network} ${netmask})"


}

GetClientCfg(){
	[ ! -d ${DATA}/clients/${CLIENTNAME} ] && ErrorMessage "Can not find client config, please use 'create-clientcert'."

	[ ! -n "${SAVECFG}" ] && ErrorMessage "You must specify 'SAVECFG' variable for using a volume mapped to your filesystem."

	rm -rf ${SAVECFG}/client 2>/dev/null
	
	mkdir ${SAVECFG}/client 2>/dev/null

	cp -R ${DATA}/clients/${CLIENTNAME}/* ${SAVECFG}/client

	cp ${DATA}/ca/ca.crt ${SAVECFG}/client

	PUBLICIP="$(curl -s http://ipinfo.io/ip)"

	VPNSERVER=${VPNSERVER:=${PUBLICIP}}

	sed -e "s/__VPNSERVER__/${VPNSERVER}/g" ${CONFDIR}/openvpn-client.conf >${SAVECFG}/client/openvpn-client.conf

	random_zip_password="$(openssl rand -base64 6)"

	chmod 755 ${SAVECFG}/client/*

	zip --password "${random_zip_password}" -9 ${SAVECFG}/client.zip ${SAVECFG}/client/*

	InfoMessage "A password protected zip file with ca.crt, client.key, client.crt and openvpn-client.conf has been created for you in ${SAVECFG} volume."
	InfoMessage "Password for ${SAVECFG}/client.zip is '${random_zip_password}'."
	InfoMessage "Take your ${SAVECFG}/client.zip to a safe storage and delete it from volume/host filesystem."

	rm -rf ${SAVECFG}/client
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
    CreateDH
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
