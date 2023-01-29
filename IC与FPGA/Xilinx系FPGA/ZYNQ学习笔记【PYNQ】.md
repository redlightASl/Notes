# PYNQ从入门到入土

来自官方文档的简介概括如下：

>PYNQ is an open-source project from Xilinx that makes it easy to design embedded systems with Zynq All Programmable Systems on Chips (APSoCs). Using the Python language and libraries, designers can exploit the benefits of programmable logic and microprocessors in Zynq to build more capable and exciting embedded systems.

**PYNQ**是Xilinx推出的一个开源项目，目的是让开发者使用Python开发Xilinx全可编程平台（主要是ZYNQ系列SoC），软件开发者能更便捷地使用Python对已有算法进行硬件加速与FPGA设计

[开源项目地址](https://github.com/Xilinx/PYNQ)

PYNQ是**Python Productivity for Zynq**的缩写

PYNQ使设计嵌入式系统架构师、工程师和程序员可以只使用Zynq器件和Xilinx的FPGA开发IDE而不必使用ASIC风格的设计工具来设计可编程逻辑电路。PYNQ 通过三种方式实现此目标：

1. 可编程逻辑电路作为名为**overlay**的*硬件库*提供，软件工程师可以选择最适合其应用程序的overlay，并通过相关API访问overlay。overlay像软件库一样，被设计为可配置并在许多不同的应用程序中尽可能频繁地重复使用

   overlay模型的实现借鉴于Linux内核模型，将底层完全封装

   缺点：创建新的overlay仍然需要具有设计FPGA电路专业知识的工程师

2. PYNQ使用Python对嵌入式处理器和overlay进行编程。PYNQ使用C编写的CPython解释器，并集成了大量的C库，可以使用C编写的优化代码进行扩展。在可行的情况下，应使用更便于算法和顶层应用软件开发的Python环境；而在效率要求时，可以使用更靠近底层C代码。

3. PYNQ是一个开源项目，旨在在任何计算平台和操作系统上工作。通过采用基于Web的体系结构实现此目标——该体系结构与浏览器无关——PYNQ并入了开源的Jupyter notebook基础架构，可以直接在Zynq设备的ARM硬核处理器上运行IPython内核和Web服务器。Web服务器通过一组基于浏览器的工具代理访问内核，这些工具提供了dashboard、bash终端、代码编辑器和Jupyter notebooks工具。浏览器工具通过JavaScript、HTML和CSS实现，可以在任何现代浏览器上运行。

注意：**PYNQ并不是通过Python语言直接对FPGA进行编程**

在PYNQ框架下并不能通过Python对FPGA进行编程来取代传统的RTL编程方式，PYNQ只是为了软件工程师能够低门槛地使用FPGA，获取并行计算和可灵活配置等优点，而各种基于FPGA实现的类ASIC应用依然需要专业的硬件工程师通过Vivado和相关工具进行开发

## PYNQ系统架构

PYNQ系统架构分为三层，分别是以FPGA设计为主的**硬件层**、以Linux内核与Python为主的**软件层**，以及以Jupyter Notebook为主的**应用层**

硬件层的设计与嵌入式设计方法相同，都是为了实现PS与PL的协同交互。整个FPGA部分的设计被称为overlay，可面向多用户、多应用生成不同的bitstream文件，并可以通过软件API进行调用，动态切换FPGA上的逻辑功能

软件层运行在ZYNQ的PS端，主要由Ubuntu操作系统和构建在Ubuntu操作系统中的Python构成。PYNQ的API库则起到了连接软硬件的作用，使开发者可以通过Python访问PL侧的处理单元

应用层主要由运行在Python之上的Jupyter Notebook和IPython构成。其中Jupyter Notebook在网络浏览器中运行，通过上位机的浏览器访问运行在ZYNQ的PS端的Linux系统上的Python里的Jupyter Notebook，就可以对PYNQ进行软件部分的开发

PYNQ应用同时包含了硬件设计和软件驱动，比如PL bitstreams和Python包，用户必须要同时部署这两部分内容才能顺利运行起来

## 使用便宜的Zynq开发板构建PYNQ

目前官方PYNQ只支持PYNQ-Z1、PYNQ-Z2和一些高端的Zynq开发板（1k RMB以上，穷b学生根本买不起），所以如果是自己买了/画了便宜的Zynq开发板，很多时候就需要自己编译出一份PYNQ镜像，通过SD卡来安装；如果想把PYNQ应用在工程中，自然也需要自行编译PYNQ镜像。

### 硬件需求

对于PYNQ应用，开发板至少需要有以下硬件：

* 核心必须是Xilinx家的ZYNQ系列，至少得是ZYNQ-7000，官方推荐使用ZU系列来跑一些需要神经网络加速的应用（可能是因为ZU系列资源更充足，也可能是因为ZU系列都会带有更强大的CPU硬核）

* ZYNQ附属的最小系统，包括用于PL端的DDR3、DDR4等和用于主动加载PL端比特流的SPI FLASH。以太网、USB、声卡等都是可选的，但是为了方便使用一般会把以太网子系统包括进去

  其中DDR大小至少要有512MB，太小的RAM带不动Ubuntu

* SD卡槽，PYNQ需要从SD卡启动（除非使用petalinux二次定制）

* BOOT切换跳线/开关

* 串口/JTAG调试接口引出

### 自定制PYNQ镜像文件的环境配置

> 以下所有流程均基于当前最新版本PYNQ-3.0.1（git branch为**v3.0.1**）
>
> 硬件环境如下：AMD R5-**5600g**（amd64），宿主机为**Windows10**专业版，采用**VirtualBox**虚拟机方案
>
> 软件环境如下：**Ubuntu20.04、Vivado2022.1、Vitis2022.1、Petalinux2022.1**

按照[官方文档](https://pynq.readthedocs.io/en/latest/getting_started.html)的介绍就可以根据自己开发板的资源定制一套PYNQ镜像文件，搭建自定义的PYNQ系统主要需要三个必备材料

* rootfs文件：这是一份不含内核信息的Linux根文件系统镜像，包含了PYNQ所需的软件，其中ZYNQ 7000+需要使用arm镜像；ZYNQ UltraScale+需要使用aarch64镜像。根文件系统的重要性不必多言，这个文件实际上是Xilinx的魔改版Ubuntu16.04，很多软件（指底层C库和一些基于C的上层应用）层面支持都已经在这里统一，因此上层的Jupyter Notebook和底层硬件驱动可以解耦。

    如果需要移植PYNQ到自己的开发板上，那么这个文件一般是不需要改动，只要从官网下载合适版本的就可以了

* sdist文件：这是PYNQ的Python源码文件合集（sdist表示Source Distribution软件发行版），可以用来加速编译过程

* 开发板的板级描述文件：PetaLinux根据这些文件生成对应的uboot、Linux内核，并和rootfs文件放在一起构成完整的基于ZYNQ PL+PS协同的Linux软硬件系统，最后把sdist文件解压后扔进目录，从而构成完整的PYNQ系统。板级描述文件可以使用两种方式提供
  * 直接提供BSP文件（也就是下文中使用官方库提供的脚本生成/从官网下载的标准BSP，只支持PYNQ-Z1、Z2和一些其他的板子，不一定支持我们买到的便宜板子（甚至是矿板））
  * 提供比特流文件和hdf文件（老版本）/xsa文件（新版本），自行组织BOARD_BSP目录和BSP文件

下面分析一下整体流程

1. 从GitHub的开源[Repo](https://github.com/Xilinx/PYNQ)中获取sd卡编译文件

   相关SDK被放置在\<PYNQ repository\>/sdbuild目录下

   目录的README文档中已经写了一些注意事项，摘录如下

   > It's highly recommended to run these scripts inside of a virtual machine. The image building requires doing a lot of things as root and while every effort has been made to ensure it doesn't break the world this is far from guaranteed.This flow must be run in a Ubuntu based Linux distribution and has been tested on Ubuntu 16.04 and Ubuntu 18.04. Other Linux versions might work but may require different or additional packages. The build process is optimised for 4-cores and can take up to 50 GB of space.
   > 
   > 推荐使用虚拟机运行脚本，这些镜像构建需要root权限。流程已经在Ubuntu 16.04和Ubuntu 18.04中得到了测试，为保险起见应使用Ubuntu执行脚本，其他发行版可能会存在依赖问题。此外构建步骤需要4核处理器（再怎么说也得来个能用的赛扬）并且至少需要50G的硬盘空间

   这步其实不是必须的，用户可以自行构建一个基于ubuntu20的项目，但需要更改很多环境配置，因此不推荐使用除了ubuntu 16和18以外的任何版本构建pynq

2. 为了完成README文档所说的注意事项，我们需要先准备一个编译环境

   官方推荐安装以下系统的虚拟机：

   | Supported OS | Code name |
   | ------------ | --------- |
   | Ubuntu 16.04 | xenial    |
   | Ubuntu 18.04 | bionic    |
   | Ubuntu 20.04 | Focal     |

   可以选择安装Ubuntu或者使用虚拟机

   > ~~玩嵌入式怎么能不来个双系统/纯Linux系统呢！虚拟机没有灵魂！当然可以尝试白嫖学校实验室的电脑装Ubuntu~~
   >
   > 如果你想要正常使用PYNQ，建议不要折腾Linux实体机——因为这个东西的环境实在太难配了，还有很多莫名其妙的BUG，而且你永远不知道哪个版本适合你的PC，能随时删掉重装的虚拟机是最稳妥的选择

   如果选择使用安装Ubuntu，无论是双系统还是直接上实体机Linux，需要的步骤都很简单了，直接下一步吧

   如果选择使用虚拟机，还需要安装vmtool/vagrant-vbguest等操作来获得舒畅的使用体验，建议先放下这个教程去查查虚拟机里linux的优化，并按照官网给出的建议实施

   **虚拟机的大小建议为500GB**，因为需要装一大堆软硬件工具和各种依赖包、配置工具

   > 官方推荐使用VirtualBox，笔者也赞同——因为不需要折腾太多VMware的“特性”

3. 使用\<PYNQ repository\>/sdbuild/scripts/setup_host.sh脚本在已有的Ubuntu系统中进行环境配置

   可以在bash shell里直接执行

   ```shell
   sudo ./setup_host.sh
   ```

   **如果用zsh、csh的话要先切bash shell再执行脚本**

   > 使用Dash的Ubuntu也要记得先把默认shell切换成原生bash，否则可能会出现一些莫名其妙的问题

4. 最折磨人的配工具环境！编译一套PYNQ你需要如下软件环境：

   * PetaLinux：用于在Xilinx家SoC上定制编译嵌入式Linux的SDK
   * Vivado：Xilinx的亡牌软件，懂得都懂，不懂就去百度
   * Vitis：Xilinx专门用于SoC软件开发的一套东西，写ZYNQ软件的时候要和它打交道

   每一个软件都是吃硬盘大户（悲）

   所有安装教程都能在Xilinx官方文档或者百度/google/bing上找到教程

   如果是老ZYNQ开发者（指配环境大师），应该都已经有这些软件了

   完事以后还要把PetaLinux和Vitis的相关设置导出，官方给出了以下示例

   ```shell
   source <path-to-vitis>/Vitis/2020.1/settings64.sh
   source <path-to-petalinux>/petalinux-2020.1-final/settings.sh
   petalinux-util --webtalk off
   ```

   注意：检查Vivado的licenses，因为PYNQ的硬件综合实现过程中需要调用Xilinx IP库里面的*HDMI IP*

5. 从[PYNQ官网的Board页面](www.pynq.io/board.html)下载rootfs和sdist

   从页面向下翻就可以找到**PYNQ rootfs aarch64/arm v3.0.1**两行，它们分别是用于zu和z7000的rootfs和通用的PYNQ软件包

   > 这一步操作必须用梯子，因为pynq.io的服务器在国外，不用梯子这辈子都不要想下载到文件
   >
   > rootfs的另一个获取方式是通过xilinx官网的下载url，格式如下所示
   >
   > ```
   > https://www.xilinx.com/member/forms/download/xef.html?filename=pynq_rootfs_aarch64_v2.x.zip
   > ```
   >
   > 或类似下面的格式
   >
   > ```
   > https://www.xilinx.com/member/forms/download/xef.html?filename=pynq_rootfs_arm_v3.0.1.zip
   > ```
   >
   > 最后`filename=`一项指明要下载哪个rootfs
   >
   > 但这个方式无法下载sdist，所以还是要用最新版本的sdist

6. 将rootfs和sdist复制到指定位置并重命名

   ```shell
   cp pynq_rootfs.<arm|aarch64>.tar.gz <PYNQ repository>/sdbuild/prebuilt/pynq_rootfs.<arm|aarch64>.tar.gz
   cp pynq-<version>.tar.gz <PYNQ repository>/sdbuild/prebuilt/pynq_sdist.tar.gz
   ```

   也就是`sdbuild/prebuilt`目录

   注意：下载下来的文件格式可能不同，必须使用压缩并打包过的`.tar.gz`格式，脚本才能够正确识别；而且**文件名要和上面所说文件名一致**

7. 确定要编译的是哪个BSP，把参数加进make指令里

   使用参数`PREBUILT`来指定要使用的rootfs，这里默认使用了预编译的默认命名rootfs，就不需要加进去

   使用参数`BOARDS`来指定编译的BSP目标，这里选择Pynq-Z2

   使用参数`REBUILD_PYNQ_SDIST`来指定是否使用预编译的sdist，这里选择False，就不用加了

   使用参数`REBUILD_PYNQ_ROOTFS`来指定是否使用预编译的rootfs，这里选择False，就不用加了

8. 把所有环境都配完以后就可以开始make了

   这是骷髅宝宝都会的操作！

   ```shell
   cd <PYNQ repository>/sdbuild/
   make BOARDS=Pynq-Z2
   ```

   需要注意一点：这套操作包括了综合IP核、实现PS-PL协同与AMBA总线、实现片上硬件系统、导出比特流、编译U-Boot和整个嵌入式Linux内核、解压根文件系统、下载并安装PYNQ的基础Python包、编译生成一堆软件和依赖......所以“**这个操作可能会花费数个小时**”

   这里先使用Pynq-Z2开发板作为验证。

   **如果不出意外的话，编译过程中肯定会出意外，可以参考后面给出的Debug过程和其他博文来尝试解决**

如果编译通过，那么就可以转到后面刻录镜像到SD卡部分，上板验证

### 自定制镜像

> 如果读者需要自定制PYNQ，建议先按照上面的流程走一遍，确认自己的环境是正确无误的，并且对于PYNQ构建工具有一个基本的了解，再看本节

如果要把PYNQ部署到自己的开发板或某些核心板上，就需要自定制片上硬件，封装成板级描述文件（由xsa文件、比特流文件、符合PYNQ格式的bsp描述文件、设备树dtb/dts文件、编译后的设备驱动等共同组成的树状目录）。PYNQ根目录下的`boards`目录中就存储了PYNQ-Z1、PYNQ-Z2、ZCU104三个设备的板级描述文件

一个合法的最小板级描述文件结构如下所示：





首先需要使用Vivado构建片上PL部分的比特流和PS部分的外设配置，如果调用了Microblaze或是使用了动态重配置功能还需要预先合并比特流。如果需要编辑bootloader，则切换到Vitis中对基础的FSBL进行编辑即可，Xilinx也提供了示例工程。

所有可能的片上电路（比特流）和PL端的嵌入式代码（bin文件）都要以FSBL方式进行合并，预先使用petalinux封装到一起，以比特流和xsa的形式放置到板级描述文件目录中，PYNQ工具在构建过程中会自动调用

随后要准备rootfs和sdist，这一步在上面也提到过，不再赘述。需要注意的是**PYNQ的rootfs不推荐开发者自行编辑**，因为可能会由于引入新的依赖导致Kernel Panic。如果需要在PYNQ中删除不必要的软件包或引入ROS之类的中间件软件包，应当首先使用仿真环境运行，检查依赖后再实际配置。sdist文件是可以自行删改的，但也要注意python包中的依赖问题

PYNQ提供了自启动Python脚本功能，用户只需要编写一个叫`boot.py`的脚本，放置到板级描述文件目录的对应位置即可在系统启动后自动执行里面的代码

最麻烦的步骤是编辑Linux设备树和编写/编译Linux外设驱动。这一步需要使用到Vitis和Petalinux工具。PYNQ会自动调用Petalinux来完成Linux内核和U-Boot的构建，也就导致开发者要提前向PYNQ传递Linux设备树和外设驱动信息。Xilinx提供了完整的PS端外设Linux驱动和大部分常见的PL端Xilinx IP驱动，如果是开发者自行编写的IP，就需要自己搞定Linux驱动问题了，这一点和其他嵌入式Linux开发是一样的。

开发者要提前编写好设备树，并且把内核驱动编译成.ko文件（这一步一般要使用Vitis），再把它们放到板级描述文件目录的对应位置。其实这一步虽然麻烦但并不必要——用PYNQ的目的就是简化嵌入式Linux开发流程，如果用到PL端的自定义IP，其实只要提前制作好Overlay文件在后面部署时调用即可

如果开发过程涉及到了Linux内核驱动，Xilinx官方推荐直接扔掉PYNQ框架，使用Petalinux和Vitis进行部署，最后利用PYNQ单独构建rootfs，可以参考PYNQ中的markdown文件

最后一步是编写bsp描述文件，一个基本的`my_pynq.bsp`文件格式如下

```shell

```

按照基本目录结构构建完毕后 ，就可以按照正常流程进行构建编译生成镜像

### Debug过程











### 刻录镜像到SD卡

SD卡需要事先格式化好

最繁琐、正规的方式是**在Linux下进行分区**，因为需要使用到`ext4`文件系统，**Windows下不好分区烧录，推荐使用一键刻录工具烧录编译出的镜像文件**

简单说一下步骤：

1. 插卡，格式化，这一步注意备份卡里的已有数据

   ```shell
   sudo umount /dev/mmcblk0
   # 这里要选择/dev目录下面以文件形式存在的SD卡
   # 如果使用电脑自带的SD读卡器，一般会是mmcblk开头的设备
   # 如果使用USB读卡器，可能会是sdb开头的设备
   
   sudo fdisk /dev/mmcblk0
   # 使用Linux下的fdisk工具打开设备
   ```

   第一步umount是为了卸载已经插入电脑的sd卡文件系统

   > Linux基于“万物皆文件”的思想，会把存储设备sd卡抽象成“块设备”文件，存在/dev/位置，而运行在这个设备上的文件系统需要通过“挂载”的方式加入操作系统，没挂载的文件系统只是一堆杂乱无章的数据，只有挂载到操作系统某个目录（一般选择/mnt目录或者/media/<user_name>/目录）的文件系统才能被Linux读取，使用mount进行文件系统挂载，使用umount进行卸载

   fdisk是一个Linux下的命令行硬盘处理工具，提供了和disk genius这样硬盘处理工具类似的格式化功能，只不过很难用他进行数据恢复数据备份等工作

   如果用过Arch Linux的话应该对fdisk不陌生，装系统的时候就要用它进行格式化

   进入fdisk以后可以使用`m`获取帮助信息，如果忘记了某条指令可以直接输入m

   **输入`p`指令查看现有sd卡的分区，可以查看到空间大小等数据，注意在这一步确认打开的是不是sd卡**

   如果打开错误，直接使用`q`指令退出工具，将不会导致任何问题

   如果确认好，可以直接使用`d`指令删除分区

   一定要把sd卡上所有分区都删除，直到出现报错“无法继续删除分区”

2. 建立新分区

   使用`n`指令新建一个分区，这个分区我们会命名为**BOOT**，格式化成FAT32，大小会是500MB，用来存储Zynq所需的启动数据，包括FSBL和比特流文件

   在接下来的选项中通过选择p使其为主分区，使用默认分区号1和第一个扇区；设置最后一个扇区，也就是设置第一个分区的大小为500MB，通过输入`+500M`（加号不要忘记，最后的M也不要忘记），这样就能为该分区预留出500MB空间

   这样一个基本分区就格式化好了（实际上是在修改分区表）

   接下来输入`t`指令，然后选择`c`，这样就能设置本分区为“W95 FAT32 (LBA)”格式

   可以在输入t指令后使用`l`指令查看可选的分区格式

   最后使用`a`指令将本分区设置为引导分区

   然后重复上述步骤建立第二个分区，这个分区在之后会被命名为**rootfs**，格式化成ext4格式用于存储pynq上的根文件系统

   这次在使用n指令后只需要保持默认选项——一路回车就可以了，建立完分区后也**不需要**使用t指令、a指令，而是使用p指令查看分区表，如果没有错误直接退出就可以了，如果出现错误也可以直接使用d指令删除刚才创建的分区或者使用q指令不保存分区表地退出程序

3. 上述步骤中如果没有观察到错误，可以直接使用以下指令格式化文件系统

   ```shell
   sudo mkfs.vfat -F 32 -n BOOT /dev/mmcblk0p0
   sudo mkfs.ext4 -L rootfs /dev/mmcblk0p1
   ```

   分别格式化为FAT32和ext4，并且命名为BOOT分区和rootfs分区

4. 重新挂载sd卡，查看是否可以进行文件读写

5. 将之前生成的启动文件直接复制粘贴到BOOT分区，将pynq根文件系统解压后直接复制到rootfs分区

6. 卸载文件系统，拔出sd卡

   这样就完成了刻录流程！

上面的流程是最标准的，而PYNQ常常会编译出一个`.img`镜像文件，我们处理这个文件只需要将其用dd指令写入sd卡即可，如下所示

```shell
sudo dd if=./pynq.img of=/dev/sdb
```

需要注意这里使用的sd卡必须是经过格式化且没有分区的才行

### 安装SD卡、配置网络、连接上位机

这一步就不多说了，主要讲一下不使用pynq自带的python脚本如何配置网络

上电以后用串口连接，登录账号和密码都是`xilinx`

如果使用了有线网络，一般直接就能上网，最多需要自己配置ip，使用下面的指令

```shell
ifconfig eth0 192.168.1.2
```

这里eth0的位置是插上网线后的网口名，一般是eth0或eth1，后面的192.168.1.2可以换成任意在内网同一网段的ip地址

如果不用有线网，那你需要一个usb无线网卡，将它连到板子引出的usb口；或者用一个无线模块，通过其他引脚接入，不过这样就还需要在linux内核里面加入对应的驱动，还要在之前的定制过程中加入特定的设备树文件。

总之，我们现在弄到了一个能连wifi的东西，使用`ifconfig`可以发现对应的wlan0（或其他称呼）没有ip地址，甚至wlan0根本不存在，这样就需要用下面的指令打开wlan设备

```shell
sudo -S wpa_supplicant -D nl80211 -i wlan0 -c /etc/wpa_supplicant.conf -B
```

这里用到了`wpa_supplicant`工具，pynq会自带这个软件包。如果实在没有，可以使用`iwconfig`工具

这里的意思是使用nl80211驱动，根据/etc/wpa_supplicant.conf的配置来初始化wlan0接口，完成这一步以后网卡就会启动，如果有指示灯，这时候网卡的指示灯应该就会闪烁

完成以后就可以使用

```shell
sudo wpa_cli -i wlan0 scan
```

扫描附近的wifi了

如果扫描到在/etc/wpa_supplicant.conf配置过的wifi，那么会自动连接

之后使用

```shell
do dhclient wlan0
```

就能完成dhcp，自动获取ip地址，也就能够上网啦

> 补充一下wpa_supplicant.conf的设置
>
> ctrl_interface=/var/run/wpa_supplicant
> update_config=1
> network={ 
> 		ssid="要连接的wifi名"
>            psk="要连接的wifi密码"
> } 

对于连接上位机，更简单，直接ssh就可以了，如果不嫌弃还能直接走telnet，也能直接用vscode访问上面的文件系统——pynq默认带了ssh、scp。除此之外，在上位机打开浏览器，输入`http://pynq:9090`，就可以打开jupyter notebook的登陆页面，可以用jupyter notebook控制整个pynq

### 使用PYNQ





