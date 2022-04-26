# 蜂鸟E203的配套SoC设计

该SoC可以在蜂鸟e200的开源库中的/rtl/e203/soc目录下找到，目录下的文件是整个蜂鸟e203的顶层文件，外设相关verilog代码在perips目录下，时钟、总线和其他内容在subsys目录下

基于Freedom E310 SoC进行二次开发

系统的SoC设计如下图所示

![http://14901018.s21i.faiusr.com/4/ABUIABAEGAAg8qiqgAYo_JSj5gIwkwM4-wE.png](RISC-V学习笔记【配套SoC简介】.assets/ABUIABAEGAAg8qiqgAYo_JSj5gIwkwM4-wE.png)

本文仅简单介绍E203的外设资源和大致的配置方法，详细的寄存器功能请翻阅官方文档或书籍

## 存储资源

1. ITCM指令紧耦合存储器：RISC-V处理器内核私有指令存储器

   有以下特性

   * 大小、地址区间（默认起始地址0x8000_0000）可配置
   * 可用Load和Store指令访问，因此可以存储数据

2. DTCM数据紧耦合存储器：RISC-V处理器内核私有数据存储器

   有以下特性

   * 大小、地址区间（默认起始地址0x9000_0000）可配置
   * 只能用于存储数据

3. ROM

   有以下特性

   * 挂载在系统存储总线上
   * 大小4kB
   * 默认仅存放一条跳转指令，直接跳转到ITCM的起始地址位置开始执行

还可以扩展片外存储设备，一般使用FLASH存储

外部FLASH可以使用其XiP（Execution in Plae）模式，通过QSPI0映射为一片只读的地址区间（0x20000_0000到0x3FFF_FFFF）

也可以使用调试器将程序直接烧写在FLASH中，利用XiP模式就可以直接从FLASH中启动

## 时钟域和电源域

整个SoC划分为3个时钟域

1. **常开域**

   使用低速32.768kHz时钟，可以选择片上振荡器、外部晶振、芯片引脚输入

   蜂鸟E203 SoC中使用LCLKGEN模块控制常开域的时钟

   **在FPGA移植时应该注意该模块为空，需要直接输入32.768kHz时钟或自行编写PLL模块**

2. **主域**

   可以使用片上振荡器、外部晶振和片上PLL来生成高速时钟

   芯片主体时钟，使用HCLKGEN模块生成

   **FPGA开发板中，HCLKGEN模块为空，直接输出16MHz的参考时钟**

3. **调试域**

   专用于支持JTAG调试，由JTAG时钟和RISC-V内核时钟组成，内部由异步时钟跨越处理

整个SoC划分为2个电源域

1. **常开域**

   为子模块LCLKGEN、看门狗、RTC和PMU外设供电

2. **MOFF域**

   为常开域外所有主体部分供电

整个SoC可以有3种电源模式

1. 正常模式

   常开域、MOFF域都供电

   正常工作，可以配置HCLKGEN的PLL在低速运行来节省功耗

2. 等待模式

   正常供电，但处理器停止运行，内核时钟关闭直到被唤醒

   使用WFI指令进入该模式

3. 休眠模式

   常开域正常供电，MOFF域断电

   配置PMU的PMUSLEEP寄存器进入休眠模式，直到PMU定义的唤醒条件唤醒

特别注意：**FPGA开发板上没有真正的电源域功能**

## 复位

全片有3个全局复位来源

1. POR电路

   上电复位

   上电前直到电压稳定，POR电路会一直输出复位信号来保证芯片正常上电

   上电复位后可以通过调节BOOTROM_N引脚来实现不同的启动方式

   1. PC复位到0x2000_0000，从外部FLASH执行
   2. PC复位到0x0000_1000，从内部ROM执行固定代码，执行完毕后直接跳转到ITCM的0x8000_0000继续执行

2. 复位引脚AON_ERST_N

3. 看门狗生成的Reset信号

   没有及时喂狗就会导致软件复位

复位信号流向如下：

三种全局复位源信号经或门后称为aonrst信号，作为Always-On模块本身的复位信号，用于复位常开域的外设。在常开域外设PMU被复位后会执行默认的唤醒指令序列，进而唤醒整个SoC复位，PMU执行默认的唤醒之林序列生成hclkrst和corerst信号。如名称一样，会分别复位HCLKGEN模块和其他主域外设及CPU

## GPIO

蜂鸟E203附带的SoC提供了共一组32个IO口的GPIO外设，每个IO都支持：

* 上拉、下拉、悬空
* 输入、输出使能
* 输入读取、输出值读取
* 输出驱动强度控制
* 两种控制模式：软件控制和IOF（硬件IO）控制模式

软件模式下，通过读写GPIO的外设控制寄存器来执行外设控制

硬件模式下，某IO受IOF接口信号控制，IOF接口包含输入使能IE、输出使能OE、输入信号寄存器IVAL、输出信号寄存器IVAL四个数据位，IOF由来可以选择IOF1、IOF2，这个要通过软件读写外设寄存器来配置

**硬件模式**的IOF0和IOF1实际上用于连接E203 SoC中其他外设的片上接口，起到类似STM32中GPIO**复用**的功能

相关复用分配表如下所示：

| GPIO IO号 | IOF0           | IOF1   |
| --------- | -------------- | ------ |
| 0         | -              | PWM0_0 |
| 1         | -              | PWM0_1 |
| 2         | QSPI1:SS0      | PWM0_2 |
| 3         | QSPI1:SD0/MOSI | PWM0_3 |
| 4         | QSPI1:SD1/MISO | -      |
| 5         | QSPI1:SCK      | -      |
| 6         | QSPI1:SD2      | -      |
| 7         | QSPI1:SD3      | -      |
| 8         | QSPI1:SS1      | -      |
| 9         | QSPI1:SS2      | -      |
| 10        | QSPI1:SS3      | PWM2_0 |
| 11        | -              | PWM2_1 |
| 12        | IIC:SDA        | PWM2_2 |
| 13        | IIC:SCL        | PWM2_3 |
| 14        | -              | -      |
| 15        | -              | -      |
| 16        | UART0:RX       | -      |
| 17        | UART0:TX       | -      |
| 18        | -              | -      |
| 19        | -              | PWM1_0 |
| 20        | -              | PWM1_1 |
| 21        | -              | PWM1_2 |
| 22        | -              | PWM1_3 |
| 23        | -              | -      |
| 24        | UART1:RX       | -      |
| 25        | UART1:TX       | -      |
| 26        | QSPI2:SS       | -      |
| 27        | QSPI2:SD0/MOSI | -      |
| 28        | QSPI2:SD1/MISO | -      |
| 29        | QSPI2:SCLK     | -      |
| 30        | QSPI2:SD2      | -      |
| 31        | QSPI2:SD3      | -      |

## 中断

中断部分可以参考【中断和异常】部分

这里单独说明GPIO中断

GPIO的每个IO都能根据IVAL信号产生不同类型的中断，包括以下：

* 上升沿触发
* 下降沿触发
* 高电平触发
* 低电平触发

对于每个IO口，上述4种中断通过一个**或**门最终产生一根中断线，所以说GPIO外设中共可以产生32个中断信号，这些中断信号都会作为SoC中PLIC的外部中断源

## 总线控制器

### IIC控制器

IIC Master：IIC主控制模块

IIC协议由一条串行数据线SDA和一条串行时钟线SCL组成，每个连接到IIC总线的设备使用唯一地址来识别，实现全双工同步通信

接口电路要求开漏输出，需要通过上拉电阻到VCC，当总线空闲时，两根线都是高电平

蜂鸟E203的SoC中支持一个IIC模块，可实现以下功能

* 作为IIC主设备向外部IIC从设备读写数据
* 产生接收/发送中断
* 通过寄存器配置SCL的频率

IIC设备需要通过GPIO的IOF功能复用输出

通过以下公式配置IIC控制器输出的SCL频率和Prescale寄存器

$Prescale=\frac{f_{IIC时钟}}{5*f_{SCL时钟}-1}$

注意：Prescale寄存器的值只能在IIC未被使能的情况下更改

蜂鸟E203的官方库函数中带有相关的驱动函数，使用这些函数即可与片外设备进行IIC通信

### SPI控制器

SPI控制器也是一种常用的通信协议

支持

* 全双工：使用4根线
  * MOSI：主机输出/从机输入
  * MISO：主机输入/从机输出
  * SCK：时钟信号，由主设备产生
  * CS：片选信号，由主设备控制，只有该信号为预先规定的使能值时，对此芯片的操作才有效
* 半双工：使用3根线
  * SDIO：数据输入/输出
  * CS：片选信号
  * SCK：时钟信号

这样的SPI协议称为Single-SPI（单SPI），数据输出通过MOSI线传输，数据在时钟的上升沿或下降沿时改变，在紧接着的下降沿或上升沿被采样完成一位数据传输，输入情况同理

除了单SPI外，还扩展出了Dual-SPI双SPI和Quad-SPI四SPI

其中Quad-SPI（简称QSPI）最常用于SPI FLASH

其具有4根数据线，使用半双工的通讯方式，一个周期可以传送4bit数据

蜂鸟E203的附带SoC支持3个QSPI模块（QSPI0、QSPI1、QSPI2）

三个模块都可以作为SPI主机进行数据收发，除此之外还支持以下功能

* 通过寄存器配置为单线、双线、四线模式
* 支持rx、tx FIFO
* 支持软件可编程的FIFO阈值中断
* 支持可编程的SCK极性和相位

其中QSPI0专用于访问外部SPI FLASH，具有以下特殊功能：

* 仅支持1个使能信号（SS0）
* 有专用的芯片引脚用于连接外部FLASH
* 支持FLASH的XiP模式，可以将外部FLASH映射为一片只读的地址区间进行直接读取

QSPI1支持4个使能信号，QSPI2支持1个使能信号，两者都可以使用GPIO的IOF功能复用为外部接口，但是不支持FLASH的XiP模式

### 使用SPI控制器

SPI控制器配备了Tx-FIFO和Rx-FIFO，软件可以通过SPI_TXDATA或SPI_RXDATA来将数据压入/弹出FIFO的映像，FIFO则会根据映像的变化进行对应操作（实际上就是通过软件操作FIFO中开放的一个表项）

SPI的一个特点就是它实际上是一套FIFO，从MOSI输出的数据经过从机的SPI控制器又会经过MISO传回主机，相关verilog代码摘录如下：

```verilog
//RX部分
always @(*) begin
        rx_NS         = rx_CS;
        clk_en_o      = 1'b0;
        data_int_next = data_int;
        data_valid    = 1'b0;
        counter_next  = counter;

        case (rx_CS)
            IDLE: begin
                clk_en_o = 1'b0;

                // check first if there is available space instead of later
                if (en) rx_NS = RECEIVE;
            end
            RECEIVE: begin
                clk_en_o = 1'b1;

                if (rx_edge) begin
                    counter_next = counter + 1;

                    if (en_quad_in)
                        data_int_next = {data_int[27:0], sdi3, sdi2, sdi1, sdi0};
                    else
                        data_int_next = {data_int[30:0], sdi1};

                    if (rx_done) begin
                        counter_next = 0;
                        data_valid   = 1'b1;

                        if (data_ready)
                            rx_NS = IDLE;
                        else
                            rx_NS = WAIT_FIFO_DONE;

		    end else if (reg_done) begin
                        data_valid = 1'b1;

                    	if (~data_ready) begin
                            // no space in the FIFO, wait for free space
                    	    clk_en_o = 1'b0;
                    	    rx_NS    = WAIT_FIFO;
                    	end
                    end
                end
            end
            WAIT_FIFO_DONE: begin
                data_valid = 1'b1;
                if (data_ready)  rx_NS = IDLE;
            end
            WAIT_FIFO: begin
                data_valid = 1'b1;
                if (data_ready)  rx_NS = RECEIVE;
            end
        endcase
    end

//TX部分
    always @(*) begin
        tx_NS         = tx_CS;
        clk_en_o      = 1'b0;
        data_int_next = data_int;
        data_ready    = 1'b0;
        counter_next  = counter;

        case (tx_CS)
            IDLE: begin
                clk_en_o = 1'b0;

                if (en && data_valid) begin
                    data_int_next = data;
                    data_ready    = 1'b1;
                    tx_NS         = TRANSMIT;
                end
            end
            TRANSMIT: begin
                clk_en_o = 1'b1;

                if (tx_edge) begin
                    counter_next  = counter + 1;
                    data_int_next = (en_quad_in ? {data_int[27:0], 4'b0000} : {data_int[30:0], 1'b0});

                    if (tx_done) begin
                        counter_next = 0;

                        if (en && data_valid) begin
                            data_int_next = data;
                            data_ready    = 1'b1;
                            tx_NS         = TRANSMIT;
			end else begin
                            clk_en_o = 1'b0;
                            tx_NS    = IDLE;
                        end
		    end else if (reg_done) begin
                        if (data_valid) begin
                            data_int_next = data;
                            data_ready    = 1'b1;
			end else begin
                            clk_en_o = 1'b0;
                            tx_NS    = IDLE;
                        end
                    end
	        end
            end
        endcase
    end
```

可以看到其中使用了一套状态机来控制FIFO状态

可以看到：即便是接收数据操作，也需要软件写入任意值到TX-FIFO来触发一次传送，因为只有这样SPI的SCLK时钟信号才会被触发，从机才能在时钟信号的控制下对输入数据进行采样

主机通过SPI写入数据到从机的过程如下：

1. 写入数据到TX-FIFO
2. 从RX-FIFO读取数据，但是将数据抛弃，这是为了触发SCK
3. SCK自动触发
4. TX-FIFO的数据被通过MOSI传输出去并保持一段时间
5. 从机检测到SCK跳变沿，自动采样数据
6. 从机将采样到的数据保存到自己的RX-FIFO中
7. 从机将自己TX-FIFO的数据通过MISO传输出去并保持一段时间
8. 主机将MISO上的数据采样并保存到自身的RX-FIFO中
9. SCK停止触发，等待下一轮数据传输
10. 完成一轮SPI数据传输

使用蜂鸟E203的配套库函数就可以实现SPI通讯的功能

详细信息可参考源码和官方文档

### UART控制器

蜂鸟E203配备了两个UART外设（UART0、UART1）用于串口通信

传输过程中UART发送端将字节数据以串行方式**逐个比特**发送，UART接收端逐个比特地进行接收，并重新将其组织成字节数据

UART的基本工作时序如下所示：

* 空闲时，UART输出拉高
* 发送第一字节前，先发送一个低电平表示起始位
* 一般以低位先发送的方式逐个比特地传输完一个字节的数据位（8位数据位），某些设备里也可以支持高位先发送
* 在传输完数据位后可选传输一位或多为奇偶校验位
* 最后传输一位以高电平表征的停止位

UART传输速率用**波特率**表示

$比特率=波特率 \times 单个调制状态对应的二进制位$

信道中携带数据信息的信号单元称为码元，每秒通过信道传输的码元数称为码元传输速率，简称**波特率**

*波特率是传输通道频宽的指标*

每秒通过信道传输的信息量称为位传输速率，简称比特率

*比特率表示有效数据额传输速率*

波特率计算的是单位时间内包含了起始位和停止位在内的所有码元的传输速率；比特率仅计算单位时间内有效数据位的传输速率

蜂鸟E203的UART具有以下功能

* 收发数据
* 8-N-1和8-N-2双数据传输格式
* 8个深度的发送、接收FIFO，支持软件可编程的阈值中断
* 接收端可采用16倍波特率的采样频率采样接受数据线，对前后连续三次的采样结果进行判断，使用选择最多数的数值作为采样结果

#### 收发数据

需要使用GPIO复用（IOF）模式将UART连接到外部引脚

向UART_TXDATA寄存器中写入要发送的数据即可进行发送，该寄存器是UART TX-FIFO的映像，深度为8，每个表项存储1字节（8位）的数据；读取UART_RXDATA寄存器的值来接收输入的数据，该寄存器则是UART RX-FIFO的映像，软件每读取依次该寄存器，便会将1字节的表项数据弹出RX-FIFO，接收时采用16倍波特率的采样频率接收数据线，并对前后连续3次的采样结果进行判断，选择最多数的数值作为采样结果。

#### UART中断

UART外设支持开启发送和接收中断、FIFO阈值中断，这些中断通过一个或门传输到PLIC作为统一的UART中断进行配置

## PWM控制器

蜂鸟E203搭载了3个PWM模块（PWM0、PWM1、PWM2），其中PWM0是宽度为8位的比较器，PWM1和PWM2是宽度为16位的比较器

每个PWM支持4个可编程的比较器（pwmcmp0到pwmcmp3），每个比较器可以产生对应的一路PWM输出和中断

需要通过GPIO的IOF功能来连接PWM外设进行输出

#### PWM计数器设置

PWM计数器的值可以通过修改PWMCOUNT寄存器来设置，8位比较器需要设置23位宽的计数器，16位比较器则需要设置31位宽的计数器

在配置PWMCFG->pwmenalways或PWMCFG->pwmenoneshot被配置为1后，将使能PWM计数器，否则计数器不会自增/自减。系统上电复位后默认PWM处于未被使能状态。计数器将在被使能后的每个时钟周期自增1，达到预定的条件后便会归零，从PWM开始计数到归零之间的时间称为PWM周期

注意：PWM归零的预定条件

* 如果PWMCFG->pwmzerocmp=1，则当PWM比较值PWMS寄存器或其取反的值>=PWMCMP0寄存器设定的比较阈值时计数器归零
* 如果PWMCFG->pwmzerocmp=0，则PWM计数器一直自增，直到PWMS寄存器反映的值达到最大值（全部为1）溢出后归零

PWM归零后可以重新开始计数（条件：PWMCFG->pwmenalways=1），也可以停止计数

PWMCOUNT寄存器在系统复位后清零，由于其可读可写，软件可以直接通过写入该寄存器来修改PWM计数器的值

#### PWMS寄存器设置

PWMS寄存器的值来自PWMCOUNT寄存器中取出的pwmcmpwidth位，PWMCFG->pwmscale域的值指定了PWMCOUNT寄存器中取除pwmcmpwidth位的低位起始位置

**PWMS寄存器只是一个只读的影子寄存器**

如果PWMCFG->pwmscale=0，则表示直接取出低pwmcmpwidth位作为PWMS寄存器的值

如果PWMCFG->pwmscale=15，则表示将PWMCOUNT寄存器的值除以2^15^作为PWMS寄存器的值

### PWM中断

PWM外设默认一旦PWM计数器比较值>=PWMCMP寄存器设定的阈值，就会产生中断

注意点如下：

* PWMCFG->pwmsticky=1时，一旦产生中断，pwmcmp_x_ip的值将会一直保持，用于反应中断的Pending状态，软件只能通过写入pwmcmp_x_ip=0将其清除，或被系统复位清零
* PWMCFG->pwmsticky=0时，pwmcmp_x_ip的值不会一直保持，软件只能通过改写PWMCMP或PWMCOUNT寄存器的值来达到清除中断的效果
* 通过配置PWMCFG->pwmzerocmp=1，可以让PWM模块产生周期性的中断

其他设置内容可以参考蜂鸟E203的官方文档

总体上PWM外设的配置和STM32中定时器的配置很类似，但是由于FPGA硬件的限制，功能不如定时器强大

## 其他外设

### WDT看门狗定时器

蜂鸟E203中也配备了看门狗定时器，这是一个31位的定时器计数器，可以通过相关寄存器设置一旦WDG比较值达到比较阈值就可以复为整个MCU或产生中断。如果不需要看门狗功能，完全可以将其作为一个周期性中断发生器使用。

只有对一个特殊的密码寄存器进行写入密码操作后次啊能对看门狗的普通可编程寄存器进行写操作，用于防止意外写入

开启以后需要不停“喂狗”才能防止MCU被软件复位

喂狗操作：

1. 写入`0x51F15E`至WDOFKEY寄存器，解锁WDT
2. 写入`0xD09F00D`到WDOGFEED寄存器来喂狗

### RTC实时时钟

没错，E203甚至有RTC！

RTC是一个48位的计数器，支持比较定时器中断

## 总结

虽然看起来很厉害，但是蜂鸟E203的配套外设确实没有STM32那么多（毕竟SoC和内核加起来才占20k+的LUT，还要什么自行车）

往小了说这就是个大号51——虽然它能在FPGA上跑到200MHz主频

往大了说——这就叫可扩展性强，你想要啥就写啥然后弄成IP核挂到片内总线上，甚至还嫌这个小SoC里面其他外设占地方=_=

蜂鸟这个SoC比较好的地方就是官方提供了一套驱动函数库（或者说标准外设库？），可以很方便地编程

这篇博文发布的时候我的集创赛应该也完事了，如果不出意外的话那就是-300的悲惨结局——从头开始掉坑

也许以后有空会专门写一篇博文总结一下这次集创赛的踩坑经历吧......

以上