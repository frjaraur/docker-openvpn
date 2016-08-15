build:
	docker build -t openvpn .

build-rpi:
	docker build -t openvpn -f Dockerfile.rpi .

clean:
	docker rm -fv openvpn
shell:
	make clean
	#docker run -ti --name openvpn -v ${PWD}/DATA:/DATA openvpn sh
	docker run -ti --name openvpn -e "PASSPHRASE=test" openvpn sh

start:
	make build-rpi
	make clean || echo
	docker volume rm openvpn || echo
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-ca
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-servercert
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-dh
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-clientcert
	docker run -ti --rm --name openvpn --cap-add=NET_ADMIN --net=host -v openvpn:/DATA openvpn start
	#docker run -ti --name openvpn -e "PASSPHRASE=test" -v openvpn:/DATA openvpn sh

test:
	make build-rpi
	make clean || echo
	docker volume rm openvpn || echo
	docker run --rm -e 'PASSPHRASE=0T03050T0' -e 'CANAME=JustForOpenVPN' -v openvpn:/DATA openvpn create-ca 
	docker run --rm -e 'PASSPHRASE=0T03050T0' -e 'SERVERNAME=openvpn' -v openvpn:/DATA openvpn create-servercert
	docker run --rm -e 'PASSPHRASE=0T03050T0' -e 'CLIENTNAME=android' -v openvpn:/DATA openvpn create-clientcert
	docker run --rm -v openvpn:/DATA -e 'CLIENTNAME=android' -e 'SAVECFG=/tmp' -v /tmp:/tmp openvpn get-clientcfg
	docker run --cap-add=NET_ADMIN --net=host --rm  --name openvpn -e 'DNS=8.8.4.4' -e 'NETWORKS=192.168.1.0/24' -v openvpn:/DATA openvpn start

