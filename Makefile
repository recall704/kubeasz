


IMG_KUBEASZ=easzlab/kubeasz:3.2.0


docker-build:
	docker build -t ${IMG_KUBEASZ}-sshpass .

docker-it:
	- docker run --rm -it \
		--name kubeasz \
		--network host \
		-e ANSIBLE_CONFIG="/etc/kubeasz/ansible.cfg" \
		-v ${PWD}:/etc/kubeasz \
		-v /root/.kube:/root/.kube \
		-w /etc/kubeasz \
		${IMG_KUBEASZ}-sshpass /bin/bash
