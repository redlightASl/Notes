[TOC]

# 定时器时钟

> 单片机就是定时器！定时器就是单片机！——某个不愿透露姓名的学长

定时器是单片机的灵魂，学一个单片机，最先掌握的是GPIO，最容易掉坑的是中断控制器，最复杂的是那些总线协议，而最难掌握的就是定时器

这里笔者通过阅读STM32F4xx官方参考手册，配合英文版和中文版整理了与STM32标准外设库有关的定时器知识点（其实大部分是摘抄/翻译原文），经过自己浅薄的经验（半年多的STM32学习经历）梳理得到以下内容，权当抛砖引玉

将外设库源码摘抄附录在结尾，顺序与正文基本一致，可供参考

## 内核定时器SYSTICK

> 我心永恒——SysTick

参考《Cortex M3与M4权威指南》内核定时器部分以获取更多信息

内核定时器SysTick是由ARM规定的包括在Cortex-M内核中的一个定时器，只能像基本定时器一样进行一般的定时功能，偶尔可以配合NVIC实现定时器中断

这个定时器主要用于作为操作系统（RTOS）系统时钟，使用CMSIS规定的库函数或寄存器就可以进行操作，大大增强操作系统的可移植性。下直自己码的简陋RTOS，上到嵌入式Linux都可以使用这个定时器

## 通用定时器组1

> 通用的就是最好的

通用定时器由TIM2、TIM3、TIM4、TIM5组成，其中TIM2、5拥有32位自动重载计数器，精度更高；TIM3、4拥有16位自动重载计数器，该计数器由可编程预分频器驱动，**预分频器为16位，分频系数在1到65536之间**

支持以下功能

* 通过输入捕获测量输入信号脉冲宽度
* 可使用外部信号控制定时器
* 可实现多个定时器互连的同步电路
* 四个独立的输入捕获、输出比较和PWM输出、单脉冲输出通道
* 产生DMA请求（触发源包括定时器溢出、初始化、输入捕获、输出比较、触发事件等）
* 支持驱动编码器和霍尔传感器
* 外部时钟触发输入或逐周期电流管理

所有这些定时器互相完全独立，不共享任何资源，可以让任意两个通用定时器同步工作

![image-20210516170041918](.\STM32F4深入学习_定时器.assets\image-20210516170041918.png)

### 时基单元

**定时器的时基单元实际上就是一套用于稳定输出时钟的计数器**，定时器的其他高级功能都是在计数器的基础上实现的

这就是为什么定时器中断、输出PWM、检测输入信号等操作都需要预先设定时基单元

时基单元本身的时钟来自于RCC的TIMxCLK，由APB总线提供；不过也可以设定成由片外电路独立输入，也就是所谓的TIMxETR；甚至也可以用其他定时器触发，这就是“从模式-定时器级联”

时基单元包括：

* **计数器**寄存器 (TIMx_CNT)
* **预分频器**寄存器 (TIMx_PSC)
* **自动重载**寄存器 (TIMx_ARR)

计数器、自动重载寄存器和预分频器寄存器可通过软件进行读写。即使在计数器运行时也可执行读写操作。

#### 关于计数器重载

> **自动重载寄存器是预装载的**。对自动重载寄存器执行写入或读取操作时会访问**预装载寄存器**。预装载寄存器的内容既可以**直接传送**到**影子寄存器**，也可以在每次**发生更新事件** (UEV) 时传送到影子寄存器——这取决于 TIMx_CR1 寄存器中的自动重载预装载使能位 (ARPE)。当 计数器达到上溢值（或者在递减计数时达到下溢值）并且 TIMx_CR1 寄存器中的 UDIS 位为 0 时，将发送更新事件。**该更新事件也可由软件产生**（称为软件更新事件）

以上段落就是指时基单元中的计数器值会通过自动重载寄存器对应的影子寄存器进行更新，CPU能操作的是顶层的自动重载寄存器：写入值后，根据自动重载预装载使能位（ARPE）的选项，在发生更新事件后或下一个时钟信号到来时，表层寄存器的值会被复制到影子寄存器，同时计数器寄存器会自动根据影子寄存器的值更新

#### 关于计数器配置

> 计数器由预分频器输出 CK_CNT 提供时钟，仅当 TIMx_CR1 寄存器中的计数器启动位 (CEN) 置 1 时，才会启动计数器
> **真正的计数器使能信号 CNT_EN 在 CEN 置 1 的一个时钟周期后被置 1**

#### 关于预分频器

> 预分频器可对计数器时钟频率进行分频，分频系数介于 1 到 65536 之间（该预分频器基于 16 位/32 位TIMx_PSC寄存器所控制的 16 位计数器），由于该控制寄存器具有缓冲功能，因此**预分频器可实现实时更改**，新的预分频比将在下一更新事件发生时被采用

所以不仅可以在定时器工作时动态更改计数器值，也可以动态更改分频值

示例时序图如下：

![image-20210516170857412](.\STM32F4深入学习_定时器.assets\image-20210516170857412.png)

![image-20210516170948206](.\STM32F4深入学习_定时器.assets\image-20210516170948206.png)

### 定时器计数模式

下面的内容都是摘自官方文档

#### 递增模式

> **计数器从0计数（自动+1）到自动重载值，然后重新从0开始计数并生成计数器上溢事件**
> **每次发生计数器上溢时会生成更新事件**，将 TIMx_EGR 寄存器中的 UG 位置 1（通过软件或使用从模式控制器）也可以生成更新事件
> 通过软件将 TIMx_CR1 寄存器中的 UDIS 位置 1 可禁止 UEV 事件。这可避免向预装载寄存器写入新值时更新影子寄存器。在 UDIS 位写入 0 之前不会产生任何更新事件，不过计数器和预分频器计数器都会重新从 0 开始计数（而预分频比保持不变）。此外如果 TIMx_CR1 寄存器中的 URS 位（更新请求选择）已置 1，则将 UG 位置 1 会生成更新事件 UEV，但不会将 UIF 标志置 1（因此，不会发送任何中断或 DMA 请求）。这样如果在发生捕获事件时将计数器清零，将不会同时产生更新中断和捕获中断。
> 发生更新事件时，将更新所有寄存器且将更新标志（TIMx_SR 寄存器中的 UIF 位）置 1（取 决于 URS 位）：
>
> ● 预分频器的缓冲区中将重新装载预装载值（TIMx_PSC 寄存器的内容）
>
> ● 自动重载影子寄存器将以预装载值进行更新

#### 递减模式

> **计数器从自动重载值开始递减计数到0， 然后重新从自动重载值开始计数并生成计数器下溢事件**
> **每次发生计数器下溢时会生成更新事件**，或将 TIMx_EGR 寄存器中的 UG 位置 1（通过软件或使用从模式控制器）也可以生成更新事件
> 通过软件将 TIMx_CR1 寄存器中的 UDIS 位置 1 可禁止 UEV 更新事件。这可避免向预装载寄存器写入新值时更新影子寄存器。在 UDIS 位写入 0 之前不会产生任何更新事件。不过，计数器会重新从当前自动重载值开始计数，而预分频器计数器则重新从 0 开始计数（但预分频比保持不变）。
> 此外如果 TIMx_CR1 寄存器中的 URS 位（更新请求选择）已置 1，则将 UG 位置 1 会生 成更新事件 UEV，但不会将 UIF 标志置 1（因此，不会发送任何中断或 DMA 请求）。这样如果在发生捕获事件时将计数器清零，将不会同时产生更新中断和捕获中断。
> 发生更新事件时，将更新所有寄存器且将更新标志（TIMx_SR 寄存器中的 UIF 位）置 1（取决于 URS 位）：
>
> ● 预分频器的缓冲区中将重新装载预装载值（TIMx_PSC 寄存器的内容）。
>
> ● 自动重载活动寄存器将以预装载值（TIMx_ARR 寄存器的内容）进行更新。
>
> **自动重载寄存器会在计数器重载之前得到更新，因此下一个计数周期就是我们所希望的新的周期长度**

#### 中心对齐

> **在中心对齐模式下，计数器从 0 开始计数到自动重载值-1， 生成计数器上溢事件；然后从自动重载值开始向下计数到 1 并生成计数器下溢事件。之后从 0 开始重新计数**——一个计数周期生成两个上溢事件
> 当 TIMx_CR1 寄存器中的 CMS 位不为“00”时，中心对齐模式有效。将通道配置为输出模式时，其输出比较中断标志将在以下模式下置 1，即：计数器递减计数（中心对齐模式 1， CMS =“01”）、计数器递增计数（中心对齐模式 2，CMS =“10”）以及计数器递增/递 减计数（中心对齐模式 3，CMS =“11”）
> 此模式下无法写入方向位（TIMx_CR1 寄存器中的 DIR 位）；而是**由硬件更新**并指示当前计数器方向。
> 每次发生计数器上溢和下溢时都会生成更新事件，或将 TIMx_EGR 寄存器中的 UG 位置 1 （通过软件或使用从模式控制器）也可以生成更新事件。这种情况下，计数器以及预分频器计数器将重新从 0 开始计数
> 通过软件将 TIMx_CR1 寄存器中的 UDIS 位置 1 可禁止 UEV 更新事件。这可避免向预装载 寄存器写入新值时更新影子寄存器。在 UDIS 位写入 0 之前不会产生任何更新事件。计数器仍会根据当前自动重载值进行递增和递减计数
>
> 如果 TIMx_CR1 寄存器中的 URS 位（更新请求选择）已置 1，则将 UG 位置 1 会生 成更新事件 UEV，但不会将 UIF 标志置 1（因此，不会发送任何中断或 DMA 请求）。如果在发生捕获事件时将计数器清零，将不会同时产生更新中断和捕获中断。
> 发生更新事件时，将更新所有寄存器且将更新标志（TIMx_SR 寄存器中的 UIF 位）置 1（取 决于 URS 位）：
>
> ● 预分频器的缓冲区中将重新装载预装载值（TIMx_PSC 寄存器的内容）。
>
> ● 自动重载活动寄存器将以预装载值 （TIMx_ARR 寄存器的内容）进行更新。注意，如
>
> 果更新操作是由计数器上溢触发的，则自动重载寄存器在重载计数器之前更新，下一个计数周期就是我们所希望的新的周期长度（计数器被重载新的值）

### 时钟选择

计数器时钟可以由内部/外部时钟源提供

#### 内部时钟CK_INT

如果禁止从模式控制器，则CEN、DIR、UG三个寄存器位就充当实际控制位，能且仅能通过软件更改，其中UG位还会自动清零；当CEN=1时，预分频器时钟由内部时钟CK_INT提供

#### 外部时钟模式1

使用外部输入引脚TIx

当TIMx_SMCR寄存器中的SMS=111时，可选择此模式，计数器可在选定的输入信号出现上升沿或下降沿时计数

如下图所示

![image-20210518132306079](.\STM32F4深入学习_定时器.assets\image-20210518132306079.png)

使用方法：

1. 开启外部时钟输入通道TIx
2. 可选择在TIMx_CCMR1寄存器的ICF[3:0]位写入滤波时间配置，或令ICF=0x0000来禁止滤波
3. 边沿检测器和捕获预分频器不需要进行设置
4. 选择上升沿/下降沿极性有效
5. 配置定时器在外部时钟模式1下工作
6. 选择已经开启的外部时钟输入通道TIx作为输入源
7. 使能计数器

配置完毕后，计数器就会在外部输入呈现对应上升沿/下降沿时计数一次并将TIF标志置1

#### 外部时钟模式2

**仅对TIM2、3、4适用**

使用外部触发输入ETR

![image-20210518132925999](.\STM32F4深入学习_定时器.assets\image-20210518132925999.png)

与外部时钟模式1的最大区别就是可以自行配置预分频器来实现“每当ETR出现n个上升沿/下降沿时，计数器计数一次”的效果

同时可能会由于ETRP信号经过重新同步电路而引起ETR上升沿与实际计数器时钟之间的延迟

配置方法：

1. 设置滤波器滤波时间
2. 设置ETR预分频器分频系数
3. 选择上升沿/下降沿检测
4. 使能外部时钟模式2
5. 使能计数器

### 外部触发输入——外部触发同步

定时器可以以复位、门控和触发三种模式与外部触发实现同步

1. **复位模式（从模式）**

   当触发输入信号发生变化时，计数器及其预分频器可重新初始化

   如果 TIMx_CR1 寄存器中的 URS 位处于低电平，则会生成更新事件 UEV，所有预装载寄存器 （TIMx_ARR 和 TIMx_CCRx）都将更新

2. **门控模式（从模式）**

   输入信号的电平可用来使能计数器

   门控模式作用于电平而非边沿，可设置为高/低电平触发使能定时器计数器

3. **触发模式（从模式）**

   所选输入上发生某一事件时可以启动计数器，该事件使用软件程序决定，可以通过外设配置寄存器设置

4. **外部时钟模式2+触发模式（从模式）**

   外部时钟模式 2 可与另一种从模式（外部时钟模式1和编码器模式除外）结合使用

   ETR 信号用作外部时钟输入，在复位模式、门控模式或触发模式下工作时，可选择另一个输入作为触发输入，但不建议通过 TIMx_SMCR 寄存器中的 TS 位来选择 ETR 作为 TRGI

#### 内部触发输入——定时器级联与同步

使用一个定时器作为另一个定时器的预分频器

定时器可以从内部连接在一起以实现定时器同步或级联。当某个定时器配置为主模式时， 可对另一个配置为从模式的定时器的计数器执行复位、启动、停止操作或为其提供时钟

![image-20210521225925100](.\STM32F4深入学习_定时器.assets\image-20210521225925100.png)

使用时需要注意：

1. 一定要设置好主模式定时器与从模式定时器
2. 主模式定时器的输出连接到从模式定时器的输入，不能反接
3. 将主模式和从模式定时器都配置为触发模式

这个功能实现比较复杂，可以查阅参考手册中给出的示例程序

### 捕获/比较通道

一个定时器时基单元具有四个/三个/两个独立的捕获/比较通道，可以完成更高级的任务

每个捕获/比较通道均附带一个捕获/比较寄存器（包括一个影子寄存器）、一套输入阶段设备（数字滤波器、多路复用器和预分频器）和一套输出阶段设备（比较器和输出控制器）

下图为输入阶段设备结构框图

TIx作为输入进行采样，滤波器生成一个滤波后的信号 TIxF 输出到带有极性选择功能的边沿检测器。边沿检测器会根据配置生成一个上升沿/下降沿信号 (TIxFPx)，该信号可**直接用作从模式控制器的触发输入**（通过一套组合逻辑），也可先进行预分频 (ICxPS)，再进入捕获寄存器

信号可以来自TI1、2、3、4（只要有输入线、滤波器、边沿检测器就可以输入到多路复用器），进而输入到统一的预分频器

![image-20210518135027490](.\STM32F4深入学习_定时器.assets\image-20210518135027490.png)

下图是捕获/比较通道的主电路结构框图

捕获/比较模块由一个**预装载寄存器**和一个**影子寄存器**组成。始终可通过读写操作访问预装载寄存器。

*在捕获模式下，**捕获实际发生在影子寄存器中**，然后**将影子寄存器的内容复制到预装载寄存器中***

*在比较模式下，**预装载寄存器的内容将复制到影子寄存器中**，然后将影子寄存器的内容**与计数器**进行**比较***

![image-20210518135041953](.\STM32F4深入学习_定时器.assets\image-20210518135041953.png)

下图是捕获/比较通道的输出阶段设备

输出阶段的输出模式控制器会根据软件配置和来自主电路的信号生成一个中间基准波形：OCxRef（高电平有效）。这个信号可以经过一个三态门（输出使能电路）到输出捕获，也可以直接输送到主模式控制器

末端的输出使能电路决定最终输出信号的极性。

![image-20210518135052372](.\STM32F4深入学习_定时器.assets\image-20210518135052372.png)

### 输入捕获与PWM输入

> 输入捕获模式下，当相应的 ICx 信号被检测到跳变沿后，将使用**捕获/比较寄存器**(TIMx_CCRx)来锁存计数器的值，并触发捕获事件；发生捕获事件时，会将相应的CCXIF标志（TIMx_SR 寄存器）置1， 并可配置发送中断或 DMA 请求
>
> 如果发生捕获事件时 CCxIF 标志已处于高位，则会将重复捕获标志 CCxOF（TIMx_SR 寄存器）置1——可通过软件向 CCxIF 写入 0 来给 CCxIF 清零或读取存储在 TIMx_CCRx 寄存器中的已捕获数据——向 CCxOF 写入0后会将其清零

输入捕获配置步骤如下：

1. 选择有效输入

   TIMx_CCR1 必须连接到 TI1 输入，因此向 TIMx_CCMR1 寄存器中的CC1S 位写入 01——只要 CC1S 不等于 00，就会将通道配置为输入模式，并且 TIMx_CCR1 寄存器将处于只读状态

2. 根据连接到定时器的信号，对所需的输入滤波时间进行编程

   如果输入为 TIx 输入之一，则对 TIMx_CCMRx 寄存器中的 ICxF 位进行编程

   注意：**滤波时间必须大于输入信号发生抖动的内部时钟周期数**
   
3. 选择输入通道的有效边沿

4. 配置输入信号预分频器

   预分频系数决定了累计多少个有效信号边沿后触发一次有效事件

5. 将TIMx_CCER寄存器中的CC1E位置1，让计数器的捕获寄存器被使能

6. 在需要的情况下可以使能中断、DMA请求

   使能可以在任何时候通过软件操作外设控制寄存器进行


使用输入捕获时，推荐**在读出捕获溢出标志之前读取数据**，这样可避免丢失在读取捕获溢出标志之后与读取数据之前可能出现的重复捕获信息

PWM输入模式是输入捕获模式的一个特例，用于对输入的PWM信号进行针对性捕获、分析

其实现步骤与输入捕获模式基本相同，仅存在以下不同之处：

1. 两个 ICx 信号被映射至同一个 TIx 输入
2. 这两个 ICx 信号在边沿处有效，但极性相反
3. 需要选择两个 TIxFP 信号之一作为触发输入，并将从模式控制器配置为复位模式

### 输出比较与PWM输出

官方文档的输出比较模式总结如下：

> 输出比较用于控制输出波形，或指示已经过某一时间段
>
> 当输出捕获/比较寄存器与计数器之间相匹配时，输出比较将进行以下操作：
>
> 1. 为相应的输出引脚分配一个有可编程输出比较模式和输出极性的输出值。匹配时，输出引脚既可保持其电平 (OCXM=000)，也可设置为有效电平 (OCXM=001)、无效电平(OCXM=010) 或进行翻转 (OCxM=011)
> 2. 将中断状态寄存器中的标志置1
> 3. 如果相应中断或DMA使能位置1，将生成中断或发送DMA请求
>
> 此外，可以将TIMx_CCRx 寄存器配置为带或不带预装载寄存器；输出比较模式下，更新事件 UEV 对 OCxREF 和 OCx 输出毫无影响，同步的精度可以达到计数器的一个计数周期，输出比较模式也可用于输出单脉冲（在单脉冲模式下）
>
> 下面是基本使用步骤：
>
> 1. 选择计数器时钟（内部、外部、预分频器）
> 2. 如果要生成中断和/或 DMA 请求，将 CCxIE 位和/或 CCxDE 位置 1
> 3. 选择输出模式。例如，当 CNT 与 CCRx 匹配、未使用预装载 CCRx 并且 OCx 使能且为 高电平有效时，必须写入 OCxM=011、OCxPE=0、CCxP=0 和 CCxE=1 来翻转 OCx 输出引脚。
> 4. 通过将 TIMx_CR1 寄存器中的 CEN 位置 1 来使能计数器。
>
> 可随时通过软件更新 TIMx_CCRx 寄存器以控制输出波形，前提是未使能预装载寄存器 （OCxPE=0，否则仅当发生下一个更新事件 UEV 时，才会更新 TIMx_CCRx 影子寄存器）

PWM模式实际上是基于输出比较模式实现的

利用输出比较模式可以生成PWM信号，*信号频率由 TIMx_ARR 寄存器值决定，其占空比则 由 TIMx_CCRx 寄存器值决定*

> 通用定时器具有独立的4个通道用于PWM模式输出，必须通过将 TIMx_CCMRx 寄存器中的 OCxPE 位置 1 使能相应预装载寄存器，再通过将 TIMx_CR1 寄存器中的 ARPE 位置 1 使能自动重载预装载寄存器。由于只有在发生更新事件时预装载寄存器才会传送到影子寄存器，因此启动计数器之前，必须通过将 TIMx_EGR 寄存器中的 UG 位置 1 来初始化所有寄存器。OCx 极性可使用 TIMx_CCER 寄存器的 CCxP 位来编程。既可以设为高电平有效，也可以设为低电平有效。OCx 输出通过将 TIMx_CCER 寄存器中的 CCxE 位置 1 来使能
>
> 在PWM模式下，MCU会将TIMx_CNT与TIMx_CCRx进行比较，之后根据计数器计数方向输出特定值。当比较结果发生改变或从“冻结”配置转换回任意PWM模式时，OCREF信号变为有效状态
>
> 定时器运行期间，可以通过软件强制 PWM 输出。根据 TIMx_CR1 寄存器中的 CMS 位状态，定时器也能够产生边沿对齐模式或中心对齐模式的 PWM 信号。

PWM计数模式可配置为递增、递减、中心对齐三种，其中使用中心对齐模式时要注意以下几点：

* 启动中心对齐模式时**将使用当前的递增/递减计数配置**，计数器将根据写入TIMx_CR1 寄存器中 DIR 位的值进行递增或递减计数
* **不得同时**通过软件**修改**DIR 和 CMS 位
* 不建议在运行中心对齐模式时对计数器执行**写操作**，否则将发生意想不到的结果
* 使用中心对齐模式最为保险的方法是：在启动计数器前通过软件生成更新（将 TIMx_EGR寄存器中的 UG 位置 1），并且不要在计数器运行过程中对其执行写操作

### 强制输出模式

可以通过强制写入输出比较控制寄存器来强制定时器输出特定的电平

不太常用，官方文档介绍如下：

> 在输出模式（TIMx_CCMRx 寄存器中的 CCxS 位 = 00）下，可直接由软件将每个输出比较信号（OCxREF 和 OCx）强制设置为有效电平或无效电平，而无需考虑输出比较寄存器和计数器之间的任何比较结果
> 要将输出比较信号 (OCXREF/OCx) 强制设置为有效电平，只需向相应 TIMx_CCMRx 寄存器 中的 OCxM 位写入 101。ocxref 进而强制设置为高电平（OCxREF 始终为高电平有效）， 同时 OCx 获取 CCxP 极性位的相反值
> 例如：CCxP=0（OCx 高电平有效）=> OCx 强制设置为高电平
> 通过向 TIMx_CCMRx 寄存器中的 OCxM 位写入 100，可将 ocxref 信号强制设置为低电平
> 无论如何，TIMx_CCRx 影子寄存器与计数器之间的比较仍会执行，而且允许将标志置 1。 因此可发送相应的中断和 DMA 请求

### 单脉冲模式

**单脉冲模式**OPM是基本定时器模式的一个特例

在这种模式下，计数器可以**在一个激励信号的触发下启动**，并可**在一段可编程的延时后产生一个脉宽可编程的脉冲**

*这个模式比较像单稳态触发器逻辑*

可以通过从模式控制器启动计数器。可以在输出比较模式或 PWM 模式下生成波形。

开启方式：将 TIMx_CR1 寄存器中的 OPM 位置 1，即可选择单脉冲模式。发生下一更新事件 UEV 时，计数器将自动停止。只有当比较值与计数器初始值不同时，才能正确产生一个脉冲。

基本使用方法如下：

1. 将 TIxFPx 映射到 TIx，连接输入端口与单脉冲控制器
2. 设置有效边沿极性
3. 配置TIxFPx为从模式控制器的触发（TRGI）
4. 配置触发模式，设置使用TIxFPx来启动计数器
5. 正常配置时基单元
6. 将脉冲发生之前的延迟时间T~delay~写入TIMx_CCR1寄存器
7. 脉冲长度由自动重载值与比较值之差TIMx_ARR - TIMx_CCR1来定义

**特例情况——OCx快速使能**

单脉冲模式下，TIx 输入的边沿检测会将 CEN 位置 1，表示使能计数器。然后在计数器值与比较值之间发生比较时，将切换输出。

但是完成这些操作需要多个时钟周期，这会限制可能的最小延迟（tDELAY 最小值）。

如果要输出延迟时间最短的波形，可以将 TIMx_CCMRx 寄存器中的 OCxFE 位置 1。这样会强制 OCxRef（和 OCx）对激励信号做出响应，而不再考虑比较的结果。其新电平与发生比较匹配时相同。仅当通道配置为 PWM1 或 PWM2 模式时，OCxFE 才会起作用。

### 编码器接口模式

STM32提供了针对编码器控制的计数器优化

TI1 和 TI2 两个输入用于连接增量编码器，如下图所示

![image-20210521224858860](.\STM32F4深入学习_定时器.assets\image-20210521224858860.png)

使能计数器后，计数器的时钟由TI1FP1或YI2FP2上的**每次有效信号转换**提供。TI1FP1和TI2FP2是进行输入滤波器和极性选择后TI1和TI2的信号，如果不进行滤波和反相，则有TI1FP1=TI1，TI2FP2=TI2，根据两个输入的信号转换序列，定时器产生计数脉冲和方向信号，根据该信号转换序列，计数器相应递增或递减计数，同时硬件对TIMx_CR1寄存器的DIR位进行相应修改。任何输入（TI1 或 TI2）发生信号转换时，都会计算DIR位，无论计数器是仅在TI1或TI2边沿处计数还是同时在TI1和TI2处计数。可通过编程 TIMx_CCER 寄存器的 CC1P 和 CC2P 位选择 TI1 和 TI2 极性

**编码器接口模式就相当于带有方向选择的外部时钟**，计数器仅根据方向设定在 0 到 TIMx_ARR 寄存器中的自动重载值之间进行连续计数，在启动前必须先配置 TIMx_ARR。此外捕获、比较、预分频器、触发输出功能继续正常工作。在此模式下，计数器会根据增量编码器的速度和方向自动进行修改，**其内容始终表示编码器的位置**

使用该模式，外部增量编码器可直接与 MCU 相连，无需外部接口逻辑；通常使用比较器将编码器的差分输出转换为数字信号来提高抗噪声性能，用于指示机械零位的第三个编码器输出可与外部中断输入相连，用以触发计数器复位

定时器配置为**编码器接口模式**时，会提供传感器当前位置的相关信息。使用*另一个*配置为**捕获模式**的定时器**测量两个编码器事件之间的周期**，可获得动态信息（速度、加速度和减速度），指示机械零位的编码器输出即可用于此目的。根据两个事件之间的时间间隔，还可定期读取计数器——可以将计数器值锁存到第三个输入捕获寄存器来实现此目的（捕获信号必须为周期性信号，可以由另一个定时器产生）；还可以通过由RTC或其他定时器生成的DMA请求读取计数器值。

### 特殊配置——发生外部事件时清除OCxREF信号

对于给定通道，在 ETRF 输入施加高电平（相应 TIMx_CCMRx 寄存器中的 OCxCE 使能位置“1”），可使 OCxREF 信号变为低电平，此后OCxREF 信号将保持低电平直到发生下一更新事件 (UEV)
此功能仅能用于输出比较模式和 PWM 模式，不适用于强制输出模式

### 特殊配置——定时器输入异或

借助TIMx_CR2寄存器中的TI1S位，可将通道1的输入滤波器连接到**异或门**的输出，从而将TIMx_CH1到TIMx_CH3这三个输入引脚组合在一起。**异或输出可与触发或输入捕获等所有定时器输入功能配合使用**

## 通用定时器组2

> 备份！一定要备份！

通用定时器由TIM9到TIM14组成，包含一个16位自动重载计数器，该计数器由可编程预分频器驱动

支持的功能和通用定时器组1完全一致，但是少了两个定时器附属多功能通道

结构框图如下所示：

![image-20210521231253113](.\STM32F4深入学习_定时器.assets\image-20210521231253113.png)

同时这些定时器也难以实现定时器组1能够实现的一些复杂功能，因为它们的控制寄存器、多路选择器被削减了一部分

TIM9和TIM12比较特殊，可以实现其他定时器无法完成的PWM输入、外部触发同步和定时器同步/级联，可以用作定时器组1的补充

## 高级定时器

> 大外设，体积大，多来几个装不下

高级定时器由TIM1和TIM8组成，两个定时器共用一个16位自动重载计数器，该计数器由可编程预分频器驱动

支持以下功能

* 通过输入捕获测量输入信号脉冲宽度
* 生成输出比较和PWM波
* 生成带死区插入的互补PWM

高级定时器和通用定时器彼此完全独立，但两个高级定时器会共享资源

高级定时器和通用定时器可以实现同步功能

高级定时器拥有基本定时器、通用定时器的所有基础功能，并且内置了非常强大（但是在通用控制方面很少用到）的舵机、推进器、飞控、磁编码器等控制功能，可以说*一个更比六个强*！

下图是高级定时器的结构框图，足以看出其强大性能

![image-20210521231849841](.\STM32F4深入学习_定时器.assets\image-20210521231849841.png)

下面着重说明TIM1和TIM8与通用定时器不同的地方

### 重复计数器

高级定时器配备了一个**重复计数器**，只有当重复计数器达到零时，才会生成更新事件

每当发生N+1个计数器上溢或下溢（其中N是TIMx_RCR重复计数器寄存器中的值），数据就将从预装载寄存器转移到影子寄存器（TIMx_ARR自动重载寄存器、 TIMx_PSC预分频器寄存器以及比较模式下的TIMx_CCRx捕获/比较寄存器）中

重复计数器是自动重载类型，其重复率为TIMx_RCR寄存器所定义的值，它允许的定时器计数器重载最大重复次数不超过128个，每个PWM周期内可实现更新占空比两次。当在中心对齐模式下，每个PWM周期仅刷新一次比较寄存器时，由于模式的对称性，最大分辨率为2xTck

重复计数器在下列情况下递减：

1. 递增计数模式下的每个计数器上溢
2. 递减计数模式下的每个计数器下溢
3. 中心对齐模式下每个计数器上溢和计数器下溢

特别地，更新时间可以由软件或硬件人为生成，重复计数器会根据更新事件重新装载

中心对齐模式下如果RCR值为奇数，更新事件将在上溢或下溢时发生，这取决于何时写入RCR寄存器以及何时启动计数器：如果在启动计数器前写入RCR，则UEV在上溢时发生；如果在启动计数器后写入RCR，则UEV在下溢时发生

### 特化的PWM输出模式

根据TIMx_CR1寄存器中的CMS位状态，高级定时器能够产生**边沿对齐模式**或**中心对齐模式**的PWM信号

详情见参考手册，基本就是字面意思

### 互补输出与死区插入

TIM1和TIM8可以输出两路互补信号，并管理输出的关断与接通瞬间（死区时间），用户可以根据与输出相连接的器件及其特性（电平转换器的固有延迟、开关器件产生的延迟等等）来调整死区时间做到精准控制。每路输出可以独立选择输出极性（主输出OCx或互补输出OCxN），通过对TIMx_CCER寄存器中的CCxP和CCxNP位执行写操作来完成极性选择。

互补信号 OCx 和 OCxN 通过

1. TIMx_CCER 寄存器中的 CCxE 和 CCxNE 位
2. TIMx_BDTR 和 TIMx_CR2 寄存器中的 MOE、OISx、OISxN、OSSI 和 OSSR 位

以上控制位的组合进行激活。需要注意：切换至IDLE（MOE下降到0）的时刻，死区仍然有效

CCxE 和 CCxNE 位同时置 1 并且 MOE 位置 1（如果存在断路）时，使能死区插入。TIMx_BDTR 寄存器中的 DTG[7:0] 位用于控制所有通道的死区生成。高级定时器将基于参考波形 OCxREF 生成 2 个输出 OCx 和 OCxN。

示例：OCx 和 OCxN 为高电平有效时，

* 输出信号 OCx 与参考信号相同，只是其上升沿相对参考上升沿存在延迟。
* 输出信号 OCxN 与参考信号相反，并且其上升沿相对参考下降沿存在延迟。
* 如果延迟时间大于有效输出（OCx 或 OCxN）的宽度，则不会产生相应的脉冲

![image-20210522103114232](.\STM32F4深入学习_定时器.assets\image-20210522103114232.png)

![image-20210522103127846](.\STM32F4深入学习_定时器.assets\image-20210522103127846.png)
在输出模式（包括强制输出模式、输出比较模式和PWM模式）下，通过配置 TIMx_CCER 寄存 器中的 CCxE 和 CCxNE 位，可将 OCxREF 重定向到 OCx 输出或 OCxN 输出。通过此功能，可以在一个输出上发送特定波形（如PWM或静态有效电平)，而同时使互补输出保持无效电平；或者使两个输出同时保持无效电平；或者两个输出同时处于有效电平，两者互补并且带死区。

注意：如果仅使能 OCxN (CCxE=0, CCxNE=1)，两者不互补，一旦 OCxREF 为高电平，OCxN 即变为有效

示例：如果 CCxNP=0，则 OCxN=OCxRef。另一方面，如果同时使能 OCx 和 OCxN (CCxE=CCxNE=1)，OCx 在 OCxREF 为高电平时变为有效，而 OCxN 则与之互补， 在 OCxREF 为低电平时变为有效。

### 断路功能

> 使用断路功能时，根据其它控制位（TIMx_BDTR 寄存器中的 MOE、OSSI 和 OSSR 位以及 TIMx_CR2 寄存器中的 OISx 和 OISxN 位）修改输出使能信号和无效电平。断路源可以是断路输入引脚，也可以是时钟故障事件，后者由复位时钟控制器中的时钟安全系统 (CSS) 生成
>
> 注意：任何情况下， OCx 和 OCxN 输出都不能同时置为有效电平
> 退出复位状态后，断路功能处于禁止状态，MOE 位处于低电平。将 TIMx_BDTR 寄存器 中的 BKE 位置 1，可使能断路功能。断路输入的极性可通过该寄存器中的 BKP 位来选择。BKE 和 BKP 位可同时修改。对 BKE 和 BKP 位执行写操作时，写操作会在 1 个 APB 时钟周期的延迟后生效。因此，执行写操作后，需要等待 1 个 APB 时钟周期，才能准确回读该位。
>
> 由于 MOE 下降沿可能是异步信号，因此在实际信号（作用于输出）与同步控制位（位于 TIMx_BDTR 寄存器中）之间插入了再同步电路，从而在异步信号与同步信号之间产生延迟。例如：如果在 MOE 处于低电平时向其写入 1，则必须首先插入延迟（空指令）， 才能准确进行读取——因为写入的是异步信号，而读取的却是同步信号。
> 发生断路（断路输入上出现所选电平）时需要执行以下操作：
>
> * MOE 位异步清零，使输出处于无效状态、空闲状态或复位状态
>
>   即使 MCU 振荡器关闭，该功能仍然有效
>
> * MOE=0 时，将以 TIMx_CR2 寄存器 OISx 位中编程的电平驱动每个输出通道；如果OSSI=0，则定时器将释放使能输出，否则使能输出始终保持高电平
>
> 除断路输入和输出管理外，断路电路内部还实施了写保护，用以保护应用的安全，用户可冻结多个参数配置
>
> 使用互补输出时电路会自动遵守以下原则：
>
> 1. 输出首先置于复位状态或无效状态
> 2. 如果定时器时钟仍存在，则将重新激活死区发生器，在死区后以OISx和OISxN位中编程的电平驱动输出。即使在这种情况下，也不能同时将OCx和OCxN驱动至其有效电平。MOE会进行再同步，因此死区的持续时间会比通常情况长一些
> 3. 如果 OSSI=0，则定时器会释放使能输出，否则只要 CCxE 位或 CCxNE 位处于高电平，使能输出就会保持或变为高电平、
> 4. 可以通过配置寄存器使用定时器中断或DMA请求
> 5. 如果TIMx_BDTR寄存器中的AOE位置1，则MOE位会在发生下一更新事件(UEV)时自动再次置1
>
> 断路输入为电平有效。因此当断路输入有效电平时，不能将 MOE 位置 1（自动或通过软件都不行），也不能将状态标志 BIF 清零。断路可由 BRK 输入生成，该输入具有可编程极性，其使能位 BKE 位于 TIMx_BDTR 寄存器中
>
> 断路有两种生成方案：
>
> 1. 使用BRK输入生成，该输入具有可编程极性，其使能位 BKE 位于 TIMx_BDTR 寄存器中
> 2. 由软件通过 TIMx_EGR 寄存器中的 BG 位生成

### 生成六路互补PWM

可用于驱动三相交流异步电动机

当通道使用互补输出时，在OCxM、CCxE 和 CCxNE 位上提供预装载位。发生COM换向事件时，这些预装载位将传输到影子位。用户可以预先编程下一步骤的配置，并同时更改所有通道的配置。COM可由软件通过将 TIMx_EGR 寄存器中的 COM 位置 1 而生成，也可以由硬件在 TRGI 上升沿生成
发生 COM 事件时，TIMx_SR 寄存器中的 COMIF 位将会置 1。可以使用中断或DMA请求

### 霍尔传感器驱动

高级定时器最重要的功能之一就是直接驱动霍尔传感器

需要通过用于**生成电机驱动 PWM 信号的高级控制定时器**（TIM1、TIM8）以及中称为 “**接口定时器**”的**另一个通用定时器** TIMx（TIM2、TIM3、TIM4 或 TIM5），实现与霍尔传感器的连接。

连接要点如下所示：

* 3个高级定时器的输入引脚TIMx_CH1、TIMx_CH2 和 TIMx_CH3通过**异或门**连接到TI1输入通道（通过将TIMx_CR2寄存器中的TI1S位置1来选择），由“接口定时器” 进行捕获

* 从模式控制器配置为复位模式，从输入设置为 TI1F_ED

  每当3个输入中有一个输入发生切换时，计数器会从0开始重新计数。这样将产生由霍尔输入的任何变化而触发的时基

* 在“接口定时器”上，捕获/比较通道1配置为捕获模式，捕获信号为TRC。**捕获值对应于输入上两次变化的间隔时间**，可提供与电机转速相关的信息

* “接口定时器”可用于在输出模式下产生脉冲，以通过触发 COM 事件更改高级控制定时器 （TIM1 或 TIM8）各个通道的配置

* TIM1 定时器用于生成电机驱动 PWM 信号

* 必须对接口定时器通道进行编程，以便在编程的延迟过后产生正脉冲，该脉冲通过TRGO输出发送到高级控制定时器（TIM1 或 TIM8）

在高级控制定时器TIM1中，必须选择正确的 ITR 输入作为触发输入，定时器编程为可产生 PWM 信号，捕获/比较控制信号进行预装载（TIMx_CR2 寄存器的 CCPC=1），并且 COM 事件由触发输入控制（TIMx_CR2 寄存器中 CCUS=1）。发生 COM 事件后，在 PWM 控制 位（CCxE、OCxM）中写入下一步的配置，此操作可在由 OC2REF 上升沿产生的中断子程序中完成。

示例程序的时序图如下：

![image-20210522104705636](.\STM32F4深入学习_定时器.assets\image-20210522104705636.png)

## 基本定时器

> 别鞭尸了，有种比比销量——8051

基本定时器由TIM6和TIM7组成，包含一个16位自动重载计数器，该计数器由可编程预分频器驱动

可以用作通用定时器生成时基，也可以专用于驱动DAC——这两个定时器内部直连DAC并能够通过它触发输出驱动DAC，也就是说**TIM6和TIM7可以用作“模拟输出”**

两个定时器彼此完全独立，不共享资源

![image-20210521231037664](.\STM32F4深入学习_定时器.assets\image-20210521231037664.png)

基本定时器的结构非常简单，形如其名——只有定时器的基本功能

**基本定时器适合于单纯需要定时的场合，因此常被用来当作备用的“SysTick”**

如果定时器资源不够用，不妨将简单的定时任务交给TIM6、7完成

# STM32的STP定时器库函数

> 从STP换到HAL，没想到愣是没有一丝改变

STM32的定时器库函数**非常多**

这里作以下基本梳理（大多是从.c文件开头的注释翻译整理）

## 库函数的基本使用方法

库函数被分成了9组功能，如下所示

### TIM时基管理

ST提供了一些库函数用来管理定时器的基础设置

时基管理的使用方法很简单，如下所示

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE)函数开启定时器时钟
> 2. 使用设定好的参数设置定时器初始化结构体
> 3. 使用TIM_TimeBaseInit()函数来应用定时器时基设置
> 4. 如果需要产生TIM更新中断，还需要使能NVIC并进行相关配置
> 5. 使用TIM_ITConfig(TIMx, TIM_IT_Update)函数配置中断服务函数
> 6. 使用TIM_Cmd(ENABLE)函数使能TIM计数器

* 设置/获取分频系数Prescaler

```c
//设置分频系数
void TIM_PrescalerConfig(TIM_TypeDef* TIMx, uint16_t Prescaler, uint16_t TIM_PSCReloadMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_PRESCALER_RELOAD(TIM_PSCReloadMode));
  /* Set the Prescaler value */
  TIMx->PSC = Prescaler;
  /* Set or reset the UG Bit */
  TIMx->EGR = TIM_PSCReloadMode;
}
```

* 设置/获取自动重装值Autoreload

```c
//设置定时器自动重装载值
void TIM_SetAutoreload(TIM_TypeDef* TIMx, uint32_t Autoreload)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  
  /* Set the Autoreload Register value */
  TIMx->ARR = Autoreload;
}

//获取定时器自动重装载值
uint16_t TIM_GetPrescaler(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Get the Prescaler Register value */
  return TIMx->PSC;
}

//设置定时器计数器寄存器值
void TIM_SetCounter(TIM_TypeDef* TIMx, uint32_t Counter)
{
  /* Check the parameters */
   assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Set the Counter Register value */
  TIMx->CNT = Counter;
}

//获取定时器计数器寄存器值
uint32_t TIM_GetCounter(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Get the Counter Register value */
  return TIMx->CNT;
}
```

* 计时模式配置

```c
//设置定时器计数器模式
void TIM_CounterModeConfig(TIM_TypeDef* TIMx, uint16_t TIM_CounterMode)
{
  uint16_t tmpcr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_COUNTER_MODE(TIM_CounterMode));

  tmpcr1 = TIMx->CR1;

  /* Reset the CMS and DIR Bits */
  tmpcr1 &= (uint16_t)~(TIM_CR1_DIR | TIM_CR1_CMS);

  /* Set the Counter Mode */
  tmpcr1 |= TIM_CounterMode;

  /* Write to TIMx CR1 register */
  TIMx->CR1 = tmpcr1;
}
```

* 设置时钟分频

```c
void TIM_SetClockDivision(TIM_TypeDef* TIMx, uint16_t TIM_CKD)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_CKD_DIV(TIM_CKD));

  /* Reset the CKD Bits */
  TIMx->CR1 &= (uint16_t)(~TIM_CR1_CKD);

  /* Set the CKD value */
  TIMx->CR1 |= TIM_CKD;
}
```

* 选择单脉冲模式

```c
void TIM_SelectOnePulseMode(TIM_TypeDef* TIMx, uint16_t TIM_OPMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_OPM_MODE(TIM_OPMode));

  /* Reset the OPM Bit */
  TIMx->CR1 &= (uint16_t)~TIM_CR1_OPM;

  /* Configure the OPM Mode */
  TIMx->CR1 |= TIM_OPMode;
}
```

* 更新请求配置

```c
//定时器更新中断请求配置
void TIM_UpdateRequestConfig(TIM_TypeDef* TIMx, uint16_t TIM_UpdateSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_UPDATE_SOURCE(TIM_UpdateSource));

  if (TIM_UpdateSource != TIM_UpdateSource_Global)
  {
    /* Set the URS Bit */
    TIMx->CR1 |= TIM_CR1_URS;
  }
  else
  {
    /* Reset the URS Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_URS;
  }
}
```

* 更新失能配置

```c
//定时器更新中断失能控制
void TIM_UpdateDisableConfig(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the Update Disable Bit */
    TIMx->CR1 |= TIM_CR1_UDIS;
  }
  else
  {
    /* Reset the Update Disable Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_UDIS;
  }
}
```

* 自动重装载配置

```c
//ARR预装载寄存器配置
void TIM_ARRPreloadConfig(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the ARR Preload Bit */
    TIMx->CR1 |= TIM_CR1_ARPE;
  }
  else
  {
    /* Reset the ARR Preload Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_ARPE;
  }
}
```

* 使能/关闭计数器

```c
void TIM_Cmd(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the TIM Counter */
    TIMx->CR1 |= TIM_CR1_CEN;
  }
  else
  {
    /* Disable the TIM Counter */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_CEN;
  }
}
```

相关函数如下所示

```c
//取消定时器初始化并关闭时钟
void TIM_DeInit(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
 
  if (TIMx == TIM1)
  {
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM1, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM1, DISABLE);  
  } 
  else if (TIMx == TIM2) 
  {     
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM2, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM2, DISABLE);
  }  
  else if (TIMx == TIM3)
  { 
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM3, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM3, DISABLE);
  }  
  else if (TIMx == TIM4)
  { 
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM4, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM4, DISABLE);
  }  
  else if (TIMx == TIM5)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM5, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM5, DISABLE);
  }  
  else if (TIMx == TIM6)  
  {    
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM6, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM6, DISABLE);
  }  
  else if (TIMx == TIM7)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM7, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM7, DISABLE);
  }  
  else if (TIMx == TIM8)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM8, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM8, DISABLE);  
  }  
  else if (TIMx == TIM9)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM9, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM9, DISABLE);  
   }  
  else if (TIMx == TIM10)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM10, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM10, DISABLE);  
  }  
  else if (TIMx == TIM11) 
  {     
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM11, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM11, DISABLE);  
  }  
  else if (TIMx == TIM12)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM12, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM12, DISABLE);  
  }  
  else if (TIMx == TIM13) 
  {       
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM13, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM13, DISABLE);  
  }  
  else
  { 
    if (TIMx == TIM14) 
    {     
      RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM14, ENABLE);
      RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM14, DISABLE); 
    }   
  }
}

//根据已有设置配置定时器初始化结构体
void TIM_TimeBaseStructInit(TIM_TimeBaseInitTypeDef* TIM_TimeBaseInitStruct)
{
  /* Set the default configuration */
  TIM_TimeBaseInitStruct->TIM_Period = 0xFFFFFFFF;
  TIM_TimeBaseInitStruct->TIM_Prescaler = 0x0000;
  TIM_TimeBaseInitStruct->TIM_ClockDivision = TIM_CKD_DIV1;
  TIM_TimeBaseInitStruct->TIM_CounterMode = TIM_CounterMode_Up;
  TIM_TimeBaseInitStruct->TIM_RepetitionCounter = 0x0000;
}

//根据初始化结构体配置定时器设置
void TIM_TimeBaseInit(TIM_TypeDef* TIMx, TIM_TimeBaseInitTypeDef* TIM_TimeBaseInitStruct)
{
  uint16_t tmpcr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
  assert_param(IS_TIM_COUNTER_MODE(TIM_TimeBaseInitStruct->TIM_CounterMode));
  assert_param(IS_TIM_CKD_DIV(TIM_TimeBaseInitStruct->TIM_ClockDivision));

  tmpcr1 = TIMx->CR1;  

  if((TIMx == TIM1) || (TIMx == TIM8)||
     (TIMx == TIM2) || (TIMx == TIM3)||
     (TIMx == TIM4) || (TIMx == TIM5)) 
  {
    /* Select the Counter Mode */
    tmpcr1 &= (uint16_t)(~(TIM_CR1_DIR | TIM_CR1_CMS));
    tmpcr1 |= (uint32_t)TIM_TimeBaseInitStruct->TIM_CounterMode;
  }
 
  if((TIMx != TIM6) && (TIMx != TIM7))
  {
    /* Set the clock division */
    tmpcr1 &=  (uint16_t)(~TIM_CR1_CKD);
    tmpcr1 |= (uint32_t)TIM_TimeBaseInitStruct->TIM_ClockDivision;
  }

  TIMx->CR1 = tmpcr1;

  /* Set the Autoreload value */
  TIMx->ARR = TIM_TimeBaseInitStruct->TIM_Period ;
 
  /* Set the Prescaler value */
  TIMx->PSC = TIM_TimeBaseInitStruct->TIM_Prescaler;
    
  if ((TIMx == TIM1) || (TIMx == TIM8))  
  {
    /* Set the Repetition Counter value */
    TIMx->RCR = TIM_TimeBaseInitStruct->TIM_RepetitionCounter;
  }

  /* Generate an update event to reload the Prescaler 
     and the repetition counter(only for TIM1 and TIM8) value immediatly */
  TIMx->EGR = TIM_PSCReloadMode_Immediate;          
}
```

### TIM输出比较管理

ST提供了有关输出捕获与输出比较的库函数

输出捕获实际上就是对定时器的输出信号进行监测，从而实现PWM等操作

使用方法如下：

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE)函数开启定时器时钟
> 2. 配置GPIO为复用模式并配置定时器到GPIO的复用选项
> 3. 使用下面的参数配置定时器时基单元初始化结构体设置
>    * 自动重装载值 = 0xFFFF
>    * 分频系数 = 0x0000
>    * 计数模式：向上计数
>    * 时钟分频：TIM_CKD_DIV1
> 4. 使用下面的参数配置定时器输出捕获初始化结构体设置
>    * 输出比较模式：TIM_OCMode
>    * 输出状态：TIM_OutputState
>    * 定时器脉冲值：TIM_Pulse
>    * 定时器输出比较极性：根据输出比较所需电平有效性选择
> 5. 使用TIM_OCxInit(TIMx, &TIM_OCInitStruct)函数使用合适的配置来设置所需的通道
> 6. 使用TIM_Cmd(ENABLE)使能定时器计数器
> 7. 如果要使用PWM输出，需要额外使能输出捕获预装载寄存器，使用函数TIM_OCxPreloadConfig(TIMx, TIM_OCPreload_ENABLE)
> 8. 可以在输出捕获的基础上使用定时器中断或DMA，只要使用对应库函数TIM_ITConfig(TIMx, TIM_IT_CCx)或TIM_DMA_Cmd(TIMx, TIM_DMA_CCx)提前进行配置即可

输出捕获的最简单用法就是PWM，但是除了这个功能，他还能实现更多更复杂的功能，相关库函数如下：

* 将每个通道独立配置为输出比较

```c
//初始化通道1输入捕获
void TIM_OC1Init(TIM_TypeDef* TIMx, TIM_OCInitTypeDef* TIM_OCInitStruct)
{
  uint16_t tmpccmrx = 0, tmpccer = 0, tmpcr2 = 0;
   
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_OC_MODE(TIM_OCInitStruct->TIM_OCMode));
  assert_param(IS_TIM_OUTPUT_STATE(TIM_OCInitStruct->TIM_OutputState));
  assert_param(IS_TIM_OC_POLARITY(TIM_OCInitStruct->TIM_OCPolarity));   

  /* Disable the Channel 1: Reset the CC1E Bit */
  TIMx->CCER &= (uint16_t)~TIM_CCER_CC1E;
  
  /* Get the TIMx CCER register value */
  tmpccer = TIMx->CCER;
  /* Get the TIMx CR2 register value */
  tmpcr2 =  TIMx->CR2;
  
  /* Get the TIMx CCMR1 register value */
  tmpccmrx = TIMx->CCMR1;
    
  /* Reset the Output Compare Mode Bits */
  tmpccmrx &= (uint16_t)~TIM_CCMR1_OC1M;
  tmpccmrx &= (uint16_t)~TIM_CCMR1_CC1S;
  /* Select the Output Compare Mode */
  tmpccmrx |= TIM_OCInitStruct->TIM_OCMode;
  
  /* Reset the Output Polarity level */
  tmpccer &= (uint16_t)~TIM_CCER_CC1P;
  /* Set the Output Compare Polarity */
  tmpccer |= TIM_OCInitStruct->TIM_OCPolarity;
  
  /* Set the Output State */
  tmpccer |= TIM_OCInitStruct->TIM_OutputState;
    
  if((TIMx == TIM1) || (TIMx == TIM8))
  {
    assert_param(IS_TIM_OUTPUTN_STATE(TIM_OCInitStruct->TIM_OutputNState));
    assert_param(IS_TIM_OCN_POLARITY(TIM_OCInitStruct->TIM_OCNPolarity));
    assert_param(IS_TIM_OCNIDLE_STATE(TIM_OCInitStruct->TIM_OCNIdleState));
    assert_param(IS_TIM_OCIDLE_STATE(TIM_OCInitStruct->TIM_OCIdleState));
    
    /* Reset the Output N Polarity level */
    tmpccer &= (uint16_t)~TIM_CCER_CC1NP;
    /* Set the Output N Polarity */
    tmpccer |= TIM_OCInitStruct->TIM_OCNPolarity;
    /* Reset the Output N State */
    tmpccer &= (uint16_t)~TIM_CCER_CC1NE;
    
    /* Set the Output N State */
    tmpccer |= TIM_OCInitStruct->TIM_OutputNState;
    /* Reset the Output Compare and Output Compare N IDLE State */
    tmpcr2 &= (uint16_t)~TIM_CR2_OIS1;
    tmpcr2 &= (uint16_t)~TIM_CR2_OIS1N;
    /* Set the Output Idle state */
    tmpcr2 |= TIM_OCInitStruct->TIM_OCIdleState;
    /* Set the Output N Idle state */
    tmpcr2 |= TIM_OCInitStruct->TIM_OCNIdleState;
  }
  /* Write to TIMx CR2 */
  TIMx->CR2 = tmpcr2;
  
  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmrx;
  
  /* Set the Capture Compare Register value */
  TIMx->CCR1 = TIM_OCInitStruct->TIM_Pulse;
  
  /* Write to TIMx CCER */
  TIMx->CCER = tmpccer;
}

//初始化通道2、通道3、通道4的库函数与初始化通道1库函数不能说一模一样，只能说别无二致，所以在此不列出

//使用默认设置初始化输入捕获初始化结构体
void TIM_OCStructInit(TIM_OCInitTypeDef* TIM_OCInitStruct)
{
  /* Set the default configuration */
  TIM_OCInitStruct->TIM_OCMode = TIM_OCMode_Timing;
  TIM_OCInitStruct->TIM_OutputState = TIM_OutputState_Disable;
  TIM_OCInitStruct->TIM_OutputNState = TIM_OutputNState_Disable;
  TIM_OCInitStruct->TIM_Pulse = 0x00000000;
  TIM_OCInitStruct->TIM_OCPolarity = TIM_OCPolarity_High;
  TIM_OCInitStruct->TIM_OCNPolarity = TIM_OCPolarity_High;
  TIM_OCInitStruct->TIM_OCIdleState = TIM_OCIdleState_Reset;
  TIM_OCInitStruct->TIM_OCNIdleState = TIM_OCNIdleState_Reset;
}

```

* 选择输出比较模式

```c
//选择输出比较的通道、使用定时器x、输出比较的模式
void TIM_SelectOCxM(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_OCMode)
{
  uint32_t tmp = 0;
  uint16_t tmp1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_OCM(TIM_OCMode));

  tmp = (uint32_t) TIMx;
  tmp += CCMR_OFFSET;

  tmp1 = CCER_CCE_SET << (uint16_t)TIM_Channel;

  /* Disable the Channel: Reset the CCxE Bit */
  TIMx->CCER &= (uint16_t) ~tmp1;

  if((TIM_Channel == TIM_Channel_1) ||(TIM_Channel == TIM_Channel_3))
  {
    tmp += (TIM_Channel>>1);

    /* Reset the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp &= CCMR_OC13M_MASK;
   
    /* Configure the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp |= TIM_OCMode;
  }
  else
  {
    tmp += (uint16_t)(TIM_Channel - (uint16_t)4)>> (uint16_t)1;

    /* Reset the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp &= CCMR_OC24M_MASK;
    
    /* Configure the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp |= (uint16_t)(TIM_OCMode << 8);
  }
}
/*
可以使用如下模式：
定时 TIM_OCMode_Timing
启动 TIM_OCMode_Active
翻转 TIM_OCMode_Toggle
PWM模式1 TIM_OCMode_PWM1
PWM模式2 TIM_OCMode_PWM2
强制启动 TIM_ForcedAction_Active
强制停止 TIM_ForcedAction_InActive
*/
```

* 选择每个通道的极性

```c
//设置正极性
void TIM_OC1PolarityConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCPolarity)
{
  uint16_t tmpccer = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OC_POLARITY(TIM_OCPolarity));

  tmpccer = TIMx->CCER;

  /* Set or Reset the CC1P Bit */
  tmpccer &= (uint16_t)(~TIM_CCER_CC1P);
  tmpccer |= TIM_OCPolarity;

  /* Write to TIMx CCER register */
  TIMx->CCER = tmpccer;
}

//设置负极性
void TIM_OC1NPolarityConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCNPolarity)
{
  uint16_t tmpccer = 0;
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_OCN_POLARITY(TIM_OCNPolarity));
   
  tmpccer = TIMx->CCER;

  /* Set or Reset the CC1NP Bit */
  tmpccer &= (uint16_t)~TIM_CCER_CC1NP;
  tmpccer |= TIM_OCNPolarity;

  /* Write to TIMx CCER register */
  TIMx->CCER = tmpccer;
}

//两个库函数都有4个不同通道的设置，在此仅列出通道1
```

* 设置/获取输出捕获/比较寄存器的值

```c
//设置输出比较寄存器1、2、3、4的值
//每个输出比较寄存器对应一个通道
void TIM_SetCompare1(TIM_TypeDef* TIMx, uint32_t Compare1)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));

  /* Set the Capture Compare1 Register value */
  TIMx->CCR1 = Compare1;
}

void TIM_SetCompare2(TIM_TypeDef* TIMx, uint32_t Compare2)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Set the Capture Compare2 Register value */
  TIMx->CCR2 = Compare2;
}

//3、4的库函数和1、2大同小异，在此不列出

//设置输出捕获寄存器1、2、3、4的值，2、3、4的设置库函数不列出
void TIM_ForcedOC1Config(TIM_TypeDef* TIMx, uint16_t TIM_ForcedAction)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_FORCED_ACTION(TIM_ForcedAction));
  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1M Bits */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1M;

  /* Configure The Forced output Mode */
  tmpccmr1 |= TIM_ForcedAction;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}

//设置定时器输出捕获预装载寄存器的值（同样是4个通道）
void TIM_OC1PreloadConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCPreload)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCPRELOAD_STATE(TIM_OCPreload));

  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1PE Bit */
  tmpccmr1 &= (uint16_t)(~TIM_CCMR1_OC1PE);

  /* Enable or Disable the Output Compare Preload feature */
  tmpccmr1 |= TIM_OCPreload;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}
```

* 选择输出比较快速模式（Output Compare Fast mode）

```c
//输出比较快速模式设置（4个通道）
void TIM_OC1FastConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCFast)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCFAST_STATE(TIM_OCFast));

  /* Get the TIMx CCMR1 register value */
  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1FE Bit */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1FE;

  /* Enable or Disable the Output Compare Fast Bit */
  tmpccmr1 |= TIM_OCFast;

  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmr1;
}

```

* 选择输出比较强制模式（Output Compare Forced mode）
* 输出比较-预装载模式
* 清空输出比较参考值

```c
//清空输出比较参考值（4通道）
void TIM_ClearOC1Ref(TIM_TypeDef* TIMx, uint16_t TIM_OCClear)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCCLEAR_STATE(TIM_OCClear));

  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1CE Bit */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1CE;

  /* Enable or Disable the Output Compare Clear Bit */
  tmpccmr1 |= TIM_OCClear;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}
```

* 选择OCREF清空信号
* 使能/失能捕获/比较通道

```c
//控制捕获通道开启/关闭
void TIM_CCxCmd(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_CCx)
{
  uint16_t tmp = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_CCX(TIM_CCx));

  tmp = CCER_CCE_SET << TIM_Channel;

  /* Reset the CCxE Bit */
  TIMx->CCER &= (uint16_t)~ tmp;

  /* Set or reset the CCxE Bit */ 
  TIMx->CCER |=  (uint16_t)(TIM_CCx << TIM_Channel);
}

//控制捕获比较通道开启/关闭
void TIM_CCxNCmd(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_CCxN)
{
  uint16_t tmp = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_COMPLEMENTARY_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_CCXN(TIM_CCxN));

  tmp = CCER_CCNE_SET << TIM_Channel;

  /* Reset the CCxNE Bit */
  TIMx->CCER &= (uint16_t) ~tmp;

  /* Set or reset the CCxNE Bit */ 
  TIMx->CCER |=  (uint16_t)(TIM_CCxN << TIM_Channel);
}
```

### TIM输入捕获管理

ST也提供了定时器输入捕获的库函数

基本使用方法如下：

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE) 函数开启定时器时钟
> 2. 将GPIO配置为合适的输入引脚，设置位复用模式并连接到定时器输入捕获
> 3. 如果需要可以自行配置定时器时基设定，但推荐默认状态为：
>    * 自动重装载值：0xFFFF
>    * 分频值：0x0000
>    * 计数模式：向上计数
>    * 时钟分频：TIM_CKD_DIV1一分频
> 4. 使用以下参数配置定时器输入捕获初始化结构体
>    * 定时器通道：选择合适的通道
>    * 定时器输入捕获选项：根据输入捕获选择
>    * 定时器输入捕获分频：随机应变
>    * 定时器输入捕获屏蔽器值：根据要过滤的捕获信号设置
> 5. 使用TIM_ICInit(TIMx, &TIM_ICInitStruct)函数根据上面的设置配置所需通道，就可以让定时器输入捕获测量输入信号的频率、占空比，或使用TIM_PWMIConfig(TIMx, &TIM_ICInitStruct)函数配置通道来测量输入PWM波的频率和占空比
> 6. 可使用中断或DMA方式读取测量信号，TIM_ITConfig(TIMx, TIM_IT_CCx)和TIM_DMA_Cmd(TIMx, TIM_DMA_CCx)函数都可选
> 7. 使用TIM_Cmd(ENABLE)来开启定时器计数器
> 8. 使用TIM_GetCapturex(TIMx)来读取捕获到的值

* 单独配置每个通道位输入捕获模式

```c
//根据输入捕获初始化结构体配置某个通道为输入捕获模式
void TIM_ICInit(TIM_TypeDef* TIMx, TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_POLARITY(TIM_ICInitStruct->TIM_ICPolarity));
  assert_param(IS_TIM_IC_SELECTION(TIM_ICInitStruct->TIM_ICSelection));
  assert_param(IS_TIM_IC_PRESCALER(TIM_ICInitStruct->TIM_ICPrescaler));
  assert_param(IS_TIM_IC_FILTER(TIM_ICInitStruct->TIM_ICFilter));
  
  if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_1)
  {
    /* TI1 Configuration */
    TI1_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_2)
  {
    /* TI2 Configuration */
    assert_param(IS_TIM_LIST2_PERIPH(TIMx));
    TI2_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_3)
  {
    /* TI3 Configuration */
    assert_param(IS_TIM_LIST3_PERIPH(TIMx));
    TI3_Config(TIMx,  TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC3Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else
  {
    /* TI4 Configuration */
    assert_param(IS_TIM_LIST3_PERIPH(TIMx));
    TI4_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC4Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
}

//使用默认设置配置输入捕获初始化结构体
void TIM_ICStructInit(TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  /* Set the default configuration */
  TIM_ICInitStruct->TIM_Channel = TIM_Channel_1;
  TIM_ICInitStruct->TIM_ICPolarity = TIM_ICPolarity_Rising;
  TIM_ICInitStruct->TIM_ICSelection = TIM_ICSelection_DirectTI;
  TIM_ICInitStruct->TIM_ICPrescaler = TIM_ICPSC_DIV1;
  TIM_ICInitStruct->TIM_ICFilter = 0x00;
}
```

* 可配置通道1/2处于PWM输入模式，用于获取外部脉冲/测量外部信号频率（如编码器输入、遥控信号输入等）

```c
//配置通道为PWM输入模式
void TIM_PWMIConfig(TIM_TypeDef* TIMx, TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  uint16_t icoppositepolarity = TIM_ICPolarity_Rising;
  uint16_t icoppositeselection = TIM_ICSelection_DirectTI;

  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Select the Opposite Input Polarity */
  if (TIM_ICInitStruct->TIM_ICPolarity == TIM_ICPolarity_Rising)
  {
    icoppositepolarity = TIM_ICPolarity_Falling;
  }
  else
  {
    icoppositepolarity = TIM_ICPolarity_Rising;
  }
  /* Select the Opposite Input */
  if (TIM_ICInitStruct->TIM_ICSelection == TIM_ICSelection_DirectTI)
  {
    icoppositeselection = TIM_ICSelection_IndirectTI;
  }
  else
  {
    icoppositeselection = TIM_ICSelection_DirectTI;
  }
  if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_1)
  {
    /* TI1 Configuration */
    TI1_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity, TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
    /* TI2 Configuration */
    TI2_Config(TIMx, icoppositepolarity, icoppositeselection, TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else
  { 
    /* TI2 Configuration */
    TI2_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity, TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
    /* TI1 Configuration */
    TI1_Config(TIMx, icoppositepolarity, icoppositeselection, TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
}
```

* 设置输入捕获预分频器

```c
//设置输入捕获1、2、3、4通道预分频器的值
void TIM_SetIC1Prescaler(TIM_TypeDef* TIMx, uint16_t TIM_ICPSC)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_PRESCALER(TIM_ICPSC));

  /* Reset the IC1PSC Bits */
  TIMx->CCMR1 &= (uint16_t)~TIM_CCMR1_IC1PSC;

  /* Set the IC1PSC value */
  TIMx->CCMR1 |= TIM_ICPSC;
}
```

* 获取捕获/比较值

```c
//获取输入捕获1、2、3、4的值
uint32_t TIM_GetCapture1(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));

  /* Get the Capture 1 Register value */
  return TIMx->CCR1;
}

uint32_t TIM_GetCapture2(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Get the Capture 2 Register value */
  return TIMx->CCR2;
}

uint32_t TIM_GetCapture3(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx)); 

  /* Get the Capture 3 Register value */
  return TIMx->CCR3;
}

uint32_t TIM_GetCapture4(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));

  /* Get the Capture 4 Register value */
  return TIMx->CCR4;
}
```

### 高级定时器（TIM1、TIM8）的特殊控制库函数

STM32F4中具有两个高级定时器，ST也为它们提供了库函数

下面是基本使用方法

> 1. 使用输出比较模式配置定时器通道
> 2. 使用TIM_BDTRInitStruct结构体设置时钟断点极性、死区时间、锁定等级、OSSI/OSSR状态和AOE（自动输出使能）模式
> 3. 使用TIM_BDTRConfig(TIMx, &TIM_BDTRInitStruct)配置定时器的高级功能
> 4. 使用TIM_CtrlPWMOutputs(TIM1, ENABLE)函数使能主输出
> 5. 一旦断点发生，定时器的输出信号就会被置于重置或某个经过TIM_BDTRConfig()设定的状态

* 配置断点输入（Break input）、死区时间、锁定等级、OSSI、OSSR状态、AOE（自动输入使能）

```c
void TIM_BDTRConfig(TIM_TypeDef* TIMx, TIM_BDTRInitTypeDef *TIM_BDTRInitStruct)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_OSSR_STATE(TIM_BDTRInitStruct->TIM_OSSRState));
  assert_param(IS_TIM_OSSI_STATE(TIM_BDTRInitStruct->TIM_OSSIState));
  assert_param(IS_TIM_LOCK_LEVEL(TIM_BDTRInitStruct->TIM_LOCKLevel));
  assert_param(IS_TIM_BREAK_STATE(TIM_BDTRInitStruct->TIM_Break));
  assert_param(IS_TIM_BREAK_POLARITY(TIM_BDTRInitStruct->TIM_BreakPolarity));
  assert_param(IS_TIM_AUTOMATIC_OUTPUT_STATE(TIM_BDTRInitStruct->TIM_AutomaticOutput));

  /* Set the Lock level, the Break enable Bit and the Polarity, the OSSR State,
     the OSSI State, the dead time value and the Automatic Output Enable Bit */
  TIMx->BDTR = (uint32_t)TIM_BDTRInitStruct->TIM_OSSRState | TIM_BDTRInitStruct->TIM_OSSIState |
             TIM_BDTRInitStruct->TIM_LOCKLevel | TIM_BDTRInitStruct->TIM_DeadTime |
             TIM_BDTRInitStruct->TIM_Break | TIM_BDTRInitStruct->TIM_BreakPolarity |
             TIM_BDTRInitStruct->TIM_AutomaticOutput;
}

//使用初始化结构体默认设置
void TIM_BDTRStructInit(TIM_BDTRInitTypeDef* TIM_BDTRInitStruct)
{
  /* Set the default configuration */
  TIM_BDTRInitStruct->TIM_OSSRState = TIM_OSSRState_Disable;
  TIM_BDTRInitStruct->TIM_OSSIState = TIM_OSSIState_Disable;
  TIM_BDTRInitStruct->TIM_LOCKLevel = TIM_LOCKLevel_OFF;
  TIM_BDTRInitStruct->TIM_DeadTime = 0x00;
  TIM_BDTRInitStruct->TIM_Break = TIM_Break_Disable;
  TIM_BDTRInitStruct->TIM_BreakPolarity = TIM_BreakPolarity_Low;
  TIM_BDTRInitStruct->TIM_AutomaticOutput = TIM_AutomaticOutput_Disable;
}
```

* 使能/失能定时器外设主输出

```c
void TIM_CtrlPWMOutputs(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Enable the TIM Main Output */
    TIMx->BDTR |= TIM_BDTR_MOE;
  }
  else
  {
    /* Disable the TIM Main Output */
    TIMx->BDTR &= (uint16_t)~TIM_BDTR_MOE;
  }  
}
```

* 选择通讯事件

```c
//选择通信事件
void TIM_SelectCOM(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the COM Bit */
    TIMx->CR2 |= TIM_CR2_CCUS;
  }
  else
  {
    /* Reset the COM Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCUS;
  }
}
```

* 设置/重置捕获比较预装载控制位

```c
//设置捕获比较预装载控制位
void TIM_CCPreloadControl(TIM_TypeDef* TIMx, FunctionalState NewState)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  if (NewState != DISABLE)
  {
    /* Set the CCPC Bit */
    TIMx->CR2 |= TIM_CR2_CCPC;
  }
  else
  {
    /* Reset the CCPC Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCPC;
  }
}
```

### 定时器中断、DMA与标志位管理

STM32中的一些定时器是可以触发定时器中断、DMA的，ST也提供了管理库函数

* 使能/失能中断源

```c
//使能或关闭定时器中断
void TIM_ITConfig(TIM_TypeDef* TIMx, uint16_t TIM_IT, FunctionalState NewState)
{  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_IT(TIM_IT));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the Interrupt sources */
    TIMx->DIER |= TIM_IT;
  }
  else
  {
    /* Disable the Interrupt sources */
    TIMx->DIER &= (uint16_t)~TIM_IT;
  }
}

/* 
TIM_IT参数可设置为以下值
TIM_IT_Update:定时器更新中断
TIM_IT_CC1:定时器比较中断4
TIM_IT_CC2:定时器比较中断4
TIM_IT_CC3:定时器比较中断4
TIM_IT_CC4:定时器比较中断4
TIM_IT_COM:定时器通讯中断
TIM_IT_Trigger:定时器触发中断
TIM_IT_Break:定时器暂停中断

TIM6和TIM7只能使用TIM_IT_Update，TIM9和TIM12只能使用TIM_IT_Update，TIM_IT_CC1, TIM_IT_CC2或TIM_IT_Trigger
TIM10、11、13、14只能使用TIM_IT_Update或TIM_IT_CC1
TIM1和TIM8两个高级定时器才被允许使用TIM_IT_COM和TIM_IT_Break
*/

//设置定时器软件事件
void TIM_GenerateEvent(TIM_TypeDef* TIMx, uint16_t TIM_EventSource)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_EVENT_SOURCE(TIM_EventSource));
 
  /* Set the event sources */
  TIMx->EGR = TIM_EventSource;
}

/*
TIM_EventSource_Update:定时器更新事件（下面内容和上面中断的内冲差不多，懒得翻译了）
TIM_EventSource_CC1: Timer Capture Compare 1 Event source
TIM_EventSource_CC2: Timer Capture Compare 2 Event source
TIM_EventSource_CC3: Timer Capture Compare 3 Event source
TIM_EventSource_CC4: Timer Capture Compare 4 Event source
TIM_EventSource_COM: Timer COM event source  
TIM_EventSource_Trigger: Timer Trigger Event source
TIM_EventSource_Break: Timer Break event source

其中TIM6、7只能使用定时器更新事件；只有高级定时器TIM1、8才能使用后三个高级事件功能
*/
```

* 获取标志状态

```c
//获取当前中断标志位状态
FlagStatus TIM_GetFlagStatus(TIM_TypeDef* TIMx, uint16_t TIM_FLAG)
{ 
  ITStatus bitstatus = RESET;  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_GET_FLAG(TIM_FLAG));

  
  if ((TIMx->SR & TIM_FLAG) != (uint16_t)RESET)
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}
```

* 获取中断状态

```c
//获取当前中断发生状态
ITStatus TIM_GetITStatus(TIM_TypeDef* TIMx, uint16_t TIM_IT)
{
  ITStatus bitstatus = RESET;  
  uint16_t itstatus = 0x0, itenable = 0x0;
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_GET_IT(TIM_IT));
   
  itstatus = TIMx->SR & TIM_IT;
  
  itenable = TIMx->DIER & TIM_IT;
  if ((itstatus != (uint16_t)RESET) && (itenable != (uint16_t)RESET))
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}
```

* 清空标志位/挂起标志位

```c
//清空中断标志位
void TIM_ClearFlag(TIM_TypeDef* TIMx, uint16_t TIM_FLAG)
{  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
   
  /* Clear the flags */
  TIMx->SR = (uint16_t)~TIM_FLAG;
}

//清空中断挂起标志位
void TIM_ClearITPendingBit(TIM_TypeDef* TIMx, uint16_t TIM_IT)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Clear the IT pending Bit */
  TIMx->SR = (uint16_t)~TIM_IT;
}
```

* 使能/失能DMA请求

```c
//使能定时器DMA
void TIM_DMACmd(TIM_TypeDef* TIMx, uint16_t TIM_DMASource, FunctionalState NewState)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_LIST5_PERIPH(TIMx)); 
  assert_param(IS_TIM_DMA_SOURCE(TIM_DMASource));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the DMA sources */
    TIMx->DIER |= TIM_DMASource; 
  }
  else
  {
    /* Disable the DMA sources */
    TIMx->DIER &= (uint16_t)~TIM_DMASource;
  }
}
```

* 配置DMA突发传输模式（burst mode）

```c
//配置定时器DMA突发传输模式与相关设置
void TIM_DMAConfig(TIM_TypeDef* TIMx, uint16_t TIM_DMABase, uint16_t TIM_DMABurstLength)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_DMA_BASE(TIM_DMABase)); 
  assert_param(IS_TIM_DMA_LENGTH(TIM_DMABurstLength));

  /* Set the DMA Base and the DMA Burst Length */
  TIMx->DCR = TIM_DMABase | TIM_DMABurstLength;
}
```

* 选择捕获比较DMA请求

```c
//选择捕获比较DMA请求使能
void TIM_SelectCCDMA(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the CCDS Bit */
    TIMx->CR2 |= TIM_CR2_CCDS;
  }
  else
  {
    /* Reset the CCDS Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCDS;
  }
}
```

### 定时器时钟管理

这里是关于定时器时钟源的管理库函数

* 选择内部/外部时钟输入

```c
//配置定时器内部时钟
void TIM_InternalClockConfig(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Disable slave mode to clock the prescaler directly with the internal clock */
  TIMx->SMCR &=  (uint16_t)~TIM_SMCR_SMS;
}

//配置定时器内部触发作为外部时钟
//可选择TIM_TS_ITR0到3作为内部触发源
void TIM_ITRxExternalClockConfig(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_INTERNAL_TRIGGER_SELECTION(TIM_InputTriggerSource));

  /* Select the Internal Trigger */
  TIM_SelectInputTrigger(TIMx, TIM_InputTriggerSource);

  /* Select the External clock mode1 */
  TIMx->SMCR |= TIM_SlaveMode_External1;
}

//配置定时器触发器作为外部时钟源
void TIM_TIxExternalClockConfig(TIM_TypeDef* TIMx, uint16_t TIM_TIxExternalCLKSource,
                                uint16_t TIM_ICPolarity, uint16_t ICFilter)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_POLARITY(TIM_ICPolarity));
  assert_param(IS_TIM_IC_FILTER(ICFilter));

  /* Configure the Timer Input Clock Source */
  if (TIM_TIxExternalCLKSource == TIM_TIxExternalCLK1Source_TI2)
  {
    TI2_Config(TIMx, TIM_ICPolarity, TIM_ICSelection_DirectTI, ICFilter);
  }
  else
  {
    TI1_Config(TIMx, TIM_ICPolarity, TIM_ICSelection_DirectTI, ICFilter);
  }
  /* Select the Trigger source */
  TIM_SelectInputTrigger(TIMx, TIM_TIxExternalCLKSource);
  /* Select the External clock mode1 */
  TIMx->SMCR |= TIM_SlaveMode_External1;
}
```

* 选择外部时钟模式为ETR（模式1/模式2）、TIx或ITRx

```c
//配置定时器ETR模式1
void TIM_ETRClockMode1Config(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler,
                            uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));
  /* Configure the ETR Clock source */
  TIM_ETRConfig(TIMx, TIM_ExtTRGPrescaler, TIM_ExtTRGPolarity, ExtTRGFilter);
  
  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Reset the SMS Bits */
  tmpsmcr &= (uint16_t)~TIM_SMCR_SMS;

  /* Select the External clock mode1 */
  tmpsmcr |= TIM_SlaveMode_External1;

  /* Select the Trigger selection : ETRF */
  tmpsmcr &= (uint16_t)~TIM_SMCR_TS;
  tmpsmcr |= TIM_TS_ETRF;

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}

//配置ETR模式2
void TIM_ETRClockMode2Config(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler, 
                             uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));

  /* Configure the ETR Clock source */
  TIM_ETRConfig(TIMx, TIM_ExtTRGPrescaler, TIM_ExtTRGPolarity, ExtTRGFilter);

  /* Enable the External clock mode2 */
  TIMx->SMCR |= TIM_SMCR_ECE;
}
```

### 定时器同步管理

STM32中部分定时器可以实现同步功能，这里是相关的同步管理库函数

基本配置方法如下所示：

> 两个/多个定时器可进行串连、同步、交错等多种配置，需要以下步骤：
>
> 1. 使用下面的两个函数配置主定时器：
>    * TIM_SelectOutputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_TRGOSource)选择输出触发源
>    * TIM_SelectMasterSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_MasterSlaveMode)选择当前定时器模式为主从模式
> 2. 使用下面的函数配置从定时器：
>    * TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)选择触发源输入
>    * TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)选择当前定时器模式为从模式
> 3. 这样从定时器就会被连接到主定时器的触发器，接收主定时器控制
> 4. 使用TIM_ETRConfig(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler, uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)函数配置定时器的外部触发源，可实现由外部信号控制定时器
> 5. 配合TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)与TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)函数，可以让定时器接收外部信号并作为从模式工作

* 选择输入触发信号

```c
void TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_TRIGGER_SELECTION(TIM_InputTriggerSource));

  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Reset the TS Bits */
  tmpsmcr &= (uint16_t)~TIM_SMCR_TS;

  /* Set the Input Trigger source */
  tmpsmcr |= TIM_InputTriggerSource;

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}
```

* 选择输出触发信号

```c
void TIM_SelectOutputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_TRGOSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST5_PERIPH(TIMx));
  assert_param(IS_TIM_TRGO_SOURCE(TIM_TRGOSource));

  /* Reset the MMS Bits */
  TIMx->CR2 &= (uint16_t)~TIM_CR2_MMS;
  /* Select the TRGO source */
  TIMx->CR2 |=  TIM_TRGOSource;
}
```

* 选择主从模式

```c
//设置定时器为从模式
void TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_SLAVE_MODE(TIM_SlaveMode));

  /* Reset the SMS Bits */
  TIMx->SMCR &= (uint16_t)~TIM_SMCR_SMS;

  /* Select the Slave Mode */
  TIMx->SMCR |= TIM_SlaveMode;
}

//设置定时器为主/从模式
void TIM_SelectMasterSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_MasterSlaveMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_MSM_STATE(TIM_MasterSlaveMode));

  /* Reset the MSM Bit */
  TIMx->SMCR &= (uint16_t)~TIM_SMCR_MSM;
  
  /* Set or Reset the MSM Bit */
  TIMx->SMCR |= TIM_MasterSlaveMode;
}
```

* 当作为外部触发使用时进行ETR配置

```c
//设置定时器外部触发模式（ETR）
void TIM_ETRConfig(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler,
                   uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));

  tmpsmcr = TIMx->SMCR;

  /* Reset the ETR Bits */
  tmpsmcr &= SMCR_ETR_MASK;

  /* Set the Prescaler, the Filter value and the Polarity */
  tmpsmcr |= (uint16_t)(TIM_ExtTRGPrescaler | (uint16_t)(TIM_ExtTRGPolarity | (uint16_t)(ExtTRGFilter << (uint16_t)8)));

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}
```

### 定时器特殊结构管理

定时器也可以作为特殊设备的接口使用，ST也提供了这样用法的库函数

* 解码器接口配置

```c
void TIM_EncoderInterfaceConfig(TIM_TypeDef* TIMx, uint16_t TIM_EncoderMode,
                                uint16_t TIM_IC1Polarity, uint16_t TIM_IC2Polarity)
{
  uint16_t tmpsmcr = 0;
  uint16_t tmpccmr1 = 0;
  uint16_t tmpccer = 0;
    
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_ENCODER_MODE(TIM_EncoderMode));
  assert_param(IS_TIM_IC_POLARITY(TIM_IC1Polarity));
  assert_param(IS_TIM_IC_POLARITY(TIM_IC2Polarity));

  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Get the TIMx CCMR1 register value */
  tmpccmr1 = TIMx->CCMR1;

  /* Get the TIMx CCER register value */
  tmpccer = TIMx->CCER;

  /* Set the encoder Mode */
  tmpsmcr &= (uint16_t)~TIM_SMCR_SMS;
  tmpsmcr |= TIM_EncoderMode;

  /* Select the Capture Compare 1 and the Capture Compare 2 as input */
  tmpccmr1 &= ((uint16_t)~TIM_CCMR1_CC1S) & ((uint16_t)~TIM_CCMR1_CC2S);
  tmpccmr1 |= TIM_CCMR1_CC1S_0 | TIM_CCMR1_CC2S_0;

  /* Set the TI1 and the TI2 Polarities */
  tmpccer &= ((uint16_t)~TIM_CCER_CC1P) & ((uint16_t)~TIM_CCER_CC2P);
  tmpccer |= (uint16_t)(TIM_IC1Polarity | (uint16_t)(TIM_IC2Polarity << (uint16_t)4));

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;

  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmr1;

  /* Write to TIMx CCER */
  TIMx->CCER = tmpccer;
}
```

* 选择Hall Sensor

```c
void TIM_SelectHallSensor(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the TI1S Bit */
    TIMx->CR2 |= TIM_CR2_TI1S;
  }
  else
  {
    /* Reset the TI1S Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_TI1S;
  }
}
```

### 定时器特殊重映射配置

一些定时器能够被重映射为特殊的配置端口，这里是该功能的管理库函数

```c
//配置定时器重映射端口
void TIM_RemapConfig(TIM_TypeDef* TIMx, uint16_t TIM_Remap)
{
 /* Check the parameters */
  assert_param(IS_TIM_LIST6_PERIPH(TIMx));
  assert_param(IS_TIM_REMAP(TIM_Remap));

  /* Set the Timer remapping configuration */
  TIMx->OR =  TIM_Remap;
}

//配置TI1、2、3、4作为输入，这里仅列出TI1的库函数
static void TI1_Config(TIM_TypeDef* TIMx, uint16_t TIM_ICPolarity, uint16_t TIM_ICSelection,
                       uint16_t TIM_ICFilter)
{
  uint16_t tmpccmr1 = 0, tmpccer = 0;

  /* Disable the Channel 1: Reset the CC1E Bit */
  TIMx->CCER &= (uint16_t)~TIM_CCER_CC1E;
  tmpccmr1 = TIMx->CCMR1;
  tmpccer = TIMx->CCER;

  /* Select the Input and set the filter */
  tmpccmr1 &= ((uint16_t)~TIM_CCMR1_CC1S) & ((uint16_t)~TIM_CCMR1_IC1F);
  tmpccmr1 |= (uint16_t)(TIM_ICSelection | (uint16_t)(TIM_ICFilter << (uint16_t)4));

  /* Select the Polarity and set the CC1E Bit */
  tmpccer &= (uint16_t)~(TIM_CCER_CC1P | TIM_CCER_CC1NP);
  tmpccer |= (uint16_t)(TIM_ICPolarity | (uint16_t)TIM_CCER_CC1E);

  /* Write to TIMx CCMR1 and CCER registers */
  TIMx->CCMR1 = tmpccmr1;
  TIMx->CCER = tmpccer;
}
```