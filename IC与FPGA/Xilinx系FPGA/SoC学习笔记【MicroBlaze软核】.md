# Microblaze软核

本篇博文介绍如何在Zynq中使用Microblaze软核。包括PicoRV、E203、Cortex-M0、light52等各种架构的软核都可以用类似的方式部署在Zynq-PL部分。

部署一个软核的最基本方法就是在FPGA上实现一个SoC，将**软核**、**RAM**、**片上总线**、至少一个**片上外设**例化到顶层模块并配置约束，同时使用厂商提供的API将hex/bin/其他格式的可执行汇编文件放进片上**ROM**中，完成综合布线后将得到的比特流文件烧录到FPGA中。FPGA上电后会自动加载外部NVM（泛指非易失性存储器）中存储的比特流，SoC需要的ROM在加载的同时就完成了初始化，等待软核CPU读取

但是对于ZYNQ器件，上电首先加载的是FSBL，它包含了PL端的所有配置项，这个程序是由PS端的Cortex-A核执行的，并且可以从各种地方完成加载和动态重配置







## 硬件部分









## 软件部分



