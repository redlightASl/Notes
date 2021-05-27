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

目前官方PYNQ只支持PYNQ-Z1、PYNQ-Z2和一些高端的Zynq开发板（1k RMB以上，穷b学生根本买不起），所以如果是自己买了/画了便宜的Zynq开发板，很多时候就需要自己编译出一份PYNQ镜像，通过SD卡来安装

### 硬件需求

对于PYNQ应用，开发板至少需要有以下硬件：

* 核心必须是Xilinx家的ZYNQ系列，也就是说要包含软核和硬核

  其实只要有ZYNQ SoC的最小系统就可以使用PYNQ了，只不过没有以太网会很不方便

* ZYNQ附属的最小系统，包括用于PL端的DDR3、DDR4等和用于加载PL端比特流的SPI FLASH

  其中DDR大小至少要有512MB

* SD卡槽

* 以太网接口

* BOOT切换跳线/开关

* BOOT切换跳线/开关

* 串口/JTAG调试接口引出

### 自定制PYNQ镜像文件

按照[官方文档](https://pynq.readthedocs.io/en/latest/getting_started.html)的介绍就可以根据自己开发板的资源定制一套PYNQ镜像文件，搭建自定义的PYNQ系统主要需要两个必备材料

* rootfs文件：这是一份不含内核信息的Linux镜像，包含了PYNQ所需的软件，其中ZYNQ 7000+需要使用arm镜像；ZYNQ UltraScale+徐娅使用aarch64镜像，简而言之这就是PYNQ的大脑
* 开发板的板级描述文件：PetaLinux根据这些文件生成对应的嵌入式Linux内核，并和rootfs文件放在一起构成完整的基于ZYNQ PL+PS协同的Linux软硬件系统。板级描述文件可以使用两种方式提供
  * 直接提供BSP文件（也就是下文中使用官方库提供的脚本生成/从官网下载的标准BSP，只支持PYNQ-Z1、Z2和一些其他的板子，不一定支持我们买到的便宜板子（甚至是矿板））
  * 提供比特流文件和hdf文件

下面分析一下整体流程

1. 从GitHub的开源Repository中获取sd卡编译文件

   相关SDK被放置在\<PYNQ repository\>/sdbuild目录下

   目录的README文档中已经写了一些注意事项，摘录如下

   > It's highly recommended to run these scripts inside of a virtual machine. The image building requires doing a lot of things as root and while every effort has been made to ensure it doesn't break the world this is far from guaranteed.This flow must be run in a Ubuntu based Linux distribution and has been tested on Ubuntu 16.04 and Ubuntu 18.04. Other Linux versions might work but may require different or additional packages. The build process is optimised for 4-cores and can take up to 50 GB of space.
   > 
   > 推荐使用虚拟机运行脚本，这些镜像构建需要root权限。流程已经在Ubuntu 16.04和Ubuntu 18.04中得到了测试，为保险起见应使用Ubuntu执行脚本，其他发行版可能会存在依赖问题。此外构建步骤需要4核处理器（再怎么说也得来个能用的赛扬）并且至少需要50G的硬盘空间
   
   这步其实不是必须的，
   
   * 
   
2. 为了完成README文档所说的注意事项，我们需要先准备一个编译环境

   官方推荐安装以下系统的虚拟机：

   | Supported OS | Code name |
   | ------------ | --------- |
   | Ubuntu 16.04 | xenial    |
   | Ubuntu 18.04 | bionic    |

   可以选择安装Ubuntu或者使用虚拟机（玩嵌入式怎么能不来个双系统/纯Linux系统呢！虚拟机没有灵魂！当然可以尝试白嫖学校实验室的电脑装Ubuntu）

   如果选择使用安装Ubuntu，无论是双系统还是猛男直接上，需要的步骤都很简单了，直接下一步吧

   如果选择使用虚拟机，还需要安装vmtool/vagrant-vbguest等操作来获得舒畅的使用体验，建议先放下这个教程去查查虚拟机里linux的优化，并按照官网给出的建议实施

3. 使用\<PYNQ repository\>/sdbuild/scripts/setup_host.sh脚本在已有的Ubuntu系统中进行环境配置

   可以在bash shell里直接执行

   ```shell
   sudo ./setup_host.sh
   ```

   如果用zsh、csh的话要先切bash shell再执行脚本

4. 最折磨人的配环境！编译一套PYNQ你需要如下软件环境：

   * PetaLinux：用于在Xilinx家SoC上定制编译嵌入式Linux的SDK
   * Vivado：Xilinx的王牌软件，懂得都懂，不懂就去百度
   * Vitis：Xilinx专门用于SoC软件开发的一套东西，写ZYNQ软件的时候要和它打交道

   每一个软件都是吃硬盘大户（悲）

   所有安装教程都能在Xilinx官方文档或者百度/google/bing上找到教程

   如果是老ZYNQ用户（指配环境大师），应该都已经有这些软件了

   完事以后还要把PetaLinux和Vitis的相关设置导出，官方给出了以下示例

   ```shell
   source <path-to-vitis>/Vitis/2020.1/settings64.sh
   source <path-to-petalinux>/petalinux-2020.1-final/settings.sh
   petalinux-util --webtalk off
   ```

   注意：检查Vivado的licenses，因为需要调用Xilinx IP库里面的HDMI IP

5. 配完环境以后就可以开始make了

   这是骷髅宝宝都会的操作！

   ```shell
   cd <PYNQ repository>/sdbuild/
   make
   ```

   需要注意一点：这套操作包括了综合IP核、实现PS-PL协同与AMBA总线、实现片上硬件系统、导出比特流、编译整个嵌入式Linux内核、编译生成一堆软件和依赖......所以“**这个操作可能会花费数个小时**”





### 编译镜像







### 刻录镜像到SD卡







### 安装SD卡、配置网络、连接上位机







### 使用PYNQ







