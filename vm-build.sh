#!/bin/bash

IMAGE=$1
MAC=$2
IP=$3
HDD=${4:-480}
RAM=${5:-12}
VMPATH="/vm/tm/$IMAGE"

if [[ $# -lt 3 ]] ; then
    echo 'Usage : vm-build name mac ip [disk ram]'
    exit 0
fi

zfs create vm/tm/$IMAGE

cp /vm/os/bionic-server-cloudimg-amd64.raw $VMPATH/disk.0
qemu-img resize $VMPATH/disk.0 +${HDD}G

cat > $VMPATH/user-data <<EOF
#cloud-config
disable_root: false
runcmd:
  - mkdir -p /root/.ssh
  - echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuj5Ki5q8GEFkw/XH2cGi0eJYQTX291HFXovPjI88O0D6W+WklZv221pAaYCypiA3XOht+lYcXsM1RIk/NIFs6/qzZX1Adk4hVhGB8npXz3vE++X4mESNkfR11y38w0Cz3e7NpsqF9q347Z54vfY4YeyJdQvseiJQh8ipJ2ZVRv9tfuhYiKejyhIDsnZodBvdN2ucvtTvtJWDlSthoLydpurNs1DK+Oechbcm2qHWZm5Yw4P/mWqDAwvqLdaKeUodzLhxfw2O8KuNiZt7kD/LvPVgGUj3n8BwctUr7K6j5lVeS54UqcvYJHbbRUzhrd1hGj9dmCdNiPfaCCEu9hTmZ root@ovh' > /root/.ssh/authorized_keys
  - service sshd restart
  - apt update
  - hostnamectl set-hostname ${IMAGE}.pilet.io
EOF


cat > $VMPATH/network-config <<EOF
version: 2
ethernets:
  ens3:
    dhcp4: false
    dhcp6: false
    addresses:
      - $IP/32
    gateway4: 192.99.39.168
    nameservers:
      addresses:
        - 192.99.39.168
        - 8.8.8.8
    routes:
      - to: 192.99.39.168/32
        scope: link
    match:
      macaddress: $MAC
EOF


cat > $VMPATH/start <<EOF
qemu-system-x86_64\
 -name $IMAGE --enable-kvm -cpu host\
 -smp cpus=2 -m ${RAM}G\
 -vnc none\
 -drive file=$VMPATH/disk.0,if=virtio,index=0,format=raw\
 -drive file=$VMPATH/init.img,if=virtio,index=1,format=raw\
 -net nic,model=virtio,macaddr=${MAC}\
 -net bridge,br=br0 --daemonize
EOF

chmod +x $VMPATH/start

cloud-localds -v --network-config=$VMPATH/network-config $VMPATH/init.img $VMPATH/user-data
