build:
	docker build -t openvpn .

clean:
	docker rm -fv openvpn
shell:
	make clean
	#docker run -ti --name openvpn -v ${PWD}/DATA:/DATA openvpn sh
	docker run -ti --name openvpn -e "PASSPHRASE=test" openvpn sh

start:
	make clean || echo
	docker volume rm openvpn || echo
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-ca
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-servercert
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-dh
	docker run --rm -e "PASSPHRASE=test" -v openvpn:/DATA openvpn create-clientcert
	docker run -ti --rm --name openvpn --cap-add=NET_ADMIN --net=host -v openvpn:/DATA openvpn start
	#docker run -ti --name openvpn -e "PASSPHRASE=test" -v openvpn:/DATA openvpn sh
