#!/usr/bin/env bash

distro=focal

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
    echo "ll1." $1
    echo "ll2." $2
    echo "ll3." $3
    echo "ll4." $4
    echo "ll5." $5

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

    #[ $1 != amd64 -a ! -f $RFSDIR/usr/bin/qemu-${tgtarch}-static ] && cp $(which qemu-${tgtarch}-static) $RFSDIR/usr/bin
    mkdir -p $2/usr/local/bin
    cp -f board/phytium/common/ubuntu-package-installer $RFSDIR/usr/local/bin/

    packages_list=board/phytium/common/$3
    [ ! -f $packages_list ] && echo $packages_list not found! && exit 1

    echo additional packages list: $packages_list
    if [ ! -d $RFSDIR/usr/aptpkg ]; then
	mkdir -p $RFSDIR/usr/aptpkg
	cp -f $packages_list $RFSDIR/usr/aptpkg
	if [ -f board/nxp/common/ls/reconfigpkg.sh ]; then
		cp -f board/nxp/common/ls/reconfigpkg.sh $RFSDIR/usr/aptpkg
	fi
    fi

    mkdir -p $RFSDIR/etc
    cp -f /etc/resolv.conf $RFSDIR/etc/resolv.conf

    if [ ! -d $RFSDIR/debootstrap ]; then
        echo "testdeboot"
	export LANG=en_US.UTF-8
	sudo debootstrap --arch=$1 --foreign focal $RFSDIR

	echo "installing for second-stage ..."
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C \
	sudo chroot $RFSDIR /debootstrap/debootstrap  --second-stage
	if [ "x$?" != "x0" ]; then
		do_recover_from_error "debootstrap failed in second-stage"
		exit 1
	fi

	echo "configure ... "
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C \
	sudo chroot $RFSDIR dpkg --configure -a
    fi

    sudo chroot $RFSDIR ubuntu-package-installer $1 $distro $5 $3 
	if [ "x$?" != "x0" ]; then
		 do_recover_from_error "ubuntu-package-installer failed"
		exit 1
	fi

    sudo chroot $RFSDIR systemctl enable systemd-rootfs-resize
    sudo chown -R $USER:$GROUPS $RFSDIR
    #if dpkg-query -l snapd | grep ii 1>/dev/null; then
    #	chmod +rw -R $RFSDIR/var/lib/snapd/
    #fi

    if [ $distro = focal ]; then
	echo Ubuntu,20.04.1 | tee $RFSDIR/etc/.firststagedone 1>/dev/null
    elif [ $distro = bionic ]; then
	echo Ubuntu,18.04.5 | tee $RFSDIR/etc/.firststagedone 1>/dev/null
    fi
    setup_distribution_info $5 $2 $1

    #rm $RFSDIR/etc/apt/apt.conf
    rm $RFSDIR/dev/* -rf
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
	elif grep -Eq "^BR2_LINUX_KERNEL_INTREE_DTS_NAME=\"e2000\"$" ${BR2_CONFIG}; then
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
	if grep -Eq "^BR2_ROOTFS_SKELETON_CUSTOM_FULL_RFS=y$" ${BR2_CONFIG}; then
		echo "full"
	else
		echo "main"
	fi
}

main()
{
	# $1 - the current rootfs directory, skeleton-custom or target
	echo "1." ${1}
	echo "2." ${2}
	echo "3." $(arch_type)
	echo "4." $(plat_name)
        sudo rm -rf ${1}/*
	# run first stage do_distrorfs_first_stage arm64 ${1} ubuntu-additional_packages_list focal ubuntu
	do_distrorfs_first_stage $(arch_type) ${1} ubuntu-additional_packages_list focal ubuntu

	# change the hostname to "platforms-Ubuntu"
	echo $(plat_name)-Ubuntu > ${1}/etc/hostname

	if [ $distro = focal ]; then
		sed -i "s/float(n\[0\])/float(n[0].split()[0])/" ${1}/usr/share/pyshared/lsb_release.py
	fi

	# rebuild iproute2 and use the tc command modified for target system
	if grep -Eq "^BR2_PACKAGE_IPROUTE2=y$" ${BR2_CONFIG}; then
		make iproute2-rebuild ${O:+O=$O}
	fi

	exit $?
}

main $@
