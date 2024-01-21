#!/bin/bash

set -e
apt update
apt -y install xorriso live-build syslinux squashfs-tools python-docutils
apt -y install wget fakeroot gcc libncurses5-dev bc \
ca-certificates pkg-config make flex bison build-essential autoconf \
automake aptitude
