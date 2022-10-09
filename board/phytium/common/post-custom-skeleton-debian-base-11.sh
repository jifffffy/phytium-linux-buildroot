#!/usr/bin/env bash

distro=bullseye

trap recover_from_ctrl_c INT

recover_from_ctrl_c()
{
	do_recover_from_error "Interrupt caught ... exiting"
	exit 1
}

do_recover_from_error()
{
	sudo chroot $RFSDIR /bin/umount /proc > /dev/null 2>&1;
	sudo chroot $RFSDIR /bin/umount /sys > /dev/null 2>&1;
	USER=$(id -u); GROUPS=${GROUPS}; \
	sudo chroot $RFSDIR  /bin/chown -R ${USER}:${GROUPS} / > /dev/null 2>&1;
	echo -e "\n************"
    echo $1
	echo -e "  Please running the below commands before re-compiling:"
	echo -e "    rm -rf $RFSDIR"
	echo -e "    make skeleton-custom-dirclean"
	echo -e "  Or\n    make skeleton-custom-dirclean O=<output dir>"
}

do_distrorfs_first_stage() {
# $1: platform architecture, arm64
# $2: rootfs directory, output/build/skeleton-custom
# $3: board/common/ubuntu-additional_packages_list
# $4: focal
# $5: ubuntu

    DISTROTYPE=$5
    [ -z "$RFSDIR" ] && RFSDIR=$2
    [ -z $RFSDIR ] && echo No RootFS exist! && return
    [ -f $RFSDIR/etc/.firststagedone ] && echo $RFSDIR firststage exist! && return
    [ -f /etc/.firststagedone -a ! -f /proc/uptime ] && return
    mkdir -p $RFSDIR/lib/modules

    if [ $1 = arm64 ]; then
	tgtarch=aarch64
    elif [ $1 = armhf ]; then
	tgtarch=arm
    fi

    qemu-${tgtarch}-static -version > /dev/null 2>&1
    if [ "x$?" != "x0" ]; then
        echo qemu-${tgtarch}-static not found
        exit 1
    fi

    debootstrap --version > /dev/null 2>&1
    if [ "x$?" != "x0" ]; then
        echo debootstrap not found
        exit 1
    fi

    sudo chown 0:0  $RFSDIR
    #[ $1 != amd64 -a ! -f $RFSDIR/usr/bin/qemu-${tgtarch}-static ] && cp $(which qemu-${tgtarch}-static) $RFSDIR/usr/bin
    sudo mkdir -p $2/usr/local/bin
    sudo cp -f board/phytium/common/debian-package-installer $RFSDIR/usr/local/bin/
    sudo cp -r   output/modules $RFSDIR/lib
    sudo rm -rf  output/modules
    [ -f output/linux-headers.tar.gz ] && sudo tar zxf  output/linux-headers.tar.gz -C $RFSDIR
    packages_list=board/phytium/common/$3
    [ ! -f $packages_list ] && echo $packages_list not found! && exit 1

    echo additional packages list: $packages_list
    if [ ! -d $RFSDIR/usr/aptpkg ]; then
	sudo mkdir -p $RFSDIR/usr/aptpkg
	sudo cp -f $packages_list $RFSDIR/usr/aptpkg
    fi

    sudo mkdir -p $RFSDIR/etc
    sudo cp -f /etc/resolv.conf $RFSDIR/etc/resolv.conf

    if [ ! -d $RFSDIR/debootstrap ]; then
        echo "testdeboot"
	export LANG=zh_CN.UTF-8
	sudo debootstrap --arch=$1 --foreign bullseye $RFSDIR  http://ftp.cn.debian.org/debian/

	echo "installing for second-stage ..."
	export LC_ALL="zh_CN.UTF-8" && export LANGUAGE="zh_CN:zh" && export LANG="zh_CN.UTF-8"
	#DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LANG=zh_CN.UTF-8 \
	sudo chroot $RFSDIR /debootstrap/debootstrap  --variant=minbase --second-stage
	if [ "x$?" != "x0" ]; then
		do_recover_from_error "debootstrap failed in second-stage"
		exit 1
	fi

	echo "configure ... "
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C \
	sudo chroot $RFSDIR dpkg --configure -a
    fi

    sudo chroot $RFSDIR debian-package-installer $1 $distro $5 $3 $6 $7
	if [ "x$?" != "x0" ]; then
		 do_recover_from_error "debian-package-installer failed"
		exit 1
	fi

   # sudo chroot $RFSDIR systemctl enable systemd-rootfs-resize
    sudo chown -R $USER:$GROUPS $RFSDIR

    if [ $distro = bullseye ]; then
	echo debian,11 | tee $RFSDIR/etc/.firststagedone 1>/dev/null
    elif [ $distro = bionic ]; then
	echo Ubuntu,18.04.5 | tee $RFSDIR/etc/.firststagedone 1>/dev/null
    fi
    setup_distribution_info $5 $2 $1

    #rm $RFSDIR/etc/apt/apt.conf
    sudo rm $RFSDIR/dev/* -rf
}

setup_distribution_info () {
    DISTROTYPE=$1
    RFSDIR=$2
    tarch=$3
    distroname=`head -1 $RFSDIR/etc/.firststagedone | cut -d, -f1`
    distroversion=`head -1 $RFSDIR/etc/.firststagedone | cut -d, -f2`
    releaseversion="$distroname (based on $DISTROTYPE-$distroversion-base) ${tarch}"
    releasestamp="Build: `date +'%Y-%m-%d %H:%M:%S'`"
    echo $releaseversion > $RFSDIR/etc/buildinfo
    sed -i "1 a\\$releasestamp" $RFSDIR/etc/buildinfo
    if grep U-Boot $RFSDIR/etc/.firststagedone 1>$RFSDIR/dev/null 2>&1; then
        tail -1 $RFSDIR/etc/.firststagedone >> $RFSDIR/etc/buildinfo
    fi

    if [ $DISTROTYPE = ubuntu ]; then
        echo $distroname $1-$distroversion > $RFSDIR/etc/issue
        echo $distroname $1-$distroversion > $RFSDIR/etc/issue.net

        tgtfile=$RFSDIR/etc/lsb-release
        echo DISTRIB_ID=Phytium > $tgtfile
        echo DISTRIB_RELEASE=$distroversion >> $tgtfile
        echo DISTRIB_CODENAME=$distro >> $tgtfile
        echo DISTRIB_DESCRIPTION=\"$distroname $1-$distroversion\" >> $tgtfile

        tgtfile=$RFSDIR/etc/update-motd.d/00-header
        echo '#!/bin/sh' > $tgtfile
        echo '[ -r /etc/lsb-release ] && . /etc/lsb-release' >> $tgtfile
        echo 'printf "Welcome to %s (%s %s %s)\n" "$DISTRIB_DESCRIPTION" "$(uname -o)" "$(uname -r)" "$(uname -m)"' >> $tgtfile

        tgtfile=$RFSDIR/etc/update-motd.d/10-help-text
        echo '#!/bin/sh' > $tgtfile
        echo 'printf "\n"' >> $tgtfile
        echo 'printf " * Support:        https://www.phytium.com.cn\n"' >> $tgtfile

        tgtfile=$RFSDIR/usr/lib/os-release
        echo NAME=\"$distroname\" > $tgtfile
        echo VERSION=${DISTROTYPE}-$distroversion >> $tgtfile
        echo ID=Ubuntu >> $tgtfile
        echo VERSION_ID=$distroversion >> $tgtfile
	echo PRETTY_NAME=\" Ubuntu Built with Buildroot, based on Ubuntu $distroversion LTS\" >> $tgtfile
	echo VERSION_CODENAME=$distro >> $tgtfile

        rm -f $RFSDIR/etc/default/motd-news
        rm -f $RFSDIR/etc/update-motd.d/50-motd-news
    fi
}

plat_name()
{
	if grep -Eq "^BR2_TARGET_GENERIC_HOSTNAME=\"D2000\"$" ${BR2_CONFIG}; then
		echo "D2000"
	elif grep -Eq "^BR2_TARGET_GENERIC_HOSTNAME=\"E2000\"$" ${BR2_CONFIG}; then
		echo "E2000"
	fi
}

arch_type()
{
	if grep -Eq "^BR2_aarch64=y$" ${BR2_CONFIG}; then
		echo "arm64"
	elif grep -Eq "^BR2_arm=y$" ${BR2_CONFIG}; then
		echo "armhf"
	fi
}

full_rtf()
{
	if grep -Eq "^BR2_PACKAGE_ROOTFS_DESKTOP=y$" ${BR2_CONFIG}; then
		echo "desktop"
	else
		echo "base"
	fi
}

main()
{
	# $1 - the current rootfs directory, skeleton-custom or target
	ROOTPATH=${1}/usr/src/linux-headers
	KERNELVERSION=`ls $1/lib/modules`
	cd ${1}/lib/modules/${KERNELVERSION}/build
	if grep -Eq "^BR2_ROOTFS_LINUX_HEADERS=y$" ${BR2_CONFIG}; then
		sudo mkdir -p ${ROOTPATH}
		sudo cp --parents $(find  -type f -name "Makefile*" -o -name "Kconfig*")  ${ROOTPATH}
        	sudo cp -a  arch/arm64/include  ${ROOTPATH}
		sudo cp -a .config      ${ROOTPATH}
		sudo cp  --parents arch/arm64/kernel/module.lds  ${ROOTPATH}
		sudo cp  --parents tools/include/tools/le_byteshift.h ${ROOTPATH}
		sudo cp  --parents tools/include/tools/be_byteshift.h ${ROOTPATH}
        	sudo cp Module.symvers  ${ROOTPATH}
		sudo cp -a  arch/arm64/include/asm     ${ROOTPATH}/include
		sudo cp -a  arch/arm64/include/generated/asm   ${ROOTPATH}/include
		sudo cp -a  include   ${ROOTPATH}
		sudo cp -a  scripts   ${ROOTPATH}
        	cd   ${1}
		sudo tar zcvf linux-headers.tar.gz  usr/src/linux-headers
		sudo mv linux-headers.tar.gz  ../
	fi
	cd   ${1}
	sudo rm -rf ${1}/lib/modules/${KERNELVERSION}/build
	sudo rm -rf ${1}/lib/modules/${KERNELVERSION}/source
	sudo mv ${1}/lib/modules  ../
	sudo rm -rf ${1}/*
        cd ../../
	# run first stage do_distrorfs_first_stage arm64 ${1} ubuntu-additional_packages_list focal ubuntu
	do_distrorfs_first_stage $(arch_type) ${1} ubuntu-additional_packages_list bullseye  debian $(plat_name) $(full_rtf)

	# change the hostname to "platforms-Ubuntu"
	echo $(plat_name)-debian > ${1}/etc/hostname
        
	if ! grep -q  "$(plat_name)-debian"  ${1}/etc/hosts; then
        	echo 127.0.0.1   $(plat_name)-debian | sudo tee -a ${1}/etc/hosts 1>/dev/null
        fi

	if grep -Eq "^BR2_PACKAGE_XORG_ROGUE_UMLIBS=y$" ${BR2_CONFIG}; then
                make xorg-rogue-umlibs-rebuild ${O:+O=$O}
        fi

	if grep -Eq "^BR2_ROOTFS_CHOWN=y$" ${BR2_CONFIG}; then
                make rootfs-chown-rebuild ${O:+O=$O}
		sudo chroot ${1} systemctl enable systemd-rootfs-chown.service
        fi

	exit $?
}

main $@
