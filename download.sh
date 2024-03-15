DOCKER_VER=20.10.9
KUBEASZ_VER=3.2.0
K8S_BIN_VER=v1.23.1
EXT_BIN_VER=1.0.0
SYS_PKG_VER=0.4.2
HARBOR_VER=v2.1.3
REGISTRY_MIRROR=CN

# images needed by k8s cluster
calicoVer=v3.19.3
flannelVer=v0.15.1
dnsNodeCacheVer=1.21.1
corednsVer=1.8.6
dashboardVer=v2.4.0
dashboardMetricsScraperVer=v1.0.7
metricsVer=v0.5.2
pauseVer=3.6
nfsProvisionerVer=v4.0.2

# BASE 为当前脚本所在目录
BASE=$(cd "$(dirname "$0")" && pwd)

function get_offline_image() {
    imageDir="$BASE/down"
    mkdir -p "$imageDir"
    logger info "downloading offline images"

    if [[ ! -f "$imageDir/calico_$calicoVer.tar" ]];then
        docker pull "calico/cni:$calicoVer" && \
        docker pull "calico/pod2daemon-flexvol:$calicoVer" && \
        docker pull "calico/kube-controllers:$calicoVer" && \
        docker pull "calico/node:$calicoVer" && \
        docker save -o "$imageDir/calico_$calicoVer.tar" "calico/cni:$calicoVer" "calico/kube-controllers:$calicoVer" "calico/node:$calicoVer" "calico/pod2daemon-flexvol:$calicoVer"
    fi
    if [[ ! -f "$imageDir/coredns_$corednsVer.tar" ]];then
        docker pull "coredns/coredns:$corednsVer" && \
        docker save -o "$imageDir/coredns_$corednsVer.tar" "coredns/coredns:$corednsVer"
    fi
    if [[ ! -f "$imageDir/k8s-dns-node-cache_$dnsNodeCacheVer.tar" ]];then
        docker pull "easzlab/k8s-dns-node-cache:$dnsNodeCacheVer" && \
        docker save -o "$imageDir/k8s-dns-node-cache_$dnsNodeCacheVer.tar" "easzlab/k8s-dns-node-cache:$dnsNodeCacheVer"
    fi
    if [[ ! -f "$imageDir/dashboard_$dashboardVer.tar" ]];then
        docker pull "kubernetesui/dashboard:$dashboardVer" && \
        docker save -o "$imageDir/dashboard_$dashboardVer.tar" "kubernetesui/dashboard:$dashboardVer"
    fi
    if [[ ! -f "$imageDir/flannel_$flannelVer.tar" ]];then
        docker pull "easzlab/flannel:$flannelVer" && \
        docker save -o "$imageDir/flannel_$flannelVer.tar" "easzlab/flannel:$flannelVer"
    fi
    if [[ ! -f "$imageDir/metrics-scraper_$dashboardMetricsScraperVer.tar" ]];then
        docker pull "kubernetesui/metrics-scraper:$dashboardMetricsScraperVer" && \
        docker save -o "$imageDir/metrics-scraper_$dashboardMetricsScraperVer.tar" "kubernetesui/metrics-scraper:$dashboardMetricsScraperVer"
    fi
    if [[ ! -f "$imageDir/metrics-server_$metricsVer.tar" ]];then
        docker pull "easzlab/metrics-server:$metricsVer" && \
        docker save -o "$imageDir/metrics-server_$metricsVer.tar" "easzlab/metrics-server:$metricsVer"
    fi
    if [[ ! -f "$imageDir/pause_$pauseVer.tar" ]];then
        docker pull "easzlab/pause:$pauseVer" && \
        docker save -o "$imageDir/pause_$pauseVer.tar" "easzlab/pause:$pauseVer"
        /bin/cp -u "$imageDir/pause_$pauseVer.tar" "$imageDir/pause.tar"
    fi
    if [[ ! -f "$imageDir/nfs-provisioner_$nfsProvisionerVer.tar" ]];then
        docker pull "easzlab/nfs-subdir-external-provisioner:$nfsProvisionerVer" && \
        docker save -o "$imageDir/nfs-provisioner_$nfsProvisionerVer.tar" "easzlab/nfs-subdir-external-provisioner:$nfsProvisionerVer"
    fi
    if [[ ! -f "$imageDir/kubeasz_$KUBEASZ_VER.tar" ]];then
        docker pull "easzlab/kubeasz:$KUBEASZ_VER" && \
        docker save -o "$imageDir/kubeasz_$KUBEASZ_VER.tar" "easzlab/kubeasz:$KUBEASZ_VER"
    fi
}

function download_docker() {
    if [[ "$REGISTRY_MIRROR" == CN ]];then
        DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/x86_64/docker-${DOCKER_VER}.tgz"
    else
        DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VER}.tgz"
    fi

    if [[ -f "$BASE/down/docker-${DOCKER_VER}.tgz" ]];then
        logger warn "docker binaries already existed"
    else
        logger info "downloading docker binaries, version $DOCKER_VER"
        if [[ -e /usr/bin/wget ]];then
        wget -c --no-check-certificate "$DOCKER_URL" || { logger error "downloading docker failed"; exit 1; }
        else
        curl -k -C- -O --retry 3 "$DOCKER_URL" || { logger error "downloading docker failed"; exit 1; }
        fi
        /bin/mv -f "./docker-$DOCKER_VER.tgz" "$BASE/down"
    fi
}

function get_k8s_bin() {
    [[ -f "$BASE/bin/kubelet" ]] && { logger warn "kubernetes binaries existed"; return 0; }

    logger info "downloading kubernetes: $K8S_BIN_VER binaries"
    docker pull easzlab/kubeasz-k8s-bin:"$K8S_BIN_VER" && \
    logger debug "run a temporary container" && \
    docker run -d --name temp_k8s_bin easzlab/kubeasz-k8s-bin:${K8S_BIN_VER} && \
    logger debug "cp k8s binaries" && \
    docker cp temp_k8s_bin:/k8s "$BASE/k8s_bin_tmp" && \
    /bin/mv -f "$BASE"/k8s_bin_tmp/* "$BASE/bin" && \
    logger debug "stop&remove temporary container" && \
    docker rm -f temp_k8s_bin && \
    rm -rf "$BASE/k8s_bin_tmp"
}

function get_ext_bin() {
    [[ -f "$BASE/bin/etcdctl" ]] && { logger warn "extra binaries existed"; return 0; }

    logger info "downloading extral binaries kubeasz-ext-bin:$EXT_BIN_VER"
    docker pull "easzlab/kubeasz-ext-bin:$EXT_BIN_VER" && \
    logger debug "run a temporary container" && \
    docker run -d --name temp_ext_bin "easzlab/kubeasz-ext-bin:$EXT_BIN_VER" && \
    logger debug "cp extral binaries" && \
    docker cp temp_ext_bin:/extra "$BASE/extra_bin_tmp" && \
    /bin/mv -f "$BASE"/extra_bin_tmp/* "$BASE/bin" && \
    logger debug "stop&remove temporary container" && \
    docker rm -f temp_ext_bin && \
    rm -rf "$BASE/extra_bin_tmp"
}

function get_sys_pkg() {
    [[ -f "$BASE/down/packages/chrony_xenial.tar.gz" ]] && { logger warn "system packages existed"; return 0; }

    logger info "downloading system packages kubeasz-sys-pkg:$SYS_PKG_VER"
    docker pull "easzlab/kubeasz-sys-pkg:$SYS_PKG_VER" && \
    logger debug "run a temporary container" && \
    docker run -d --name temp_sys_pkg "easzlab/kubeasz-sys-pkg:$SYS_PKG_VER" && \
    logger debug "cp system packages" && \
    docker cp temp_sys_pkg:/packages "$BASE/down" && \
    logger debug "stop&remove temporary container" && \
    docker rm -f temp_sys_pkg
}

function download_all() {
    mkdir -p "$BASE/down" "$BASE/bin"
    download_docker && \
    get_k8s_bin && \
    get_ext_bin && \
    get_sys_pkg && \
    get_offline_image
}

download_all