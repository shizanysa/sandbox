#!/bin/bash
NAMEVM=$1
SIZE=$2
DISTR=$3
IP=$4
VCPUS=$5
VMEM=$6
virsh destroy $1
virsh undefine $1
if [ -b /dev/vg00/$1 ]; then
  echo "Logical Volume $1 already exists in volume group "vg00""
  echo "Remove lv $1"
  lvremove -f /dev/vg00/$1
  lvcreate -q -L $2 -n $1 vg00 --yes
else
  lvcreate -q -L $2 -n $1 vg00 --yes
fi

if [ "$DISTR" == "Ubuntu" ]; then
  cd /cloud-init/
  if [ ! -f bionic-server-cloudimg-amd64.img ]; then
    wget http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
  fi
  if [ ! -f "/cloud-init/Ubuntu.raw" ]; then
    echo ---convert to raw---
    qemu-img convert -f  qcow2 -O raw bionic-server-cloudimg-amd64.img Ubuntu.raw 
  fi  
  echo ---dd copy ubuntu img-------
  dd if=/cloud-init/Ubuntu.raw of=/dev/vg00/$1 bs=4M status=progress
  echo ---dd done ----------

  cd /cloud-init/machines/
  cat > meta-data <<EOF
  instance-id: $1
  local-hostname: $1
  network-interfaces: |
    auto ens3
    iface ens3 inet static
    address $4
    network 192.168.0.0
    netmask 255.255.255.0
    broadcast 192.168.0.255
    gateway 192.168.0.1
    dns-nameservers 8.8.8.8
EOF

fi
if [ "$DISTR" == "Centos7" ]; then
  echo ---dd copy ...-------
  dd if=/cloud-init/$3.raw of=/dev/vg00/$1 bs=4M status=progress
  echo ---dd done ----------

  cd /cloud-init/machines/
  cat > meta-data <<EOF
  instance-id: $1
  local-hostname: $1
  network-interfaces: |
    auto eth0
    iface eth0 inet static
    address $4
    network 192.168.0.0
    netmask 255.255.255.0
    broadcast 192.168.0.255
    gateway 192.168.0.1
    dns-nameservers 8.8.8.8
EOF
fi

#cd /cloud-init/machines/
#cat > meta-data <<EOF
#instance-id: $1
#local-hostname: $1
#network-interfaces: |
#  auto eth0
#  iface eth0 inet static
#  address $4
#  network 192.168.0.0
#  netmask 255.255.255.0
#  broadcast 192.168.0.255
#  gateway 192.168.0.1
#  dns-nameservers 8.8.8.8
#EOF

cloud-localds /cloud-init/machines/$1.iso /cloud-init/machines/$3.txt /cloud-init/machines/meta-data

virt-install \
            --name $1 \
	    --vcpus $5 \
            --memory $6 \
            --disk /dev/vg00/$1,device=disk,bus=virtio \
            --disk /cloud-init/machines/$1.iso,device=cdrom \
            --os-type linux \
            --os-variant centos7.0 \
            --virt-type kvm \
            --network bridge=br0 \
            --graphics vnc,listen=0.0.0.0 --noautoconsole \
            --check all=off \
            --import 

if [ "$DISTR" == "Ubuntu" ]; then
	virsh change-media $1 hda --eject --config
else
	virsh change-media $1 sda --eject --config
fi

virsh change-media $1 hda --eject --config
rm -f /cloud-init/machines/$1.iso
