# 前置知识：USB协议

**USB**即**通用串行总线**（Universal Serial Bus），到现在已经发展到4.0，目前经常使用的协议标准是2.0、3.0版本（4.0版本目前仅在高端设备上有出现，且全部使用USB type-C物理接口）。标准的USB由四根线组成：VBUS、GND、D+（DP）、D-（DN），其中D+和D-是数据线，采用**差分传输**的方式。

**stm32的USB接口支持到2.0，不支持3.0及以上，下面的介绍均针对USB2.0协议**

USB分为主机和从机，在**主机上，D+、D-都通过15K电阻下拉到地**，在没有设备接入时，信号线均为低电平；**从机则会通过D+上拉1.5K电阻表示高速设备接入，通过D-上拉1.5K电阻表示低速设备接入**，主机可以通过从机设备接入前后D+、D-的电平变化检测设备是高速设备还是低速设备。

STM32F4系列MCU自带USB OTG FS（全速USB2.0协议，12Mb/s）和USB OTG HS（高速USB2.0协议，1.5Mb/s）的控制器，但是**其中HS需要外接高速PHY芯片才能实现**，实现方式和FS大同小异，这里仅以FS控制器为例：STM32F4的USB OTG FS控制器支持USB2.0的双模式接入，可以配置为*仅主机*、*仅从机*、*主从机*三种模式，但是主机模式下支持全速（12Mb/s）和低速（1.5Mb/s）收发器，从机模式下仅支持全速收发器。控制器还配备了1.25KB的专用RAM、生成VBUS电压的外部电荷泵。

此外主机控制器还配备以下硬件：

* 8个可动态重配置的主机通道
* 一个硬件调度器，可以在周期性和非周期性硬件FIFO中存储总共8+8=16个中断、控制、批量、同步传输请求
* 一个共享RX FIFO
* 一个周期性TX FIFO
* 一个非周期性TX FIFO

从机控制器配备以下硬件：

* 一个双向控制端点
* 3个IN端点和3个OUT端点
* 一个共享RX FIFO
* 一个TX-OUT FIFO
* 4个专用TX-IN FIFO

# STM32的USB OTG

ST在STP库中提供了用于USB OTG的库函数

一般来说需要编写USB驱动才能使用STM32的USB外设，但是ST提供了完整的驱动库来实现USB功能，只要将其移植到自己的工程就可以使用USB功能了。官方的USB库包含以下主要文件（以从机设备为例）：

* usb_bsp.c/h：USB板级支持包
* usbd_usr.c/h：用户应用层代码
* usbd_storage_msd.c/h：磁盘操作代码
* usbd_desc.c/h：USB从机设备描述符
* usb_dcd_int.c/h、usb_dcd.c/h：USB从机底层驱动
* usb_core.c/h：USB通用驱动
* USB_Device：USB从机库驱动代码















