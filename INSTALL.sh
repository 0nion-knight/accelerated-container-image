#!/bin/bash

H="$(cd "$(dirname "$0")" && pwd)"
DEST="/opt/overlaybd/snapshotter"

getInput() {
    msg=$*
    while true
    do
        echo -n "${msg} "
        read RET
        if [[ "${RET}" == "Y" ]]; then
            return 1
        fi
        if [[ "${RET}" == "N" ]]; then
            return 0
        fi
        continue
    done
}

echo "Compile overlaybd-snapshotter..."
cd $H
make -j4 || exit 1
sudo make install || exit 1
sudo mkdir -p /etc/overlaybd-snapshotter
echo "copy config.json to /etc/overlaybd-snapshotter/"
sudo cp script/config.json /etc/overlaybd-snapshotter

echo "create service..."
sudo cp $H/script/overlaybd-snapshotter.service /opt/overlaybd/snapshotter
sudo systemctl enable /opt/overlaybd/snapshotter/overlaybd-snapshotter.service
sudo systemctl start overlaybd-snapshotter

getInput 'Would you like make containerd support overlaybd-snapshotter [Y/N]? (this will change /etc/containerd/config.toml and restart containerd)'
OP=$?
if [[ OP -eq 1 ]]; then
    echo "Change config.toml to make containerd support snapshotter..."
    m=$(grep proxy_plugins.overlaybd /etc/containerd/config.toml)
    if [[ $? -ne 0 ]]; then
        if [[ ! -f /etc/containerd/config.toml ]]; then
            touch /etc/containerd/config.toml
        fi
sudo cat <<-EOF | sudo tee --append /etc/containerd/config.toml
[proxy_plugins.overlaybd]
    type = "snapshot"
    address = "/run/overlaybd-snapshotter/overlaybd.sock"
EOF
    sudo systemctl restart containerd
    fi
else
    echo "install done."
fi
