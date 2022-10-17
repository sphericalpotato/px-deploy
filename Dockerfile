FROM registry.fedoraproject.org/fedora:35-x86_64
ENV CLOUDSDK_PYTHON="/usr/bin/python2.7"

RUN dnf install -y dnf-plugins-core && \
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo && \
    dnf update -y  && \
    dnf install -y openssh-clients openssl make golang git azure-cli awscli make \
                   jq terraform vagrant-2.2.19-1 packer python2 gcc gcc-c++ && \
    yum clean all && \
    echo ServerAliveInterval 300 >/etc/ssh/ssh_config && \
    echo ServerAliveCountMax 2 >>/etc/ssh/ssh_config && \
    echo TCPKeepAlive yes >>/etc/ssh/ssh_config && \
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-338.0.0-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-338.0.0-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-338.0.0-linux-x86_64.tar.gz && \
    ln -s /google-cloud-sdk/bin/gcloud /usr/bin/gcloud && \
    gcloud components install alpha -q && \
    vagrant plugin install vagrant-aws vagrant-azure && \
    vagrant plugin install vagrant-google --plugin-version 2.5.0 && \
    vagrant plugin install vagrant-vsphere --plugin-version 1.13.5 && \
    vagrant box add azure https://github.com/azure/vagrant-azure/raw/v2.0/dummy.box --provider azure --provider azure && \
    vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box --provider aws && \
    vagrant box add google/gce https://vagrantcloud.com/google/boxes/gce/versions/0.1.0/providers/google.box --provider google && \
    curl -Ls https://github.com/vmware/govmomi/releases/download/v0.23.0/govc_linux_amd64.gz | zcat >/usr/bin/govc && \
    mkdir -p /root/go/src/px-deploy

COPY go.mod go.sum px-deploy.go /root/go/src/px-deploy/
COPY vagrant /px-deploy/vagrant
COPY vsphere-init.sh VERSION /

RUN chmod 755 /usr/bin/govc /vsphere-init.sh
RUN cd /root/go/src/px-deploy ; go install
