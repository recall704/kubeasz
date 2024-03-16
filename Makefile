


IMG_KUBEASZ=easzlab/kubeasz:3.2.0

docker-it:
	- docker run --rm -it \
		--name kubeasz \
		--network host \
		-v ${PWD}:/etc/kubeasz \
		-v /root/.kube:/root/.kube \
		-v /root/.ssh:/root/.ssh \
		-w /etc/kubeasz \
		${IMG_KUBEASZ} /bin/bash
