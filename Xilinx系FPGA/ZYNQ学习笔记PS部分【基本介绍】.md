# 基于Zynq的嵌入式开发流程

Xilinx Zynq SoC 是集成了FPGA和硬核处理器的特殊SoC，它与一般FPGA的最大不同就是自带了一个ARM Cortex-A系列硬核，根据型号不同从A9到A53都有，对于ZYNQ7020来说，它集成了一块ARM Cortex-A9双核处理器，性能足够运行Linux

## 自顶向下方法









## 自底向上方法

1. 编写底层模块并使用IP集成器创建Processor System
2. 进行模块的仿真
3. 创建PS最小系统
4. 编写并生成顶层HDL
5. 进行硬件部分仿真
6. 导出比特流并进行烧录（一般固化到片外FLASH或使用SD卡加载）
7. 在SDK中创建软件工程并编写代码
8. 进行板级验证

## Zynq嵌入式最小系统

### Zynq 7000系列搭载的ARM Cortex-A9处理器硬核





### 片上DDR3内存控制器

用于管理板载片外内存





### UART





# helloworld工程

第一部分实现ZYNQ向上位机通过串口输出"hello world"字符串

第二部分实现ZYNQ点亮板载LED灯

## 硬件部分1

### 创建工程

对于Zynq而言，片上资源过于丰富，使用传统的HDL+Tcl方式进行管理十分不便，Vivado提供了一套可视化的模块设计环境，可以使用【IP INTERGRATOR】-【Block Design】来管理片上硬件模块

在管理视图中添加**zynq processing system**即可将Zynq片上的PS部分以预设IP的形式添加到工程

![image-20210425133559294](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425133559294.png)

该IP核相关的配置文件被自动生成保存在Design部分，通过图形界面进行配置

![image-20210425133852556](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425133852556.png)

### 配置工程

双击IP核即可进行配置

接口说明：

* M_AXI_GP0_ACLK：M_AXI_GP0的时钟信号，可以将PS端的时钟提供给PL端使用
* DDR：内存控制器输入/输出总线端口
* FIXED_IO：PS连接外部IO的端口
* M_AXI_GP0：PS与PL进行片上通信的AXI总线端口
* FCLK_CLK0：PS部分的FCLK时钟端口
* FCLK_RESET0_N：PS提供给PL的FPGA硬件复位端口

### PS块接口与外设简介

![image-20210425135613707](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425135613707.png)

1. PS部分的MIO是固定的，但可以选择连接到其上的不同外设，这就类似于典型MCU的“GPIO复用”
2. 





### 配置DDR控制器

![image-20210425140320428](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425140320428.png)

选择内存部件型号为`MT41J256M16 RE-125`表示搭载DDR内存容量为8GB

### 配置外设IO与UART

**对照开发板原理图**选择要连接到UART输出口的引脚，将其对应到片上UART外设

在【Peripheral I/O Pins】中选择要连接的引脚和外设

由于我选用的开发板是将MIO14和MIO15连接到了UART口，所以在这里选用对应14、15号引脚的UART0。注意：对
于其他型号的开发板，串口使用的MIO引脚可能不同

![image-20210425141050105](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425141050105.png)

在【MIO Configuration】中可以查看详细的外设配置

这里甚至可以选择IO电平标准，相当灵活

![image-20210425141310035](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425141310035.png)

在【PS-PL Configuration】中可进行有关串口波特率、AXI接口、DMA等关于PS和PL部分通讯/协同工作的设置

![image-20210425141448740](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425141448740.png)

这里并不进行更改

### 配置时钟

在【Clock Configuration】中可以配置时钟选项，这里并不涉及降频、超频或更改外设时钟等操作，所以保持默认

![image-20210425142526379](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425142526379.png)

这里面最重要的就是Input Frequency（33.3333），这里表示的就是ZYNQ的PS端输入时钟，直接由外部晶振接入

### 删除无用接口

1. 在【PS-PL Configuration】-【AXI Non Source Enablement】-【GP Master AXI Interface】中取消勾选M_AXI_GP0_interface
2. 在【PS-PL Configuration】-【AXI Non Source Enablement】-【Enable Clock Resets】中取消勾选FCLK_RESET0_N
3. 在【Clock Configuration】中取消选择【PL Fabric Clocks】下属FCLK_CLK0时钟

![image-20210425142749069](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425142749069.png)

### 完成生成

配置完成后得到模块如下所示：

![image-20210425143004771](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425143004771.png)

点击Run Block Automation进行生成

生成后点击上方“Validate Design”进行DRC验证

完毕后在Design Source部分右键点击配置文件选择【Generate Output Products】将配置文件生成为IP核的HDL代码

生成后得到的顶层文件和底层IP的HDL代码都保存在【Sources】-【IP Sources】目录下，包括综合、实现、仿真三部分代码

![image-20210425143945140](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425143945140.png)

右键配置文件选择【Create HDL Wrapper】进行HDL文件的封装，**生成顶层文件**，这会方便以后对工程进行修改

![image-20210425144111568](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425144111568.png)

可以选择用户自定义或vivado自动管理两种方式，为了方便这里选用后一种

### 导出到SDK

老版本vivado可以在左上角【File】-【Export】中选择【Export Hardware】来将HDL文件导出到SDK

**在新版本中，Xilinx将软件部分移到了Vitis软件下，用Vitis负责HLS、SDK两部分的软件编程工作，用Vivado负责FPGA相关的硬件编程工作**。应该手动在Vitis软件中导入生成的`.xsa`文件

打开后选中vivado生成的.xsa所在目录，

![image-20210425230153492](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425230153492.png)

1. 点击【File】-【New】-【Platform Project】

![image-20210425222808283](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425222808283.png)

如上图选择.xsa所在目录

这就通过vivado生成的配置文件创建了一套板级支持包BSP

2. 点击【File】-【New】-【Application Project】

![image-20210425223218722](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425223218722.png)

一路next后输入Project名字

![image-20210425223457943](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425223457943.png)

可以直接选用Hello World工程或Empty Application工程

![image-20210425223523049](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425223523049.png)

通过Hello World工程创建的工程文件如下

```c
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

int main()
{
    init_platform();

    print("Hello World\n\r");
    print("Successfully ran Hello World application");
    cleanup_platform();
    return 0;
}
```

如果自己创建应用程序文件，应加入一个标准的hello world代码

```c
#include "stdio.h"

int main(void)
{
    printf("hello world\n\r");
    
    return 0;
}
```

编辑完毕后点击上方的编译按钮

3. 连接开发板的JTAG和串口到PC
4. 编译完毕后如下图右键点击项目运行

![image-20210425224955954](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425224955954.png)

5. 完成后结果如下

![image-20210425224935816](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425224935816.png)

下载完成后板载PL端DONE LED不会点亮，因为这个LED指示的仅仅是PL端烧录，该部分并未涉及到PL端资源

## 软件部分1











## 硬件部分2













## 软件部分2





