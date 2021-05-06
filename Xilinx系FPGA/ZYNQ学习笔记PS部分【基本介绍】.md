# 基于Zynq的嵌入式开发流程

Xilinx Zynq SoC 是集成了FPGA和硬核处理器的特殊SoC，它与一般FPGA的最大不同就是自带了一个ARM Cortex-A系列硬核，根据型号不同从A9到A53都有，对于ZYNQ7020来说，它集成了一块ARM Cortex-A9双核处理器，性能足够运行Linux

下图为Zynq-7000系列SoC的系统框图

![image-20210427121603584](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210427121603584.png)

## 自顶向下方法

这种方法多用于大工程的进度管理

将一个任务划分为多个小目标，一个一个进行解决的思想反映到SoC开发，就是首先将任务划分为硬件和软件两部分，再把硬件部分划分为软件无关和软件相关两类，把软件划分为需要硬件协助与无需硬件协助（纯算法）两类，这就能让进度规划更加合理

对于Zynq开发，直接采用Xilinx现成的划分：

* 软件相关的硬件：PS端的Cortex-A9硬核处理器、PL端通过AXI总线与硬核相联的电路、PL端的软核等
* 软件无关的硬件：PL端的部分硬件加速电路等
* 硬件相关的软件：运行在硬核、软核上的操作系统、裸机代码、对PL端硬件加速电路的处理代码等
* 硬件无关的软件：运行在操作系统支持下的计算代码等

Zynq的最大优点就是可以把硬核与FPGA结合，实现可编程灵活性与性能兼顾——用ZYNQ不用硬核，那为什么不选更便宜的Artix？（学习目的、强迫症、硬核极客想用啥用啥）；而自顶向下方法其实就是在做项目前考虑该怎么把这个优点发挥到极制，毕竟这么贵的东西还是要物尽其用

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

主频766MHz

带有I缓存和D缓存、MMU、FPU、看门狗

配备DMA和一个SysTick

通过NVIC处理中断/异常

### 片上DDR3内存控制器

用于管理板载片外内存，可适配DDR2、DDR3、LPDDR3等多种版本的片外内存颗粒

### UART

用于串口输入输出，一般将C标准输出重定向至串口即可使用printf通过串口输出debug信息

一个基于ZYNQ硬核的片上系统至少需要启用这三个部分，才能够实现哈佛架构的需求

# helloworld工程

在这个工程中主要的麻烦就是教程中给出的都是老版本Xilinx SDK的项目，在新版Vivado和Vitis中不支持直接导出（或者说直接导出会有各种各样的麻烦），需要等待之后的软件更新才能解决，所以在新版本中需要手动把Vivado生成的.xsa文件导入Vitis才能完成开发

第一部分实现ZYNQ向上位机通过串口输出"hello world"字符串

第二部分实现ZYNQ通过MIO点亮板载LED灯

## 部分1

UART向上位机发送“hello world”字符串

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
2. PS模块具有2个连接到引脚的MIO bank和2个连接到PL端的EMIO bank
3. PS端可以通过PS-PL端时钟生成器、AXI主从端口、DMA等端口连接PL端

### 配置DDR控制器

![image-20210425140320428](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425140320428.png)

选择内存部件型号为`MT41J256M16 RE-125`表示搭载DDR内存容量为8GB

**在这里还应该选择合适的DRAM总线带宽，此处使用了16位，有些型号的DDR需要使用32位带宽，应该根据芯片手册选择**

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
2. 在【PS-PL Configuration】-【General】-【Enable Clock Resets】中取消勾选FCLK_RESET0_N
3. 在【Clock Configuration】中取消选择【PL Fabric Clocks】下属FCLK_CLK0时钟

![image-20210425142749069](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425142749069.png)

### 完成生成

配置完成后得到模块如下所示：

![image-20210425143004771](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425143004771.png)

点击Run Block Automation进行生成

生成后点击上方“Validate Design”进行DRC验证

完毕后在Design Source部分右键点击配置文件选择【Generate Output Products】将配置文件生成为IP核（其实是整个ZYNQ片上PS系统）的HDL代码

生成后得到的顶层文件和底层IP的HDL代码都保存在【Sources】-【IP Sources】目录下，包括综合、实现、仿真三部分代码

![image-20210425143945140](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425143945140.png)

右键配置文件选择【Create HDL Wrapper】进行HDL文件的封装，**生成顶层文件**，这会方便以后对工程进行修改

![image-20210425144111568](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210425144111568.png)

可以选择用户自定义或vivado自动管理两种方式，为了方便这里选用后一种

### 导出到SDK

老版本vivado可以在左上角【File】-【Export】中选择【Export Hardware】来将HDL文件导出到SDK

**在新版本中，Xilinx将软件部分移到了Vitis软件下，用Vitis负责HLS、SDK两部分的软件编程工作，用Vivado负责FPGA相关的硬件编程工作**。应该先点击左上角【File】-【Export】-【Export Hardware】导出到SDK，再手动在Vitis软件中导入生成的`.xsa`文件

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

## 部分2

使用ZYNQ上搭载的硬核CPU通过GPIO与MIO点亮板载LED

### ZYNQ封装与引脚

封装相关详细内容可参考Zynq-7000-Pkg-Pinout手册（代号为**UG865**）

ZYNQ-7020采用BGA封装，引脚被分为几个不同的部分：

* 用户IO：由用户自行设定的引脚约束决定，支持差分对输出

* 配置IO

  DONE_0：当PL部分完成比特流加载后输出高电平，一般用于设置配置完成指示灯

  INIT_B_0：当可配置内存部分完成配置后输出低电平，一般用于设置配置完成指示灯

  PROGRAM_B_0：对PL部分的异步复位引脚，当拉低时开始复位

  TCK_0：JTAG接口的时钟信号

  TDI_0：JTAG数据输入

  TDO_0：JTAG数据输出

  TMS_0：JTAG模式选择

  CFGBVS_0：bank0的预置IO电平标准配置引脚。若bank0的V~CCO~为2.5V或3.3V，这个引脚要结道V~CCO~；若V~CCO~小于等于1.8V，这个引脚需要接地

  PUDC_B：外部上拉电阻使能引脚。若拉低，则可以在每个SelectIO引脚上接外部上拉电阻；否则外部上拉电阻被无效。这个引脚必须直接或通过1k及以下的电阻连接到VCCO_34或GND，**千万不能在配置时悬空**

* 电源引脚

  GND：地线

  VCCPINT：PS端的1.0V电源，独立于PL VCCINT

  VCCPAUX：PS端的1.8V备用电源

  VCCO_MIO0：MIO的bank500的1.8V-3.3V电源

  VCCO_MIO1：MIO的bank501的1.8V-3.3V电源

  VCCO_DDR：为DDR供电的1.2-1.8V电源

  VCCPLL：PS端PLL的1.8V电源。注意在BGA封装的器件中需要在它过孔背面放置一个到地的0402电容（0.47uF到4.7uF即可）。当使用VCCPAUX电源时，这个引脚必须用一个0603封装，100MHz阻抗120Ω的磁珠和一个0603封装、10uF的退耦电容组成LC滤波电路来削弱PLL抖动

  VCCAUX：辅助电路的1.8V电源

  VCCAUX_IO_G：辅助IO电路的1.8V或2.0V电源

  VCCINT：内部核心逻辑的1.0V电源

  VCCO_#：每个bank输出驱动电路的电源

  VCCBRAM：PL端块RAM的1.0V电源

  VCCBATT_0：加密内存的备份电源。如果不使用应当接VCC或接地

  VREF：输入阈值电压控制引脚，当不需要外部阈值电压时可以复用为用户IO

* PS MIO引脚

  PS_POR_B：用于上电复位的引脚。在VCCPINT、VCCPAUX、VCCO_MIO0达到最大值、PS_CLK稳定之前要保持接地；在断电阶段，VCCPINT达到0.8V，至少下面四个条件之一得到满足之前也保持接地：

	1. PS_POR_B输入强制接地
   	2. PS_CLK输入被切断
   	3. VCCPAUX低于0.7V
   	4. VCCO_MIO0低于0.9V

  注意：为了保证PS端eFUSE完整性，直到VCCPINT达到0.4V前都要保证该引脚触发

  PS_CLK：PS端的系统参考时钟，必须在30MHz到60MHz之间

  PS_SRST_B：PS端系统复位引脚。当使用调试器时该引脚为0，强制PS端进入系统复位

  PS_MIO_VREF：为RGMII输入接收器提供参考电压，如果不使用，该引脚可以悬空；若使用，该引脚应当分压（可使用常见的电阻分压）为1/2的VCCO_MIO1

  PS_MIO[53:0]：由用户定义的PS端复用IO接口

* PS DDR引脚

  比较复杂、接法固定，这里省略，详情参考引脚手册

* XADC引脚

  ZYNQ搭载了12位双路ADC，XADC引脚就是为这些ADC服务的

  VCCADC_0：XADC的模拟正电源

  GNDADC_0：XADC的模拟地参考点

  VP_0：XADC的正相模拟信号输入

  VN_0：XADC的反相模拟信号输入

  VREFP_0：1.25V参考电源输入

  VREFN_0：1.25V参考地输入

  ADxP、ADxN：XADC差分辅助模拟信号输入引脚

* 其他引脚

ZYNQ系列的封装特色是：电源引脚集中在中心，功能引脚在四周，地线穿插其中

### GPIO与MIO

GPIO详细内容可参考Xilinx Zynq-7000 系列技术参考手册（代号为**UG585**）

下图给出了ZYNQ的基本架构

![image-20210427121603584](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210427121603584.png)

**ZYNQ说简单点就是个带FPGA的STM32**，在ZYNQ中FPGA是作为硬核的外设连接的

GPIO也是一个外设，它被连接到了MIO。MIO即Multiuse IO，类似于一套多路复用器，可以将来自PS外设和静态存储器接口的访问多路复用到PS的引脚上。

> Each GPIO is independently and dynamically programmed as input, output, or interrupt sensing. Software can read all GPIO values within a bank using a single load instruction, or write data to one or more GPIOs (within a range of GPIOs) using a single store instruction. The GPIO control and status registers are memory mapped at base address 0xE000_A000
> 
> 每个GPIO都可以独立、动态地编程为输入、输出、中断模式，软件可以使用独立的load指令或store指令读写一个bank中的任意选定的GPIO的值。GPIO的控制和状态寄存器（CSR）被映射到基地址为0xE000_A000的空间

ZYNQ中的GPIO与MCU中的GPIO类似，能够进行输入/输出GPIO被分为4个**bank**，软件通过一组外设控制寄存器来控制GPIO

其中**bank0和bank1通过MIO连接到PS引脚，bank2和bank3通过EMIO连接到PL端**

总体上讲，ZYNQ内部分为了两个部分PS和PL，这两个部分之间、两个部分与封装的引脚之间都是通过MIO连接的，MIO通过引脚约束确定，使用的是xdc描述；而GPIO是一个附属于PS端的外设，它的作用就是让PS端的处理器硬核能够对外界信号进行通用的输入输出操作，对GPIO的配置使用SDK（Vitis）对处理器硬核进行编程来配置

在点灯中，需要使用的是bank0/bank1的GPIO

操作GPIO的控制寄存器时一次性向输出数据寄存器写入32位，会导致整个一个bank的值被修改；如果想要修改单一位就需要先读取-修改-再写入这样繁琐的步骤；为此可以使用屏蔽寄存器将其他不需要修改的位屏蔽掉，屏蔽寄存器分为高16位寄存器和低16位寄存器，需要两个配合使用

### 配置外设GPIO与IO映射并导出

![image-20210430221655867](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210430221655867.png)

打开vivado的工程，双击之前创建好的ZYNQ图形，在【Peripheral IO Pins】中选择GPIO MIO

重新进行一遍之前的导出操作：

1. 点击Run Block Automation进行生成
2. 点击上方“Validate Design”进行DRC验证
3. 在Design Source部分右键点击配置文件选择【Generate Output Products】将配置文件生成为IP核的HDL代码
4. 右键配置文件选择【Create HDL Wrapper】进行HDL文件的封装
5. 导出.xsa文件并在Vitis中创建工程

### 软件部分编写

使用的软件代码如下所示：

```c
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xstatus.h"
#include "xgpiops.h"// GPIO外设库
#include "sleep.h"// 延迟函数库

#define MIOLED1 0
#define MIOKEY1 9
#define input 0
#define output 1

XGpioPs Gpios;

int main()
{
	init_platform();
	int status=0;
	XGpioPs_Config *ConfigPtr;

	print("Hello World\n\r");
	print("Successfully ran Hello World application");

	ConfigPtr=XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);// 根据预设的器件获取器件ID与地址
    status=XGpioPs_CfgInitialize(&Gpios,ConfigPtr,ConfigPtr->BaseAddr);// 配置GPIO初始化
	if(status!=XST_SUCCESS)// 检查是否配置成功
    	return XST_FAILURE;

	XGpioPs_SetDirectionPin(&Gpios,MIOLED1,output);// 接LED输出
	XGpioPs_SetDirectionPin(&Gpios,MIOKEY1,input);// 接按钮输入
    XGpioPs_SetOutputEnablePin(&Gpios,MIOLED1,1);// 使能LED输出

	while(1)
	{
		if(XGpioPs_ReadPin(&Gpios,MIOKEY1))
		{
			XGpioPs_WritePin(&Gpios,MIOLED1,1);// 按钮按下时输出高电平
	    }
	    else
	    {
	    	XGpioPs_WritePin(&Gpios,MIOLED1,0);// 平时输出低电平
	    }
	}
	cleanup_platform();
	return 0;
}
```

在添加代码前需要先选择左上角【File】-【New】-【Application Project】按照提示步骤创建一个新工程

完成后，在源文件【src】中修改main.c文件为上述代码即可

### 烧录

1. 清除已编译文件并重新进行编译
2. 连接开发板的JTAG接口和UART接口到PC
3. 右键点击当前程序并选择【Run As】中的【Launch on Hardware】执行烧录

完成后即可尝试按下开发板上对应KEY1按钮，可看见LED亮起