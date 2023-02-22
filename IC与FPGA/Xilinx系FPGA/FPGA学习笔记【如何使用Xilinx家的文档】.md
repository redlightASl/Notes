# 常用Xilinx官方文档

一般可以直接使用**DocNav**查看文档，也可以在Xilinx官网查看文档。Xilinx的文档和其他公司差不多，都遵循相同缩写描述相同类型的东西，常用的缩写如下：

* **UG**：User Guide，用户手册。最常用的文档，提供器件/IP/软件使用的各种基本知识和使用方法，遇到不会的问题第一时间参考UG文档往往可以获得解决思路
* **WP**：White Paper，白皮书。常用文档，代表Xilinx官方立场的规范性技术文件，也可能充当广告角色。一些官方推荐的新产品会以白皮书的形式给出特性介绍
* XAPP：Xilinx Application，Xilinx示例应用。主要是对IP核的使用进行介绍，提供模板工程，用户可以在上面修改；还提供相关介绍，遇到应用问题时可以参阅、
* **XMP**：Xilinx Manual Product，产品手册。比较常用的文档，提供基本的产品介绍、性能对比图、结构框图等，可以用于辅助器件选型（虽然一般都直接用官网上的搜索筛选进行选型）
* **PB**：Product Brief，产品简介。比较常用的文档，可能是芯片或IP核的基本介绍。适合用于产品选型
* XTP：Xilinx Tools Product，开发套件手册。提供了很多官方/合作方评估板和开发板、开发套件的介绍，适合用于购买开发板的选型
* RPT：Report，报告。分为*特性*报告和*合格性*报告，分别描述相关IP核或接口的特性
* **EN**：Errata Notification，勘误。一般来说文档的开头和结尾都会保存文档的更新记录，所以这个东西通常只有在软件大版本更新或硬件资料出现严重问题时才会发布，是对之前文档资料的debug
* AR：Answer Record，对Xilinx社区中的技术问题问答的总结
* PK：Package封装，主要描述器件的封装规格
* **DS**：Data Sheet，数据手册。和产品规格书是类似的，都用于描述芯片的主要功能或简单介绍IP核的原理/实现

## 常用的Xilinx文档

本人经常用到的Xilinx文档列举如下：

### Spartan-7 系列

**ug973**：Vivado套件安装手册

**ug892**：Vivado设计流程概述

**ug896**：Vivado的IP核（IP Catalog功能）使用简介

**ug903**：Vivado的XDC约束使用简介核语法介绍

ds189：Spartan-7的数据手册

wp483：Spartan-7的特性介绍

ug1291：Vivado独立仿真流程

**ug1283**：7系列FPGA启动流程介绍

**ug471**：7系列FPGA的接口SelectIO资源（IOB）介绍

**ug472**：7系列FPGA的全局时钟资源（Digital Clock Manager，DCM）介绍

**ug473**：7系列FPGA的片上内存资源BRAM（块RAM）介绍

**ug474**：7系列FPGA的可重配置逻辑块资源（Configuable Logic Block，CLB）介绍

ug1118：封装自定义IP简介

xapp495：TMDS接口的简介（原示例用在Spartan-6上）

### Artix-7系列

**ug953**：7系列FPGA的仿真库使用手册

**ug1037**：Vivado的AXI相关IP使用简介和AXI总线介绍

**ug479**：7系列FPGA的片上DSP资源（DSP48E1 Slice）介绍

ug480：7系列FPGA的片上XADC双12位1MSPS ADC用户手册

ug898：Vivado的嵌入式设计指南

**ug482**：FPGA内嵌GTP收发器用户手册

ug894：Vivadao的TCL脚本使用指南

ug899：IO和时钟规划指南

### ZYNQ-7000系列

**ug585**：ZYNQ-7000用户手册

**ug821**：ZYNQ-7000软件开发手册

ug865：ZYNQ-7000引脚定义

**ug1165**：嵌入式ZYNQ开发用户手册

**ug1144**：petalinux工具用户手册

**ug940**：Vivado-Vitis工具嵌入式开发快速入门手册

ug1233：Xilinx移植版opencv使用指南

ug873：基于SDK的旧版Zynq使用手册

**ds190**：ZYNQ-7000系列简介

pg021：AXI-DMA的IP核介绍

pg078：AXI-BRAM的IP核介绍

pg160：、GMII、RGMII网口IP介绍

**xapp1078**：Cortex-A9运行嵌入式Linux示例

xapp742：AXI-VDMA的示例

XAPP1247：7000系列FPGA的MultiBoot（相当于OTA）技巧

### Kintex-7系列

**ug906**：Vivado时序分析与收敛技巧指南

**ug901**：Vivado综合器指南

**ds176**：7系列FPGA的内存接口（AXI-MIG）介绍

ug871：HLS教程

### 硬件设计相关

**ds187、ds191**：7系列FPGA的电源设计指南（电气性能指南）

**ug483**：7系列FPGA的PCB设计指南

**ug933**：ZYNQ系列的PCB设计指南

wp484：Spartan-7和Artix-7的低功耗DDR布局设计