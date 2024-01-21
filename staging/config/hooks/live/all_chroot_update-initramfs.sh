#!/bin/sh

for KERNEL in /boot/vmlinuz-*
do
	VERSION="$(basename ${KERNEL} | sed -e 's|vmlinuz-||')"

	update-initramfs -k ${VERSION} -t -u
done

cat << EOF
********************
end of hook
********************
EOF
