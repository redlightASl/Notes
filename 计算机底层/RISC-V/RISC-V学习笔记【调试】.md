# 蜂鸟E203的开源调试实现

蜂鸟E203在处理器内核外集成了一套调试外设，能够支持完整的GDB调试功能，并可以通过openocd经由jtag接口实现在线调试

## 调试机制

### 交互调试Interactive Debug

交互调试是处理器提供的最常见的一种调试功能，指**调试器软件能够直接对处理器取得控制权，进而对其以一种交互的方式进行调试**

一般的交互调试要求调试软件能够控制处理器实现以下功能：

* 下载、启动程序
* 通过设定各种特定条件来停止程序
* 查看并改变处理器的运行状态
* 查看通用寄存器、存储器地址的值
* 查看并改变程序状态（包括变量值、函数状态）

对于嵌入式设备，调试软件一般运行在上位机，被调试的处理器往往位于开发板上，这被称为**远程调试**

因此需要硬件支持通过物理介质（典型的JTAG接口）与主机端调试软件进行通信接收器控制，处理器核直接受到硬件调试模块的控制

常见的调试过程可以如下概括：

1. 开发者运行调试软件，并在某条程序处设置断点调试
2. 调试软件通过底层驱动JTAG接口访问远程处理器的调试模块并将断点信息传递给调试模块
3. 调试模块得到指令后会请求处理器内核运行停止
4. 调试模块根据断点信息修改对应指令的PC地址的指令，将其替换为一个Breakpoint指令
5. 请求恢复处理器内核运行
6. 处理器内核恢复运行
7. 执行到对应的指令PC地址，遇到Breakpoint指令
8. 内核产生Debug异常，自动跳转到调试模式的异常服务程序
9. 调试模块检测到处理器内核进入调试模式的异常服务程序，将信息回传到上位机
10. 开发者运行主机端的调试软件并设置读取某个寄存器的值
11. 调试软件会通过JTAG接口访问远程处理器的调试模块，并令其回传某个寄存器的值
12. 调试模块开始对处理器内核进行控制，将寄存器的值读取出来，并进行回传
13. 调试软件检测到调试模块回传，通过JTAG接口将数据返回上位机并进行显示

其他调试指令大同小异，都是一整套复杂的软硬件协同过程

交互式调试的弊端就是对于处理器的运行具有**打扰性**，对某些对时间先后性有依赖的程序无法重现bug，并且对于某些需要外界触发的bug（比如MCU中常见的GPIO外部中断）无法进行检测

由此出现了跟踪调试机制

### 追踪调试Trace Debug

追踪调试又叫跟踪调试：**调试器只跟踪记录处理器内核所执行过的所有程序指令，不会打断干扰处理器的执行过程**

相比交互式调试的实现难度更大，产生的信息量更是大到不可描述的地步

所以只有财大气粗的高端处理器才可能搭载这种技术

不排除有闲的蛋疼的dalao给自己写的cpu配备追踪调试（雾）

## 蜂鸟E203的调试功能

RISC-V基金会还未发布标准的RISC-V调试架构文档，但是根据目前的候选文档，要求处理器实现特殊的“调试模式”，并且定义了若干触发条件，因此可以将RISC-V的调试模式看作一种特殊的异常。当进入调试模式时，处理器会进行如下更新：

1. PC跳转到0x800地址
2. 将处理器正在执行的指令PC保存到CSR->dpc中
3. 将引发进入调试模式的触发原因保存到CSR->dcsr中

同时，RISC-V标准指令集中已经定义了一条特殊的断点指令ebreak，该指令主要用于调试软件设置断点——**当处理器运行到这条指令时会自动跳转到异常模式或调试模式**，同时候选文档中规定了一个特殊的dret指令，执行到该指令时，处理器PC将跳转到保存在SCR->dpc中的值（处理器退回到之前进入调试模式前的程序执行点），并将CSR->dcsr寄存器中的域清除掉（指示处理器退出调试模式）。此外，候选文档中还定义处理器应支持**调试中断**，处理器核收到该中断后将进入调试模式

蜂鸟E203的硬件调试机制就基于该方案实现，**目前蜂鸟E203仅支持交互式调试**，不支持追踪调试

### 蜂鸟E203的调试实现

调试主机即PC端上位机，使用GDB与蜂鸟E203进行通信，在蜂鸟的实现中，GDB现与Gdbserver进行通信，Gdbserver使用开源软件OpenOCD充当。由于OpenOCD的源码中包含了各种常见硬件芯片的驱动（如FTDI的USB转JTAG芯片），可以直接使用对应芯片的USB接口与调试主机的USB接口连接。上位机的总线时序使用片上的**DTM模块**进行解析。被解析后的调试总线时序被传输到**硬件调试模块**中，该模块统筹整个调试机制。

### DTM模块

该模块使用FSM对JTAG协议进行解析并转换成调试总线，由于DTM模块处于JTAG时钟域，与调试总线要访问的调试模块不属于同一个时钟域，所以需要被同步

### 硬件调试模块

可以访问/rtl/e203/debug/sirv_debug_module.v、/rtl/e203/debug/sirv_debug_ram.v、/rtl/e203/debug/sirv_debug_rom.v这三个文件来翻阅硬件调试模块的源代码

调试中断会被该模块生成并作为一根输入信号输送给处理器的**交付模块**。调试终端一旦被接受，就会引起流水线冲刷，取消后续的指令并向IFU模块发送冲刷请求，将重新取指的PC改为0x800

其他操作根据候选文档中指明的调试机制实现，可查看官方文档。