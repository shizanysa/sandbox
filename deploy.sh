#!/bin/bash
virsh destroy $1
virsh undefine $1
lvremove -f /dev/vg00/$1
lvcreate -L $2G -n $1 vg00

echo ---dd copy ...-------
dd if=/cloud-init/CentOS-7-x86_64-GenericCloud-1901.raw of=/dev/vg00/$1 bs=4M status=progress
cloud-localds /cloud-init/machines/test1.iso /cloud-init/machines/test1.txt
echo ---dd done ----------

virt-install \
            --name $1\
            --memory 1024 \
            --disk /dev/vg00/$1,device=disk,bus=virtio \
            --disk /cloud-init/machines/test1.iso,device=cdrom \
            --os-type linux \
            --os-variant centos7.0 \
            --virt-type kvm \
            --graphics none \
            --network bridge=br0 \
            --import 

virsh change-media $1 hda --eject --config
