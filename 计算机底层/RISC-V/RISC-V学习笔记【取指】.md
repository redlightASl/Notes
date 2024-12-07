# 处理器取指

**每条指令在存储器空间中所处的地址称为它的指令PC**，**取址**指处理器核将指令（按照其指令PC值对应的存储器地址）从存储器中读取出来的过程

取址的目标如下：

* 快速取址
* 连续取址

可能面对的问题如下：

* 指令的编码宽度不相等，导致PC地址与地址边界无法对齐
* 分支跳转指令执行后，可能导致跳转到另一个不连续的PC处，取址时需要从新的PC值对应的存储器地址读出指令
* 处理器会按顺序执行非分支跳转指令，需要按顺序从存储器中读取指令

传统RISC架构处理器的解决方案

* 连续不断地从存储器中顺序读取出非分支跳转指令，即使是地址不对齐的32位指令，也应该能每个周期读出一条完整指令
* 能够快速判断在分支跳转指令中是否跳转，如果需要跳转，则从新的PC地址处快速取出指令，力求每个周期读出一条完整指令

下面以传统RISC架构处理器介绍取址步骤

## 对于取指速度的优化

优化取指速度需要保证存储器的读延迟越小越好，但常见的存储器会存在不同程度的延迟

为了让处理器核能以最快速度取址，常使用以下两种方法取址

1. **ITCM**（Instruction Tightly Coupled Memory）指令紧耦合寄存器

   **配置一段较小容量的存储器（通常为几十KB，使用SRAM），用于存储指令**

   物理上需要离核心很近且专属于处理器核来**取地很小的访问延迟**（一般为一个时钟周期）

   优点：1. 实现非常简单；2. 能保证实时性

   缺点：1. 使用地址区间寻址，无法像缓存一样映射无限大的存储器空间；2. 容量受限

2. **I-Cache**（Instruction Cache）指令缓存

   **利用软件程序的时间局限性和空间局部性，将外部指令存储器空间动态映射到容量有限的指令缓存中，将访问指令存储器的平均延迟降低到最小**

   优点：1. 延迟确定，可以用于实时性要求较高的应用场景；2. 结构、实现复杂

   缺点：1. 缓存容量有限，访问缓存不确定性较大，可能造成缓存不命中；2. 无法保证处理器反应速度的实时性

## 对于非对齐指令取指的优化

处理器取指的一个目标是连续不断，争取每个时钟周期都能取出一条指令，源源不断地为后续执行提供指令流，不出现空闲的时钟周期

一般上述两种优化取指速度的方法都会使用SRAM，他的读端口宽度固定，n位的SRAM在一个时钟周期只能读出一个n位的数据，但如果一条n位的指令被存储于地址不对齐的位置，则意味着需要分2个时钟周期才能读出一条指令，一般使用以下方法来处理非对齐指令

### 普通指令

使用**剩余缓存**保存上次取指后没有用完的比特位，供下次使用

例如：从ITCM中取出一个32位的指令字，但只用到了它的低16位，则

1. 只需要使用此次取出的32位中低16位指令和之前取出32位中高16位指令组成一个32位指令，再进行执行
2. 指令长度本身就是16位，将其暂存在剩余缓存中，等待下一个周期取出下一个32位指令字后再拼接出完整指令执行

### 分支跳转指令

如果分支跳转指令的目标地址与32位地址边界不对齐，且需要取出一个32位的指令字，则剩余缓存的解决方案失效！

这种情况下常**使用多体化的SRAM进行指令存储**

常见的形式为**奇偶交替**：使用两块32位宽的SRAM交错地进行存储，将两个32位指令字分别存储在两块不同的SRAM中，这样就可以在一个时钟周期内访问两块SRAM并取出两个连续的32位关键字，然后拼接形成真正的32位指令

## 分支指令处理

### 分支指令类型

1. 无条件跳转/分支指令

   无需判断条件就一定会发生跳转的指令

   还存在以下分类

   1. 无条件直接跳转/分支

      使用立即数计算得到跳转地址的指令

      RISC-V中的JAL指令就是无条件直接跳转指令，该指令使用编码在指令字中的20位立即数作为偏移量，将其乘2后与当前指令所在地址相加就得到了最终的跳转目标地址

   2. 无条件间接跳转/分支

      使用寄存器索引的操作数计算得到跳转地址的指令

      RISC-V中的JALR指令就是无条件间接跳转指令，该指令使用编码在指令字中的12位立即数作为偏移量，与基地址寄存器（其中索引的操作数）相加得到最终的跳转目标地址

2. 带条件跳转/分支指令

   判断条件决定是否跳转的指令

   存在以下分类

   1. 带条件直接跳转/分支

      使用立即数计算得到跳转地址的指令

   2. 带条件间接跳转/分支

      用寄存器索引的操作数计算得到跳转地址的指令

   上面两个类型和无条件跳转/分支指令类似，但是都多出判断条件的这一部分。RISC-V架构中没有带条件间接跳转指令

   **理论上指令只有在执行阶段完成后才能解析出最终的跳转结果**，如果在取指期间暂停，直到执行阶段完成才继续取指，会浪费大量时钟周期，造成流水线断流。所以处理器会采用**分支预测**技术，会预测跳转的方向和跳转的目标地址

### 分支预测

   1. 静态分支预测

不依赖任何执行过的指令信息和历史信息，凭借当前分支指令本身的信息进行预测

**最简分支预测**：总是预测分支指令不会发生跳转，如果执行阶段发现需要跳转，则冲刷流水线重新取指，会造成两个时钟周期的流水线延迟

**分支延迟槽**：每一条分支指令后面紧跟的一条或若干条指令不受分支跳转的影响，不管分支是否跳转，后面的指令都一定会被执行。分支延迟槽中的指令永远被执行而不用被丢弃重取，它不会受到冲刷流水线的影响

**BTFN预测**（Back Taken，Forward Not Taken）：对向后跳转预测为跳，向前跳转预测为不跳，比较常见

   2. 动态分支预测

依赖已经执行过的历史信息和分支指令本身的信息综合进行*方向*预测

**一比特饱和计数器**：最简单的动态预测器，每次分支指令执行后就会使用此计数器记录上次的方向，采用*下一次分支指令永远采用上次记录的方向*作为本次的预测

**两比特饱和计数器**：最常见的动态预测器，采用FSM的方式进行预测。

当前状态=强不需要跳转 或 弱不需要跳转，则预测该指令方向为 不需要跳转

当前状态=弱需要跳转 或 强需要跳转，则预测该指令方向为 需要跳转

如果预测出错，则反向更改当前状态：从 强需要跳转 要出错连续2次才能变为变为 弱不需要跳转，因此具有一定的切换缓冲，其在复杂程序流中预测精度一般比简单的一比特饱和计数器更高

但是使用该方案可能会导致**别名重合**：使用多个两比特饱和计数器负责不同分支指令的预测，会导致大量空间占用，所以只能采用有限个计数器组成计数器表格，但表项数目有限但指令众多，所以很多不同的分支会不可避免地指向相同的表项

解决这个问题一般采用**动态分支预测算法**：采用不同的表格组织方式（控制表格大小）和索引方式（控制别名重合问题）来提高预测精准率，常见算法如下：

1) 一级预测器

将有限个两比特饱和计数器组织成**一维表格**，称为**预测器表格**。直接使用PC值的一部分进行索引

“一级预测器”指的是其索引仅仅采用指令本身的PC值

优点：简单易行

缺点：索引机制过于简单导致预测精度不高

2) 两级预测器

又称为**相关预测器**

对于每条分支，将有限个两比特饱和计数器组织成PHT（Pattern History Table），使用该分支跳转的历史作为PHT的索引

只需要n个bit就能索引2^n^个表项

分支历史又可以分为局部历史（每个分支指令自己的跳转历史）和全局历史（所有分支指令的跳转历史）

**局部分支预测器**采用分立的局部历史缓存，每个缓存有自己对应的PHT，对于每条分支指令，会先索引其对应的局部历史缓存，再使用局部历史缓存中的历史值所引导对应的PHT

**全局分支预测器**使用所有分支指令共享的全局历史缓存。这个解决方案节省资源但只有在PHT容量非常大时才能体现出其优势，且PHT容量越大，优势越明显

常见的全局预测算法有：

* Gshare算法：将分支指令PC值的一部分和共享的全局历史缓存进行**异或**，使用运算的结果作为PHT的索引
* Gselect算法：将分支指令PC值的一部分和共享的全局历史缓存进行**拼接**，使用运算的结果作为PHT的索引

3. 预测地址

分支目标地址需要在**执行阶段计算后才能得到分支的目标地址**，这些任务无法在一个周期内完成，在连续取下一条指令前，甚至连译码判断当前指令是否属于分支指令都无法及时地在一个周期内完成，因此为了连续不断地取指，需要预测分支的目标地址，常见技术如下

1) BTB（Branch Target Buffer分支目标缓存）：使用容量有限的**缓存**保存最近执行过的分支指令的PC值及它们的跳转目标地址。对于后续需要取指的每条PC值，将其与BTB中存储的各个PC值进行比较，如果出现匹配则预测这是一条分支指令，使用其对应存储的跳转目标地址作为预测的跳转地址

优点：最简单快捷

缺点：1. BTB容量与时序、面积难以平衡；2. 对于间接跳转/分支指令的预测效果并不理想

2) RAS（Return Address Stack返回堆栈地址）：使用容量有限的**硬件堆栈**（FIFO）来存储函数调用的返回地址

间接分支/跳转指令多用于函数调用/返回，这两者成对出现，因此可以在函数调用时PC+=4或2，将其顺序执行的下一条指令的PC值压入RAS堆栈，等到函数返回时将其弹出，只要程序正常执行，RAS就能提供较高的预测准确率。不过由于RAS深度有限，出现多次函数嵌套则可能堆栈溢出，影响准确率

优点：正常情况下准确率高

缺点：出现函数嵌套时难以处理

3) Indirect BTB（间接BTB）：专门为间接分支/跳转指令设计的BTB，它通过高级的索引方法进行匹配，结合BTB和动态两级预测器的技术

优点：预测成功率很高

缺点：硬件开销非常大

4. 其它扩展技术

# RISC-V架构对取指硬件的简化

## 规整的指令编码格式

RISC-V指令集编码十分规整，可以快速译码得到指令类型及其使用的操作数寄存器索引或立即数

## 指令长度指示码放在低位

RISC-V提供可选的压缩指令子集C，如果支持此子集就会有32位和16位指令混合交织在一起的情形

所有RISC-V指令编码的最低几位专门用于编码表示指令的长度，**将指令长度指示码放在指令的最低位**，方便取指逻辑在顺序取指的过程中以最快速度译码出指令的长度，化简硬件设计。取指逻辑在仅取到16位指令字时就可以进行译码判断当前指令长度而无需等待另外一半16位指令字的取指

此外，由于16位的压缩指令子集是可选的，假设处理器不支持此压缩指令子集而仅支持32位指令，甚至可以将指令字的低2位忽略不存储（因为其肯定固定为11），从而节省I-Cache的开销

换句话说，RISC-V的变长指令集为译码提供方便

## 简单的分支跳转指令

RISC-V架构中存在2条无条件跳转指令JAL和JALR；存在6条带条件分支指令BEQ、BNE、BLT、BLTU、BGE、BGEU，这些指令和普通运算指令一样，直接使用两个整数操作数，然后对其进行比较，如果比较的条件满足时则会跳转。

这些指令使用12位有符号数作为偏移量，有如下计算公式：

$偏移量*2+当前指令所在地址=目标地址$

16位的压缩指令子集中指令能够一一对应32位的标准指令

## 没有分支延迟槽

RISC-V砍掉了分支延迟槽，节省了这一器件的面积

## 提供明确的静态分支预测依据和RAS依据

RISC-V架构中明确规定编译器生成的代码应该尽量优化，使向后跳转的分支指令比向前跳转的分支指令有更大概率进行跳转，因此硬件层面可以更好地和软件匹配，最大化提高静态预测的准确率

并且规定

`如果使用JAL指令且目标寄存器索引值rd=x1或rd=x5，则属于需要进行RAS压栈；如果使用JALR指令，则按照使用的寄存器值（rs1和rd）的不同，明确规定相应的RAS压栈/出栈行为，软件编译器必须按照此原则生成汇编代码`

# 蜂鸟E200处理器的取指实现

E200系列处理器核的取指子系统由*ITCM*、*BIU*和*核心内部取指令单元IFU*完成

## IFU设计思路

功能如下：

1. 对取回的地址进行简单译码（Mini-Decode）
2. 简单的分支预测（Simple-BPU）
3. 生成取指的PC
4. 根据PC地址访问ITCM或BIU

为了进行快速、连续不断的取址，做了以下优化：

1. 假定绝大多数取指发生在ITCM中，主要使用ITCM进行指令的存储以满足实时性的要求

2. ITCM使用单周期访问的SRAM

3. 对于从外部存储器中读取指令的特殊情况，IFU可以通过BIU使用系统存储接口访问外部存储器

   这种情况下无法做到单周期访问，但这种情况很少，所以不做优化

4. 要求软件应当==利用绝大多数取指发生在ITCM中的假定进行设计==

5. IFU直接将取回的指令在同一个周期内进行部分译码，如果显示当前指令为分支跳转指令，则IFU直接在同一个周期内进行分支预测

   这个优化涉及Mini-Decode和Simple-BPU两个模块，会在后面详细介绍

6. 由于同一个周期内完成ITCM内取址、部分译码、分支预测、生成下一条待取指令的PC等操作，处理器主频会受到一定影响

7. 采用最简单的静态预测机制

8. 对向后跳转的条件分支指令预测为真的跳转，向前的指令则不跳转

### Mini-Decode模块

**源码保存在/rtl/e203/core/e203_ifu_minidec.v文件**

此处的译码不会完整译出指令的所以信息，只需要译出IFU所需的部分指令信息，包括此指令是属于普通指令还是分支跳转指令、分支跳转指令的类型和细节

模块内部*例化调用*一个**完整的decode模块**，但是**将其不相关的输入信号接零、输出信号悬空**，从而让综合工具能将完整模块中的无关逻辑优化掉，这就是Mini-Decode。这样可以避免同时维护两份Decode模块导致出错

源码如下：

```verilog
module e203_ifu_minidec(
  //////////////////////////////////////////////////////////////
  // The IR stage to Decoder
    input  [`E203_INSTR_SIZE-1:0] instr,//取回的指令输入该模块进行部分译码
  //////////////////////////////////////////////////////////////
  // The Decoded Info-Bus
  output dec_rs1en,
  output dec_rs2en,
  output [`E203_RFIDX_WIDTH-1:0] dec_rs1idx,
  output [`E203_RFIDX_WIDTH-1:0] dec_rs2idx,

  output dec_mulhsu,
  output dec_mul   ,
  output dec_div   ,
  output dec_rem   ,
  output dec_divu  ,
  output dec_remu  ,

  output dec_rv32,//指示16/32位指令长度
  output dec_bjp,//指示普通/分支跳转指令
  output dec_jal,//属于JAL指令？
  output dec_jalr,//属于JALR指令？
  output dec_bxx,//属于Bxx带条件分支指令？
    
  output [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,
  output [`E203_XLEN-1:0] dec_bjp_imm 
  );

  //例化调用完整的Decode模块
  e203_exu_decode u_e203_exu_decode(

  .i_instr(instr),
      
  .i_pc(`E203_PC_SIZE'b0),//不相关输入信号接0
  .i_prdt_taken(1'b0), 
  .i_muldiv_b2b(1'b0), 
  .i_misalgn (1'b0),
  .i_buserr  (1'b0),
  .dbg_mode  (1'b0),

  .dec_misalgn(),//不相关输出信号悬空
  .dec_buserr(),
  .dec_ilegl(),
  .dec_rs1x0(),
  .dec_rs2x0(),
  .dec_rs1en(dec_rs1en),
  .dec_rs2en(dec_rs2en),
  .dec_rdwen(),
  .dec_rs1idx(dec_rs1idx),
  .dec_rs2idx(dec_rs2idx),
  .dec_rdidx(),
  .dec_info(),  
  .dec_imm(),
  .dec_pc(),
  
  .dec_mulhsu(dec_mulhsu),//其他信号正常连接
  .dec_mul   (dec_mul   ),
  .dec_div   (dec_div   ),
  .dec_rem   (dec_rem   ),
  .dec_divu  (dec_divu  ),
  .dec_remu  (dec_remu  ),

  .dec_rv32(dec_rv32),
  .dec_bjp (dec_bjp ),
  .dec_jal (dec_jal ),
  .dec_jalr(dec_jalr),
  .dec_bxx (dec_bxx ),

  .dec_jalr_rs1idx(dec_jalr_rs1idx),
  .dec_bjp_imm    (dec_bjp_imm    )  
  );
endmodule
```

### Simple-BPU机制

用于进行简单的分支预测，源码位于/rtl/e203/core/e203_ifu_litebpu.v

总体上分成三个部分：

* JAL：直接跳
* Bxx：后跳前不跳
* JALR：使用rs1索引的操作数作为基地址，根据操作数的不同再分成三个小部分
  * x0：直接使用x0+偏移地址立即跳转
  * x1：不需占用寄存器读端口，直接获取寄存器中的值，进行RAW相关性判断
  * xn：需占用寄存器读端口，先判断读端口空闲，再进行RAW相关性判断

所有的PC共享同一个加法器，在这一阶段生成加法器的两个操作数，不管前面的分支如何，总是使用立即数表示的偏移量作为一个操作数；使用三种情况下从regfile或其本身PC读出的操作值作为另一个操作数

源码如下：

```verilog
module e203_ifu_litebpu(
  //当前PC
  input  [`E203_PC_SIZE-1:0] pc,

  //mini-decoded得出信息 
  input  dec_jal,
  input  dec_jalr,
  input  dec_bxx,
  input  [`E203_XLEN-1:0] dec_bjp_imm,
  input  [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,

  //IR索引和用于检查相关性的OITF状态
  input  oitf_empty,
  input  ir_empty,
  input  ir_rs1en,
  input  jalr_rs1idx_cam_irrdidx,
  
  //送到加法器的操作数1和2
  output bpu_wait,  
  output prdt_taken,  
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,  
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,

  input  dec_i_valid,

  //读寄存器的rs1
  output bpu2rf_rs1_ena,
  input  ir_valid_clr,
  input  [`E203_XLEN-1:0] rf2bpu_x1,
  input  [`E203_XLEN-1:0] rf2bpu_rs1,

  input  clk,
  input  rst_n
  );

  //   简单的分支预测指令
  //   所有指令共享同一个加法器
  //   * Bxxx:总是向后跳转，向前不跳转。基于当前PC地址和偏移量计算出目标地址
  //   * JAL: JAL将无需预测，直接跳转
  //   * JALR跳转目标计算所需的基地址来自其rs1索引的操作数，需要从通用寄存器组中读取，e203根据rs1的索引值不同采取不同方案
  //     	JALR的rs1 == x0 :直接使用常数0+偏移地址，无条件跳转
  //    	JALR的rs1 == x1 :进行特别加速，将x1从处于EXU的寄存器组中直接拉线取出（不需要占用寄存器组的读端口）
  //          需要判定当前的EXU指令没有写回x1且EXU中的OITF必须为空，防止出现RAW相关性
  //     	JALR的rs1 != x0 或 x1 :目标地址在执行阶段译码，这里将rs1 != x0或x1的情况统称为rs1=xn
  //		  需要使用Regfile的第一个读端口（Read Port 1）从Regfile中读取出xn，在使用前一定要判断第一个读端口是否空闲	 //			 且不存在资源冲突。为了防止正在处于EXU中执行的指令需要写回xn造成RAW数据相关性，还要Simple-BPU判定当前EXU中   //		   没有任何指令

  // 处理Bxx的跳转
  // 如果立即数表示的偏移量为负数（最高位为1），意味着向后跳转，预测为需要跳转；否则不跳转
  assign prdt_taken   = (dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN-1]));

  // 处理JARL的跳转索引号
  // 在JARL的rs1值为x1或xn时可能存在相关性
  wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd0);//判定索引号是x0
  wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd1);//判定索引号是x1
  wire dec_jalr_rs1xn = (~dec_jalr_rs1x0) & (~dec_jalr_rs1x1);//判断索引号是其他寄存器xn

  //处理JALR的跳转
  //判断JALR的rs1索引号是x1的情况下是否存在RAW数据相关性
  wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & ((~oitf_empty) | 																							(jalr_rs1idx_cam_irrdidx));
  //判断JALR的rs1索引号是xn的情况下是否存在RAW数据相关性
  //OITF不为空或IR寄存器中存在指令的情况下可能出现RAW相关性
  //如果OITF非空，则可能有长指令正在执行，其结果可能会写回x1；如果IR寄存器中的指令的写回目标寄存器的索引号为x1，意味着一定存在RAW相关性
  wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~oitf_empty) | (~ir_empty));

  //如果只依赖IR阶段(OITF非空)那么当IR处于清空中或他没有使用rx1索引，那么也可以判断不存在相关性
  //OITF非空，意味着可能有长指令正在执行，其结果可能会写回xn；如果IR寄存器中存在指令，意味着可能写回xn，这里采用保守估计
  wire jalr_rs1xn_dep_ir_clr = (jalr_rs1xn_dep & oitf_empty & (~ir_empty))&(ir_valid_clr|(~ir_rs1en));

  //需要使用Regfile的第一个端口来读取xn的值，在此之前判断第一个读端口是否空闲且不存在资源冲突，如果没问题则将第一个读端口的使能置高
  wire rs1xn_rdrf_r;
  wire rs1xn_rdrf_set = (~rs1xn_rdrf_r) & dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~jalr_rs1xn_dep) | 																				jalr_rs1xn_dep_ir_clr);
  wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
  wire rs1xn_rdrf_ena = rs1xn_rdrf_set |   rs1xn_rdrf_clr;
  wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | (~rs1xn_rdrf_clr);
  sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena, rs1xn_rdrf_nxt, rs1xn_rdrf_r, clk, rst_n);

  //征用第一个读端口的使能信号，该信号将加载和IR寄存器位于同一级别的rs1索引寄存器从而读取Regfile
  assign bpu2rf_rs1_ena = rs1xn_rdrf_set;

  //如果存在x1或xn的RAW相关性，则将bpu_wait拉高，阻止IFU生成下一个PC，等待相关性解除
  //就性能而言，大多数情况下x1或xn依赖于EXU的ALU指令，需要等待1个周期ALU执行完毕写回Regfile后才会拉低bpu_wait进而取指，流水	 线中会出现一个周期的空泡性能损失；如果x1/xn和EXU中的指令没有数据相关性则不会造成性能损失
  assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;
 
  //为了节省面积，所有PC均共享同一个加法器
  //此处生成分支预测器进行PC计算所需的操作数，将他们送给共享的加法器进行计算  
    
  // 生成加法器的操作数1：如果是Bxx或JAL指令则使用它本身的PC；如果是JALR指令则分三种情况
  //						1. x0：使用常数0
  //						2. x1：使用从Regfile中硬连线出来的x1值
  //						3. xn：使用从Regfile第一个读端口读出的xn值
  assign prdt_pc_add_op1 = (dec_bxx | dec_jal) ? pc[`E203_PC_SIZE-1:0]
                         : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'b0
                         : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
                         : rf2bpu_rs1[`E203_PC_SIZE-1:0];  
  // 生成加法器的操作数2：使用立即数表示的偏移量
  assign prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];  
endmodule
```

### PC生成

PC生成逻辑模块用于产生下一个待取指令的PC

该模块源代码存放在/rtl/e203/core/e203_ifu_ifetch.v文件

蜂鸟e200将PC生成分为了四种情况

1. 复位后第一次取指

   默认使用CPU-TOP顶层输入信号`pc_rtvec`指示的值作为第一次取指的PC值

   通过在SoC顶层集成时将此信号赋不同值来控制PC的复位默认值

2. 顺序取指

   根据当前指令是16位还是32位来判断自增值

   16位：PC=PC+2

   32位：PC=PC+4

3. 分支指令取指

   使用Simple-BPU预测跳转的目标地址

4. 来自EXU的流水线冲刷

   使用EXU送来的新PC值

```verilog
// 控制PC自增
  wire [2:0] pc_incr_ofst = minidec_rv32 ? 3'd4 : 3'd2;

  wire [`E203_PC_SIZE-1:0] pc_nxt_pre;
  wire [`E203_PC_SIZE-1:0] pc_nxt;
// 控制跳转取PC
  wire bjp_req = minidec_bjp & prdt_taken;
 
// 所有PC计算共享同一个加法器来节省面积
// 选择加法器的输入
  wire ifetch_replay_req;
  wire [`E203_PC_SIZE-1:0] pc_add_op1 = 
                            `ifndef E203_TIMING_BOOST//}
                               pipe_flush_req  ? pipe_flush_add_op1 :
                               dly_pipe_flush_req  ? pc_r :
                            `endif//}
                               ifetch_replay_req  ? pc_r :
                               bjp_req ? prdt_pc_add_op1    :
                               ifu_reset_req   ? pc_rtvec :
                                                 pc_r;

  wire [`E203_PC_SIZE-1:0] pc_add_op2 =  
                            `ifndef E203_TIMING_BOOST//}
                               pipe_flush_req  ? pipe_flush_add_op2 :
                               dly_pipe_flush_req  ? `E203_PC_SIZE'b0 :
                            `endif//}
                               ifetch_replay_req  ? `E203_PC_SIZE'b0 :
                               bjp_req ? prdt_pc_add_op2    :
                               ifu_reset_req   ? `E203_PC_SIZE'b0 :
                                                 pc_incr_ofst ;

// 顺序取指的信号，在正常情况下顺序取指
  assign ifu_req_seq = (~pipe_flush_req_real) & (~ifu_reset_req) & (~ifetch_replay_req) & (~bjp_req);
  assign ifu_req_seq_rv32 = minidec_rv32;
  assign ifu_req_last_pc = pc_r;

// 加法器计算下一条待取指令的PC初步值
  assign pc_nxt_pre = pc_add_op1 + pc_add_op2;
  `ifndef E203_TIMING_BOOST//}
// 出现流水线冲刷的情况下废弃计算得到的新PC值，否则正常使用计算值
  assign pc_nxt = {pc_nxt_pre[`E203_PC_SIZE-1:1],1'b0};
  `else//}{
  assign pc_nxt = 
               pipe_flush_req ? {pipe_flush_pc[`E203_PC_SIZE-1:1],1'b0} :
               dly_pipe_flush_req ? {pc_r[`E203_PC_SIZE-1:1],1'b0} :
               {pc_nxt_pre[`E203_PC_SIZE-1:1],1'b0};
  `endif//}

......

// 产生下一条待取指令的PC值
  sirv_gnrl_dfflr #(`E203_PC_SIZE) pc_dfflr (pc_ena, pc_nxt, pc_r, clk, rst_n);
```

### 访问ITCM和BIU

蜂鸟E203支持16位压缩指令子集，在32位与16位指令交错的情况下，IFU使用位于/rtl/e203/core/e203_ifu_ift2icb.v的非对齐访问逻辑模块来进行处理

蜂鸟E200采用**剩余缓存**技术来处理非对齐指令取指

* IFU固定取指32位
* 如果访问ITCM，由于ITCM是由SRAM构成的，上次访问后的输出值将一直保存，这一过程称为**Hold-up**，利用这一特点省略一个64位寄存器的开销：ITCM的SRAM（64位）输出为一个与64位地址区间对齐的数据，这里称为**Lane**，由于CPU取指位宽32位，会连续两次或多次访问同一个Lane，这里第二次访问利用Hold-up特点，直接读取其保持不变的输出来避免重复打开SRAM
* 如果顺序取指时一个32位指令非对齐地跨越了64位边界，则会将SRAM当前输出的最高16位存入16位宽的剩余缓存，然后开始正常的拼接取指（参考之前所说*使用剩余缓存保存上次取指后没有用完的比特位供下次使用*）。因此可以只用一个周期的ITCM访问来取回32位指令
* 对于分支跳转指令或流水下冲刷情况下的取指，需要连续发起两次ITCM读操作，这种情况下的性能损失无可避免

```verilog
// 处理非对称取指情况使用FSM控制
  wire req_need_2uop_r;
  wire req_need_0uop_r;

  localparam ICB_STATE_WIDTH  = 2;
  // State 0: 空闲状态下没有特殊的取指请求
  localparam ICB_STATE_IDLE = 2'd0;
  // State 1: 等待响应状态（等待非对齐读取操作的第一次读取状态）
  localparam ICB_STATE_1ST  = 2'd1;
  // State 2: 第一次和第二次读取之间进行等待
  localparam ICB_STATE_WAIT2ND  = 2'd2;
  // State 3: 等待非对齐读取操作的第二次读取状态
  localparam ICB_STATE_2ND  = 2'd3;
  
  wire [ICB_STATE_WIDTH-1:0] icb_state_nxt;
  wire [ICB_STATE_WIDTH-1:0] icb_state_r;
  wire icb_state_ena;
  wire [ICB_STATE_WIDTH-1:0] state_idle_nxt   ;
  wire [ICB_STATE_WIDTH-1:0] state_1st_nxt    ;
  wire [ICB_STATE_WIDTH-1:0] state_wait2nd_nxt;
  wire [ICB_STATE_WIDTH-1:0] state_2nd_nxt    ;
  wire state_idle_exit_ena     ;
  wire state_1st_exit_ena      ;
  wire state_wait2nd_exit_ena  ;
  wire state_2nd_exit_ena      ;

  // 定义一些通用的变量，等待使用
  wire icb_sta_is_idle    = (icb_state_r == ICB_STATE_IDLE   );
  wire icb_sta_is_1st     = (icb_state_r == ICB_STATE_1ST    );
  wire icb_sta_is_wait2nd = (icb_state_r == ICB_STATE_WAIT2ND);
  wire icb_sta_is_2nd     = (icb_state_r == ICB_STATE_2ND    );

......

  // 状态当且仅当需要退出执行阶段时进行转换
  assign icb_state_ena = 
            state_idle_exit_ena | state_1st_exit_ena | state_wait2nd_exit_ena | state_2nd_exit_ena;

  // 选择不同数据线入口的多选器
  assign icb_state_nxt = 
              ({ICB_STATE_WIDTH{state_idle_exit_ena   }} & state_idle_nxt   )
            | ({ICB_STATE_WIDTH{state_1st_exit_ena    }} & state_1st_nxt    )
            | ({ICB_STATE_WIDTH{state_wait2nd_exit_ena}} & state_wait2nd_nxt)
            | ({ICB_STATE_WIDTH{state_2nd_exit_ena    }} & state_2nd_nxt    )
              ;
// 选取信号
  sirv_gnrl_dfflr #(ICB_STATE_WIDTH) icb_state_dfflr (icb_state_ena, icb_state_nxt, icb_state_r, clk, rst_n);

......

// 加载剩余缓存的使能信号
  assign leftover_ena = holdup2leftover_ena // 顺序取指跨界时加载当前ITCM输出的低16位
                      | uop1st2leftover_ena; // 非顺序取指跨界时发起两次读操作，第一次读操作后加载输出的高16位

  assign leftover_nxt = 
                      //  ({16{holdup2leftover_sel}} & holdup2leftover_data[15:0]) 
                      //| ({16{uop1st2leftover_sel}} & uop1st2leftover_data[15:0]) 
                        put2leftover_data[15:0] 
                      ;

  assign leftover_err_nxt = 
                        (holdup2leftover_sel & 1'b0)
                      | (uop1st2leftover_sel & uop1st2leftover_err) 
                      ;
// 实现剩余缓存的寄存器
  sirv_gnrl_dffl #(16) leftover_dffl     (leftover_ena, leftover_nxt,     leftover_r,     clk);
  sirv_gnrl_dfflr #(1) leftover_err_dfflr(leftover_ena, leftover_err_nxt, leftover_err_r, clk, rst_n);
```

蜂鸟e203的取指单元IFU、指令紧耦合寄存器ITCM、总线接口单元BIU分开实现，IFU使用ICB协议，相关协议接口存放在/rtl/e203/core/e203_ifu_ift2icb.v

基本上，**IFU有两个ICB接口，一个64位的用于访问ITCM，一个32位的用于访问BIU**

CPU会根据IFU访问的地址区间进行判断是要用ITCM-ICB还是BIU-ICB进行访问

比较判断的代码片段如下

```verilog
// 使用比较逻辑判断高位基地址与ITCM基地址是否相等，如果相等则进行访问
assign ifu_icb_cmd2itcm = (ifu_icb_cmd_addr[`E203_ITCM_BASE_REGION] == itcm_region_indic[`E203_ITCM_BASE_REGION]);

assign ifu2itcm_icb_cmd_valid = ifu_icb_cmd_valid & ifu_icb_cmd2itcm; // 允许访问ITCM
assign ifu2itcm_icb_cmd_addr = ifu_icb_cmd_addr[`E203_ITCM_ADDR_WIDTH-1:0];

assign ifu2itcm_icb_rsp_ready = ifu_icb_rsp_ready; // 准备信号

// 判断如果没有落在ITCM区域则访问BIU
assign ifu_icb_cmd2biu = 1'b1
            `ifdef E203_HAS_ITCM //{
              & ~(ifu_icb_cmd2itcm)
            `endif//}
              ;

wire ifu2biu_icb_cmd_valid_pre  = ifu_icb_cmd_valid & ifu_icb_cmd2biu;// 允许访问BIU
wire [`E203_ADDR_SIZE-1:0]   ifu2biu_icb_cmd_addr_pre = ifu_icb_cmd_addr[`E203_ADDR_SIZE-1:0];

assign ifu2biu_icb_rsp_ready = ifu_icb_rsp_ready; // 准备信号
```

#### ITCM的特殊点

E200采用数据宽度64位的单口SRAM组成，其大小和基地址可以通过`config.v`中的宏定义参数配置

64位的SRAM在物理大小上比32位的SRAM面积更紧凑，且同一时钟频率下可减少动态功耗