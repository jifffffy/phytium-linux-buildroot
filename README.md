# phytium-linux-buildroot
Buildroot是一种简单、高效且易于使用的工具，可以通过交叉编译生成嵌入式Linux系统。Buildroot的用户手册位于docs/manual/manual.pdf。  
phytium-linux-buildroot基于Buildroot，适配了飞腾e2000开发板，支持ubuntu文件系统、initrd文件系统、最小文件系统的编译。

# 开发环境
## 系统要求
Buildroot被设计为在Linux系统上运行，我们在ubuntu20.04系统上运行phytium-linux-buildroot。

## 下载phytium-linux-buildroot
`$ git clone git@gitee.com:phytium_embedded/phytium-linux-buildroot.git`

# 查看支持的defconfig
为飞腾CPU平台构建的文件系统的配置文件位于configs目录。  
在phytium-linux-buildroot根目录下执行`$ make list-defconfigs`，返回configs目录中的defconfig配置文件。  
```
$ cd xxx/phytium-linux-buildroot
$ make list-defconfigs
```
其中以phytium开头的为飞腾相关的defconfig配置文件，包含：  
```
phytium_e2000_defconfig             - Build for phytium_e2000  
phytium_e2000_ubuntu_defconfig      - Build for phytium_e2000_ubuntu  
phytium_initrd_defconfig            - Build for phytium_initrd  
```

# 编译文件系统
## 为e2000编译文件系统
（1）配置defconfig  
ubuntu文件系统：  
`$ make phytium_e2000_ubuntu_defconfig or make phytium_e2000_defconfig`  
（2）编译  
`$ make`  
（3）镜像的输出位置  
生成的根文件系统、内核、bootloader位于output/images目录。  

## 清理编译结果
（1）`$ make clean`  
删除所有编译结果，包括output目录下的所有内容。当编译完一个文件系统后，编译另一个文件系统前，需要执行此命令。  
（2）`$ make distclean`  
重置buildroot，删除所有编译结果、下载目录以及配置。  

# 在e2000开发板上启动文件系统
## 使用U-Boot启动文件系统
（1）主机端将文件系统和内核拷贝到SATA盘或U盘（以dev/sdb1分区为例）  
```
$ sudo mkfs.ext4 /dev/sdb1
$ sudo mount /dev/sdb1 /mnt
$ sudo cp xxx/phytium-linux-buildroot/output/images/rootfs.tar /mnt
$ cd /mnt
$ sudo tar xvf rootfs.tar
$ cd xxx/phytium-linux-buildroot/output/images
$ sudo cp Image e2000q-miniITX.dtb.dtb /mnt/boot
$ sync
$ sudo umount /dev/sdb1
```

（2）SATA盘或U盘接到开发板，启动开发板电源，串口输出U-Boot命令行，设置U-Boot环境变量，启动文件系统  
SATA盘：  
```
=>mw 0x32b30164 0x44; mw 0x32b30168 0x44; mw 0x31a30038 0x3; mw 0x2807e0c0 0x00
=>setenv bootargs console=ttyAMA1,115200  audit=0 earlycon=pl011,0x2800d000 root=/dev/sda1 rw
=>ext4load scsi 0:1 0x90100000 boot/e2000q-miniITX.dtb
=>ext4load scsi 0:1 0x90200000 boot/Image
=>booti booti 0x90100000 - 0x90000000
```
