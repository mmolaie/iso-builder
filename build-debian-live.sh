#!/bin/bash


set -e

usage()
{
cat << EOF

usage: $0 options

OPTIONS:
   ./build-debian-live.sh -g no-desktop
   
EOF
}

GUI=
KERNEL_VER=

while getopts “hg:k:p:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         g)
             GUI=$OPTARG
             if [[ "$GUI" != "no-desktop" ]]; 
             then
               echo -e "\n Please check the option's spelling \n"
               usage
               exit 1;
             fi
             ;;
         k)
             KERNEL_VER=$OPTARG
             if [[ "$KERNEL_VER" =~ ^[3-5]\.[0-9]+?\.?[0-9]+$ ]];
             then
               echo -e "\n Kernel version set to ${KERNEL_VER} \n"
             else
               echo -e "\n Please check the option's spelling "
               echo -e " Also - only kernel versions >3.0 are supported !! \n"
               usage
               exit 1;
             fi
             ;;
         p)
             PKG_ADD+=("$OPTARG")
             echo "Packages to be added to the build: ${PKG_ADD[@]} "
             ;;
         ?)
             GUI=
             KERNEL_VER=
             PKG_ADD=
             echo -e "\n Using the default options \n"
             ;;
     esac
done
shift $((OPTIND -1))

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

mkdir -p Live-Build

if [[ -n "$KERNEL_VER" ]]; 
then 
  
  ### START Kernel Version choice ###
  
  cd Live-Build && mkdir -p kernel-misc && cd kernel-misc 
  if [[ ${KERNEL_VER} == 3* ]];
  then 
    wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-${KERNEL_VER}.tar.xz
  elif [[ ${KERNEL_VER} == 4* ]];
  then
     wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VER}.tar.xz
  elif [[ ${KERNEL_VER} == 5* ]];
  then
     wget https://www.kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VER}.tar.xz
  elif [[ ${KERNEL_VER} == 6* ]];
  then
     wget https://www.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz
  else
    echo "Unsupported kernel version! Only kernel >3.0 are supported"
    exit 1;
  fi

  if [ $? -eq 0 ];
  then
    echo -e "Downloaded successfully linux-${KERNEL_VER}.tar.xz "
  else
    echo -e "\n Please check your connection \n"
    echo -e "CAN NOT download the requested kernel. Please make sure the kernel version is present here - \n"
    echo -e "https://www.kernel.org/pub/linux/kernel/v3.x/ \n"
    echo -e "or here respectively \n"
    echo -e "https://www.kernel.org/pub/linux/kernel/v4.x/ \n"
    exit 1;
  fi

  tar xfJ linux-${KERNEL_VER}.tar.xz 
  cd linux-${KERNEL_VER}
  
  make defconfig && \
  make clean && \
  make -j `getconf _NPROCESSORS_ONLN` deb-pkg LOCALVERSION=-debian-amd64 KDEB_PKGVERSION=${KERNEL_VER}
  cd ../../
  
  # Directory where the kernel image and headers are copied to
  mkdir -p config/packages.chroot/
  # Directory that needs to be present for the Kernel Version choice to work
  mkdir -p cache/contents.chroot/
  # Hook directory for the initramfs script to be copied to
  #mkdir -p config/hooks/
  mkdir -p config/hooks/live/

  mv kernel-misc/*.deb config/packages.chroot/
  cp ../staging/config/hooks/live/all_chroot_update-initramfs.sh config/hooks/live/all_chroot_update-initramfs.chroot
    
  ### END Kernel Version choice ### 
  
  lb config \
  -a amd64 -d bullseye  \
  --archive-areas "main contrib" \
  --swap-file-size 2048 \
  --bootloader syslinux \
  --debian-installer live \
  --bootappend-live "boot=live swap config username=proot live-config.hostname=Debian live-config.user-default-groups=audio,cdrom,floppy,video,dip,plugdev,scanner,bluetooth,netdev,sudo" \
  --linux-packages linux-image-${KERNEL_VER} \
  --linux-packages linux-headers-${KERNEL_VER} \
  --apt-options "--yes --force-yes" \
  --linux-flavour Cyberfence \
  --iso-application Debian - Custom iso installer \
  --iso-preparer ASAGroup \
  --iso-publisher ASAGroup \
  --iso-volume V-Debian $LB_CONFIG_OPTIONS
  
else

  cd Live-Build && lb config \
  -a amd64 -d bullseye \
  --archive-areas "main contrib" \
  --swap-file-size 2048 \
  --debian-installer live \
  --bootappend-live "boot=live swap config username=proot live-config.hostname=Debian live-config.user-default-groups=audio,cdrom,floppy,video,dip,plugdev,scanner,bluetooth,netdev,sudo" \
  --iso-application Debian - Custom iso installer \
  --iso-preparer ASAGroup \
  --iso-publisher ASAGroup \
  --iso-volume V-Debian $LB_CONFIG_OPTIONS 

fi

# Create dirs if not existing for the custom config files
mkdir -p config/includes.chroot/etc/systemd/system/
mkdir -p config/includes.chroot/etc/init.d/
mkdir -p config/includes.binary/isolinux/
mkdir -p config/includes.chroot/etc/profile.d/
mkdir -p config/includes.chroot/root/Desktop/
mkdir -p config/includes.chroot/etc/alternatives/
mkdir -p config/includes.chroot/etc/systemd/system/
mkdir -p config/includes.chroot/var/backups/
mkdir -p config/includes.chroot/etc/apt/

cd ../

# Add logo for the boot screen
cp staging/splash.png Live-Build/config/includes.binary/isolinux/

# Copy banners
cp staging/etc/motd Live-Build/config/includes.chroot/etc/
cp staging/etc/issue.net Live-Build/config/includes.chroot/etc/

# Add core system packages to be installed
echo "
libpcre3 libpcre3-dbg libpcre3-dev ntp
build-essential autoconf automake libtool libpcap-dev libnet1-dev 
libyaml-0-2 libyaml-dev zlib1g zlib1g-dev libcap-ng-dev libcap-ng0 
make flex bison libmagic-dev libnuma-dev pkg-config
libnetfilter-queue-dev libnetfilter-queue1 
libjansson-dev libjansson4 libnss3-dev libnspr4-dev
rsync mc python3-daemon libnss3-tools curl net-tools
python3-cryptography libgmp10 libyaml-0-2 python3-simplejson python3-pygments
python3-yaml ssh sudo openssl jq patch  
python3-pip debian-installer-launcher live-build apt-transport-https 
 " \
>> Live-Build/config/package-lists/CoreSystem.list.chroot

# Add system tools packages to be installed
echo "
htop rsync sysstat hping3 screen ngrep 
dsniff mc python3-daemon wget curl vim bootlogd lsof libpolkit-agent-1-0  libpolkit-gobject-1-0 policykit-1 policykit-1-gnome" \
>> Live-Build/config/package-lists/Tools.list.chroot


# Add specific tasks(script file) to be executed 
# inside the chroot environment
cp staging/config/hooks/live/chroot-inside-Debian-Live.hook.chroot Live-Build/config/hooks/live/

# Edit menu names for Live and Install
if [[ -n "$KERNEL_VER" ]]; 
then
   # live menu choice. That leaves the options to install.
   cp staging/config/hooks/live/menues-changes.hook.binary Live-Build/config/hooks/live/
   cp staging/config/hooks/live/menues-changes-live-custom-kernel-choice.hook.binary Live-Build/config/hooks/live/
else
  cp staging/config/hooks/live/menues-changes.hook.binary Live-Build/config/hooks/live/
  
fi

# Debian installer preseed.cfg
echo "
d-i netcfg/hostname string Debian

d-i passwd/user-fullname string proot User
d-i passwd/username string proot
d-i passwd/user-password password proot
d-i passwd/user-password-again password proot
d-i passwd/user-default-groups string audio cdrom floppy video dip plugdev scanner bluetooth netdev sudo

d-i passwd/root-password password P@ssw0rd
d-i passwd/root-password-again password P@ssw0rd
" > Live-Build/config/includes.installer/preseed.cfg

# Build the ISO
cd Live-Build && ( lb build 2>&1 | tee build.log )
mv live-image-amd64.hybrid.iso Debian.iso
