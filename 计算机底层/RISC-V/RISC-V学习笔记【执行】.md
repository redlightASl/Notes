# 蜂鸟E200的EXU单元

蜂鸟E200系列CPU是两级流水线架构，**其译码、执行、交付、写回功能全部处于流水线的第二级**

这些功能使用执行单元EXU完成，EXU功能如下

* 将IFU通过IR寄存器发送给EXU的指令进行译码与派遣（会在下面介绍）
* 通过译码得出的操作数寄存器索引读取寄存器组
* 维护指令的数据相关性
* 将指令派遣给不同的运算单元执行
* 交付指令
* 将指令的运算结果写回寄存器组

# 译码

经典五级流水线结构中，取指-译码-执行分为三个阶段进行，通过译码让CPU获取指令读取/写回的操作数寄存器索引、指令类型、指令操作信息等。目前高性能处理器普遍采用在每个运算单元前配置乱序发射队列的方式，将指令的相关性解除，从发射队列中发射出来时读取通用寄存器组，再送给运算单元进行计算

## 蜂鸟E203中的译码器

译码器模块保存在core目录下的e203_exu_decode.v文件

**完全由组合逻辑编写**

可以在某种程度上理解为一个超大型的case语句

```verilog
module e203_exu_decode(
    input  [`E203_INSTR_SIZE-1:0] i_instr,//来自IFU的32位指令
    input  [`E203_PC_SIZE-1:0] i_pc,//IFU当前指令对应的PC值
    ......
    input  i_misalgn,//取指非对齐异常标志
    input  i_buserr,//取指存储器访问错误标志位
  	
    ......//省略一堆译码得到的信息
    output dec_ilegl,//非法指令标志
	
	......
);
    
    //内容省略，总体上就是
    //1. 正常对32位和16位的指令进行译码
    //2. 根据后面所连接的器件（ALU等）定义总线和寄存器
    //3. 使用n输入并行多路选择器根据不同的指令分组，将它们的信息复用到单路的dec_info总线上
    //4. 对指令后接的操作数或立即数进行译码并输出到后面的器件
    //5. 根据16位或32位指令的具体情况生成立即数和寄存器索引
    //6. 译码出不同的非法指令情形
endmodule
```

## 整数通用寄存器组

蜂鸟E200中定义了该模块用于实现RISC-V架构中的整数通用寄存器组

由于E200属于单发射、按顺序每次写回一条指令的微架构，所以该模块只需要支持最多两个读端口和一个写端口

模块相关代码保存在e203_exu_regfile.v文件中

可以通过配置config.v更改通用寄存器的位数

### 端口逻辑

* 写端口

  通过将输入的结果寄存器索引和各自的寄存器号进行比较，产生写使能信号，被使能的通用寄存器即将写数据写入寄存器
  
* 读端口

  每个读端口都是一个纯粹的并行多路选择器，使用读操作数的寄存器索引作为选择信号，使用专用寄存器读取寄存器索引信号，当且仅当执行读操作数的时候这个专用寄存器才会被调用，可以减少读端口的动态反转功耗

  简而言之就是在读端口放了个门卫大爷，只有需要读取的时候大爷才会给寄存器索引数据开门（把寄存器索引存入该专用寄存器）

代码片段如下

```verilog
module e203_exu_regfile(
  input  [`E203_RFIDX_WIDTH-1:0] read_src1_idx,
  input  [`E203_RFIDX_WIDTH-1:0] read_src2_idx,
  output [`E203_XLEN-1:0] read_src1_dat,
  output [`E203_XLEN-1:0] read_src2_dat,

  input  wbck_dest_wen,
  input  [`E203_RFIDX_WIDTH-1:0] wbck_dest_idx,
  input  [`E203_XLEN-1:0] wbck_dest_dat,

  output [`E203_XLEN-1:0] x1_r,

  input  test_mode,
  input  clk,
  input  rst_n
);

    wire [`E203_XLEN-1:0] rf_r [`E203_RFREG_NUM-1:0];//这里使用二维数组定义寄存器组，具体长度就能更改了
    wire [`E203_RFREG_NUM-1:0] rf_wen;
    
`ifdef E203_REGFILE_LATCH_BASED //{
  	//这里使用DFF实现通用寄存器
    //因为如果使用锁存器就必须将写端口的DFF专门寄存一个时钟周期（latch设计），防止锁存器带来的写端口-读端口锁存器穿通
    wire [`E203_XLEN-1:0] wbck_dest_dat_r;
  	sirv_gnrl_dffl #(`E203_XLEN) wbck_dat_dffl (wbck_dest_wen, wbck_dest_dat, wbck_dest_dat_r, clk);
  	wire [`E203_RFREG_NUM-1:0] clk_rf_ltch;
`endif//}
    
	genvar i;//使用参数化的generate语法生成寄存器组的逻辑
generate //{
  	for (i=0; i<`E203_RFREG_NUM; i=i+1) begin:regfile//{
  		if(i==0) begin: rf0
		//x0这里是常数0，不需要产生写逻辑
			assign rf_wen[i] = 1'b0;
            assign rf_r[i] = `E203_XLEN'b0;
`ifdef E203_REGFILE_LATCH_BASED //{
            assign clk_rf_ltch[i] = 1'b0;
`endif//}
        end
        else begin: rfno0
            //通过对写寄存器的索引号和寄存器号进行比较产生写使能——典型的&运算
            assign rf_wen[i] = wbck_dest_wen & (wbck_dest_idx == i) ;
`ifdef E203_REGFILE_LATCH_BASED //{
            //如果是使用锁存器的配置则人为明确地为每个通用寄存器配置一个门控时钟以节省功耗
            //这里就是门控时钟的例化
            e203_clkgate u_e203_clkgate(
              .clk_in  (clk  ),
              .test_mode(test_mode),
              .clock_en(rf_wen[i]),
              .clk_out (clk_rf_ltch[i])
            );
            //在这里例化锁存器实现通用寄存器
            sirv_gnrl_ltch #(`E203_XLEN) rf_ltch (clk_rf_ltch[i], wbck_dest_dat_r, rf_r[i]);
`else//}{
            //如果不使用锁存器则例化DFF
            //在这里自动插入门控时钟以节省功耗
            sirv_gnrl_dffl #(`E203_XLEN) rf_dffl (rf_wen[i], wbck_dest_dat, rf_r[i], clk);
`endif//}
        end
  
      end//}
endgenerate//}
  
    //每个读端口都是一个纯粹的并行多路选择器，多路选择器的选择信号即读操作数的寄存器索引
  	assign read_src1_dat = rf_r[read_src1_idx];
  	assign read_src2_dat = rf_r[read_src2_idx];
endmodule
```

## CSR寄存器

RISC-V架构中定义了控制和状态寄存器CSR（Control and Status Register），用于配置或记录一些运行的状态。这些寄存器都位于核心内部，使用自己独立的地址编码空间，与存储器寻址无关，它们可以被看作“**内核的外设控制寄存器**”

使用专用的CSR读写指令来访问CSR寄存器

相关源代码位于e203_exu_csr.v文件下，严格按照RISC-V架构定义实现了各个CSR寄存器的具体功能

代码片段如下：

```verilog
module e203_exu_csr(
	input csr_ena,//CSR使能信号，来自ALU
  	input csr_wr_en,//CSR写操作标志位
 	input csr_rd_en,//CSR读操作标志位
    input [12-1:0] csr_idx,//CSR寄存器地址索引
	......
    
    output [`E203_XLEN-1:0] read_csr_dat,//读出数据
    input  [`E203_XLEN-1:0] wbck_csr_dat,//写入数据
	......
);
    
    ......
    //以MTVEC寄存器为例
    wire sel_mtvec = (csr_idx == 12'h305);///对CSR寄存器索引进行**译码判断**是否选中mtvec
	wire rd_mtvec = csr_rd_en & sel_mtvec;
`ifdef E203_SUPPORT_MTVEC //{
	wire wr_mtvec = sel_mtvec & csr_wr_en;
    wire mtvec_ena = (wr_mtvec & wbck_csr_wen);//mtvec使能信号
	wire [`E203_XLEN-1:0] mtvec_r;
	wire [`E203_XLEN-1:0] mtvec_nxt = wbck_csr_dat;
    //例化生成寄存器DFF
	sirv_gnrl_dfflr #(`E203_XLEN) mtvec_dfflr (mtvec_ena, mtvec_nxt, mtvec_r, clk, rst_n);
	wire [`E203_XLEN-1:0] csr_mtvec = mtvec_r;
`else//}{
  	//向量表基地址是可配置的参数，不支持软件写入
	wire [`E203_XLEN-1:0] csr_mtvec = `E203_MTVEC_TRAP_BASE;
`endif//}
	//对于读地址不存在的CSR寄存器，返回数据0；写地址不存在的CSR寄存器，忽略此写操作
    //这是为了对应RISC-V要求的不产生异常
    assign csr_mtvec_r = csr_mtvec;
    
    ......
    
    //生成CSR读操作所需的读数据，本质上该逻辑是使用与-或方式实现的并行多路选择器
    assign read_csr_dat = `E203_XLEN'b0 
               //| ({`E203_XLEN{rd_ustatus  }} & csr_ustatus  )
               | ({`E203_XLEN{rd_mstatus  }} & csr_mstatus  )
               | ({`E203_XLEN{rd_mie      }} & csr_mie      )
               | ({`E203_XLEN{rd_mtvec    }} & csr_mtvec    )
               | ({`E203_XLEN{rd_mepc     }} & csr_mepc     )
               | ({`E203_XLEN{rd_mscratch }} & csr_mscratch )
               | ({`E203_XLEN{rd_mcause   }} & csr_mcause   )
               | ({`E203_XLEN{rd_mbadaddr }} & csr_mbadaddr )
               | ({`E203_XLEN{rd_mip      }} & csr_mip      )
               | ({`E203_XLEN{rd_misa     }} & csr_misa      )
               | ({`E203_XLEN{rd_mvendorid}} & csr_mvendorid)
               | ({`E203_XLEN{rd_marchid  }} & csr_marchid  )
               | ({`E203_XLEN{rd_mimpid   }} & csr_mimpid   )
               | ({`E203_XLEN{rd_mhartid  }} & csr_mhartid  )
               | ({`E203_XLEN{rd_mcycle   }} & csr_mcycle   )
               | ({`E203_XLEN{rd_mcycleh  }} & csr_mcycleh  )
               | ({`E203_XLEN{rd_minstret }} & csr_minstret )
               | ({`E203_XLEN{rd_minstreth}} & csr_minstreth)
               | ({`E203_XLEN{rd_counterstop}} & csr_counterstop)// Self-defined
               | ({`E203_XLEN{rd_mcgstop}} & csr_mcgstop)// Self-defined
               | ({`E203_XLEN{rd_itcmnohold}} & csr_itcmnohold)// Self-defined
               | ({`E203_XLEN{rd_mdvnob2b}} & csr_mdvnob2b)// Self-defined
               | ({`E203_XLEN{rd_dcsr     }} & csr_dcsr    )
               | ({`E203_XLEN{rd_dpc      }} & csr_dpc     )
               | ({`E203_XLEN{rd_dscratch }} & csr_dscratch)
               ;
    
endmodule
```

# 执行

五级流水线架构中的执行需要译码之后执行，根据指令的具体操作类型将指令分配给不同的运算单元执行，常见的运算单元如下：

* 算术逻辑运算单元（ALU）：负责普通逻辑运算、加减法运算、移位运算等
* 整数乘法单元：主要负责有符号数或无符号整数的乘法
* 整数除法单元：主要负责有符号数或无符号整数的除法
* 浮点运算单元（FPU）：比较复杂，通常会分成多个不同的独立运算单元

对于其他具有特殊指令的处理器核，会相应增加特殊的运算单元（比如可以在处理器旁挂载DSP等硬件加速电路）

## 指令发射顺序

发射（Issue）或者说派遣（Dispatch）并不是经典五级流水线中的常见概念，但多用于各类RISC架构CPU，RISC-V中也使用了这一定义

**发射**：指令经过译码之后被派发到不同的运算单元执行的过程

发射和派遣可以混用，蜂鸟E200处理器流水线中使用派遣（Dispatch）作为定义

根据每个周期一次能发射的指令个数，可分为*单发射*和*多发射*处理器。

特别地，在一些高端的超标量处理器核中，流水线级数很多，使得派遣和发射有不同的含义：派遣表示指令经过译码之后被派发到不同的运算单元的等待队列中这一过程；发射则表示指令从运算单元的等待队列中发射到运算单元开始执行的过程。

根据发射、执行、写回顺序不同，往往分成以下流派：

* 顺序发射、顺序执行、顺序写回

  性能比较低，硬件实现最简单，面积最小

  往往在最简单流水线的处理器核中使用

* 顺序发射、乱序执行、顺序写回

  在指令的执行阶段由不同的运算单元同时执行不同的指令，这样规避了不同运算处理时间不同的问题，提高处理性能；最终写回时还是要按照顺序写回，所以很多时候ALU要等待其他指令先写回而将其运算单元本身的流水线停滞

  具有比较好的性能，面积稍大一些

* 顺序发射、乱序执行、乱序写回

  在上述乱序执行的基础上让运算单元乱序写回，又分成了几个不同的方法

  * 重排序缓存法

    使用Re-Orde Buffer（ROB）重排序缓存将ALU执行的结果暂存，最后由ROB顺序写回寄存器组

    存在面积过大、动态功耗较大的问题

    但是性能很好，实现方案很典型、成熟

  * 物理寄存器组法

    使用一个统一的物理寄存器组动态管理逻辑寄存器组的映射关系，ALU执行完毕后就将结果乱序写回物理寄存器组，物理寄存器组和逻辑寄存器组之间的映射关系可以改变

    控制复杂，功耗有所优化

  * 直接乱序写回法

    让没有数据相关性的执行结果直接写回寄存器组，有数据相关性的执行结果顺序写回

    只对部分程序有优化，需要增设电路

  * 其他方法

* 顺序派遣、乱序发射、乱序执行、乱序写回

  往往在高性能的超标量处理器中使用这种架构。

  基本上可以看作上面所有高性能操作的融合体

## 分支解析

取指阶段的分支预测功能对于带条件的分支指令，由于器条件解析需要进行操作数运算，所以需要在执行阶段进行运算并判断该分支指令是否真的需要跳转，并按照之前规定的分支预测算法进行对比执行，如果预测错误很可能需要进行流水线冲刷、造成性能损失

一般为了减少性能损失，会在比较靠前的流水线位置进行分支解析

## 蜂鸟E200系列的指令发射派遣

蜂鸟E200系列CPU的发射和派遣实际上指的是同一个行为：即指令经过译码之后被派发到不同的运算单元执行的总过程

该部分使用Dispatch模块和ALU模块共同完成

Dispatch模块负责向ALU模块**转发派遣任务**

ALU部分负责**交付模块和前级的接口**

蜂鸟E200系列的派遣特点如下：

* 所有指令必须被派遣给ALU，通过ALU与交付模块接口进行交付；如果是长指令，也需要通过ALU进一步发送至相应的长指令运算单元
* 实际的派遣功能发生在ALU内部。因为译码部分已经根据指令的运算单元进行了初步分组并译码出了其相应的指示信号，可以按照其指示信号将指令派遣给相应的运算单元
* 在派遣模块中处理流水线冲突问题，包括资源冲突和数据相关性冲突，并在某些特殊情况下将流水线的派遣点阻塞

## 流水线冲突、长指令和OITF处理

流水线冲突包括资源冲突和数据冲突两类，这两种冲突都会导致流水线阻塞。蜂鸟E203采用了两种方法分别处理资源冲突和数据冲突

### 数据冲突

**数据冲突**顾名思义，就是由于数据相关性引起的冲突

蜂鸟E203采用巧妙的方法处理数据冲突：将所有指令分成两类，将数据相关性分为三类，通过长指令拼接和流水线冲刷的方式进行处理

详细内容在下面的长指令和OITF处理部分给出

### 资源冲突

数据冲突的概念在之前已经给出，这里介绍一下资源冲突

**资源冲突**通常发生在指令派遣给不同的执行单元进行执行的过程中，当一个指令被执行时耗费的时钟周期较长，此后又有其他指令被派发给同一个硬件模块进行处理的情况下便会出现资源冲突的情况——后续的指令需要等待前一个指令完成操作后将硬件模块释放出来后才能得到执行。

蜂鸟E203的接口实现采用了严谨的valid-ready握手接口，一旦某个模块出现了资源冲突，它便会输出ready=0的信号，即使另一侧valid=1，也无法完成握手，所以前一级模块无法进行分配指令，将会进入等待状态，直到ready=1

### 长指令和OITF处理

蜂鸟E203将所有需要执行的指令分为两类：

1. 单周期执行指令

   蜂鸟E203的交付和写回功能均处于流水线的第二级，单周期执行指令在这一级就完成了交付和写回

2. 多周期执行指令

   这种指令通常需要多个时钟周期才能完成执行并写回，因此也称为“*后交付长流水线指令*”，简称为**长指令**

   长指令的执行过程比较特殊

为了在很多时钟周期后交付长指令，需要先检测出数据相关性，蜂鸟E203采用了一个称为OITF（Outstanding Instructions Track FIFO长指令追踪队列）的模块检测与长指令相关的RAW和WAW相关性

之所以不检测WAR相关性，是因为E203是按序派遣、按序写回的微架构，在派遣时就已经从寄存器组中读取了源操作数，所以写回Regfile操作不会发生在读取Regfile源操作数之前。

言归正传，OITF本质上是一个普通的FIFO（废话），它的源码在rtl/e203/core/e203_exu_oitf.v中可以查看

**在派遣点，每派遣一个长指令，便会在OITF中分配一个表项，在这个表项中会存储该长指令的源操作数寄存器索引和结果寄存器索引**

**在写回点，每次按序写回一个长指令后，就会将此指令在OITF中的表象去除——他就从FIFO中退出了**

综上所述，==OITF本质上保存了已经被派遣但是尚未写回的长指令信息==

为简单起见，这里就不附录相关代码了，感兴趣的读者可以自行翻阅源码

### 资源冲突的解决思路

蜂鸟E203采用了**阻塞流水线**的解决思路，并没有将长指令的结果直接快速旁路给后续的待派遣指令来解决数据冲突，也没有增加更多硬件模块处理资源冲突，这是因为蜂鸟E203的设计思路秉承“小面积”，放弃了更高的性能，转而实现较高的性能-面积比。如果设计高性能的CPU，则显然不能简单地使用这种思路

## ALU模块

蜂鸟E203的ALU单元位于EXU之下，主要包括5个子模块，它们共性同一份实际的运算数据通路，因此主要数据通路的面积开销只有一份

* **普通ALU**：主要负责逻辑运算、加减法、移位运算等通用的ALU指令
* **访存地址生成**：主要负责Load、Store和“A”扩展指令的地址生成、“A”扩展指令的微操作拆分和执行
* **分支预测解析**：主要负责Branch和Jump指令的结果解析和执行
* **CSR读写控制**：主要负责CSR读写指令的执行
* **多周期乘除法器**：主要负责乘法和除法指令的执行

### 普通ALU

位于rtl/e203/core/e203_exu_alu_rglr.v

该模块完全由组合逻辑电路构成（也就是说这玩意在FPGA里可以只占用一点点LUT），它本身并没有运算数据通路，其主要逻辑根据普通ALU的指令类型发起对共享运算数据通路的操作请求，并从共享的运算数据通路中取回运算结果

### 访存地址生成

该模块简称AGU（Adress Generation Unit），位于rtl/e203/core/e203_exu_alu_lsuagu.v

相关内容会在存储器架构部分详细介绍

### 分支预测解析

位于rtl/e203/core/e203_exu_alu_bjp.v

BJP（Branch and Jump resolve）模块是分支跳转指令进行交付的主要依据，可以查看交付部分进行了解

### CSR读写控制

该模块主要负责CSR读写指令的执行，位于rtl/e203/core/e203_exu_alu_csrctrl.v

这个模块也是完全由组合逻辑组成，其根据CSR读写指令的类型产生读写CSR寄存器模块的控制信号

代码片段如下：

```verilog
`include "e203_defines.v"

module e203_exu_alu_csrctrl(
  //握手接口
  input  csr_i_valid, // valid信号
  output csr_i_ready, // ready信号

  input  [`E203_XLEN-1:0] csr_i_rs1,
  input  [`E203_DECINFO_CSR_WIDTH-1:0] csr_i_info,
  input  csr_i_rdwen,   

  output csr_ena, // CSR读写使能信号
  output csr_wr_en, // CSR写操作指示信号
  output csr_rd_en, // CSR读操作指示信号
  output [12-1:0] csr_idx, // CSR寄存器的地址索引

  input  csr_access_ilgl,
  input  [`E203_XLEN-1:0] read_csr_dat, // 读操作从CSR寄存器模块读出的数据
  output [`E203_XLEN-1:0] wbck_csr_dat, // 写操作写入CSR寄存器模块的数据

  `ifdef E203_HAS_CSR_NICE//{
  input          nice_xs_off,
  output         csr_sel_nice,
  output         nice_csr_valid,
  input          nice_csr_ready,
  output  [31:0] nice_csr_addr,
  output         nice_csr_wr,
  output  [31:0] nice_csr_wdata,
  input   [31:0] nice_csr_rdata,
  `endif//}

  //CSR写回/交付接口
  output csr_o_valid, // valid信号
  input  csr_o_ready, // ready信号
  // 为了非对齐lst和AMO指令使用的特殊写回接口
  output [`E203_XLEN-1:0] csr_o_wbck_wdat,
  output csr_o_wbck_err,   

  input  clk,
  input  rst_n
  );

  `ifdef E203_HAS_CSR_NICE//{
      // If accessed the NICE CSR range then we need to check if the NICE CSR is ready
  assign csr_sel_nice        = (csr_idx[11:8] == 4'hE);
  wire sel_nice            = csr_sel_nice & (~nice_xs_off);
  wire addi_condi         = sel_nice ? nice_csr_ready : 1'b1; 

  assign csr_o_valid      = csr_i_valid
                            & addi_condi; // Need to make sure the nice_csr-ready is ready to make sure
                                          //  it can be sent to NICE and O interface same cycle
  assign nice_csr_valid    = sel_nice & csr_i_valid & 
                            csr_o_ready;// Need to make sure the o-ready is ready to make sure
                                        //  it can be sent to NICE and O interface same cycle

  assign csr_i_ready      = sel_nice ? (nice_csr_ready & csr_o_ready) : csr_o_ready; 

  assign csr_o_wbck_err   = csr_access_ilgl;
  assign csr_o_wbck_wdat  = sel_nice ? nice_csr_rdata : read_csr_dat;

  assign nice_csr_addr = csr_idx;
  assign nice_csr_wr   = csr_wr_en;
  assign nice_csr_wdata = wbck_csr_dat;
  `else//}{
  wire   sel_nice      = 1'b0;
  assign csr_o_valid      = csr_i_valid;
  assign csr_i_ready      = csr_o_ready;
  assign csr_o_wbck_err   = csr_access_ilgl;
  assign csr_o_wbck_wdat  = read_csr_dat;
  `endif//}

  //从Info Bus中取出相关信息
  wire        csrrw  = csr_i_info[`E203_DECINFO_CSR_CSRRW ];
  wire        csrrs  = csr_i_info[`E203_DECINFO_CSR_CSRRS ];
  wire        csrrc  = csr_i_info[`E203_DECINFO_CSR_CSRRC ];
  wire        rs1imm = csr_i_info[`E203_DECINFO_CSR_RS1IMM];
  wire        rs1is0 = csr_i_info[`E203_DECINFO_CSR_RS1IS0];
  wire [4:0]  zimm   = csr_i_info[`E203_DECINFO_CSR_ZIMMM ];
  wire [11:0] csridx = csr_i_info[`E203_DECINFO_CSR_CSRIDX];
  //生成操作数1，如果使用立即数则选择立即数，否则选择源寄存器1
  wire [`E203_XLEN-1:0] csr_op1 = rs1imm ? {27'b0,zimm} : csr_i_rs1;
  //根据指令的信息生成读操作指示信号
  assign csr_rd_en = csr_i_valid & 
    (
      (csrrw ? csr_i_rdwen : 1'b0) // the CSRRW only read when the destination reg need to be writen
      | csrrs | csrrc // The set and clear operation always need to read CSR
     );
  //根据指令的信息生成写操作指示信号
  assign csr_wr_en = csr_i_valid & (
                csrrw // CSRRW always write the original RS1 value into the CSR
               | ((csrrs | csrrc) & (~rs1is0)) // for CSRRS/RC, if the RS is x0, then should not really write
            );                                                                           
  //生成访问CSR寄存器的地址索引
  assign csr_idx = csridx;
  //生成送到CSR寄存器模块的CSR读写使能信号
  assign csr_ena = csr_o_valid & csr_o_ready & (~sel_nice);
  //生成写操作写入CSR寄存器模块的数据
  assign wbck_csr_dat = 
              ({`E203_XLEN{csrrw}} & csr_op1)
            | ({`E203_XLEN{csrrs}} & (  csr_op1  | read_csr_dat))
            | ({`E203_XLEN{csrrc}} & ((~csr_op1) & read_csr_dat));
endmodule
```

### 多周期乘除法器

蜂鸟E200系列使用了两种乘除法解决方案

对于蜂鸟E203，它配置了低性能小面积的多周期乘除法器，而对于其他性能较高的设备，则使用了高性能的单周期乘法器和独立的除法器

常用的多周期乘除法器和除法器实现，一般采用下面的理论实现：

* 有符号整数乘法：使用常用的Booth编码产生部分积，然后使用迭代的方法，每个周期使用加法器对部分积进行累加，经过多个周期的迭代后得到最终的乘积，从而实现多周期乘法器
* 有符号整数除法：使用常用的加减交替法，然后使用迭代的方法，每个周期使用加法器产生部分余数，经过多个周期的迭代后得到最终商和玉树，从而实现多周期除法器

两个模块的理论内容可参考数电教材或相关书籍

因为两个模块都以加法器为核心并使用一组寄存器保存部分积或部分余数，所以在蜂鸟E203中使用了资源复用——将多周期乘除法器合并作为ALU的一个子单元，二者共享数据通路中的加法器，经过多个周期完成乘法或者除法操作

多周期乘除法器MDV模块位于rtl/e203/core/e203_exu_alu_muldiv.v

同时蜂鸟E203对乘除法进行了以下优化：

* 乘法操作中，为了减少所需周期数，采用了基4（Radix-4）的Booth编码，并对无符号乘法进行一位符号扩展后统一当作有符号数进行运算，所以需要17个迭代周期
* 除法操作中，使用了普通的加减交替法，同样对于无符号乘法统一进行一位符号扩展后当作有符号数进行运算，需要33个迭代周期。此外，由于加减交替法所得结果存在1比特精度的问题，还需要额外的1个时钟周期判断是否需要进行商和余数的矫正，还有额外2个周期的商和余数矫正，最终才能得到准确的除法结果
* MDV模块只进行运算控制，没有自己的加法器，加法器与其他ALU子单元复用共享的运算数据通路
* MDV模块也没有自己的寄存器，寄存器与AGU单元复用

综上所述，**MDV实际上只是一个状态机，其乘法实现需要17个迭代周期，除法实现需要最多36个周期**，采用了典型的“速度换面积”思想

### 运算数据通路

事实上ALU真正用于计算的模块是数据通路，位于rtl/e203/core/e203_exu_alu_dpath.v

它被动接受其他ALU子单元的请求来进行具体运算，然后将计算结果返回非其他子单元运算数据通路

可以说ALU的其他子单元只是一套针对不同指令选择不同逻辑的状态机（控制系统），而数据主要经过的运算数据通路才是ALU的运算核心，整个ALU是类似“众星捧月”的结构——占据面积最大的运算数据通路在中间，数据流经过时会被周边的状态机挑选，或单次通过（普通ALU）或反复通过并输出不同结果到寄存器（多周期乘除法器），这就使得ALU面积大大缩小

### 高性能乘除法运算

除了小面积的多周期乘除法器外，**其他型号的蜂鸟E200**还配备了高性能的单周期乘法器和独立的除法器

高性能乘法器会被部署在流水线第二级，除法器则仍然使用多周期除法器，但不再与ALU复用共享的运算数据通路，而是作为长指令拥有单独的除法器单元，同样部署在流水线第二级

### 浮点单元

蜂鸟E200系列支持RISC-V的“F”和“D”扩展子集，可以处理单精度和双精度浮点指令

浮点指令由FPU支持，如果配置了FPU，则FPU作为长指令拥有独立的运算单元，并且FPU还具有独立的通用浮点寄存器组。包含F和D扩展子集的模块要求包含32个通用浮点寄存器，其中如果仅包含F的话，浮点指令子集通用浮点寄存器的宽度为32位，仅包含D的浮点指令子集通用浮点寄存器的宽度为64位

蜂鸟E200系列的FPU支持以下功能

* 独立的时钟门控
* 独立电源域
* 单双精度浮点指令复用数据通路

但是**开源的蜂鸟E203并没有配备FPU**（悲）

## 总结

这部分简要介绍了蜂鸟E203的执行单元中译码和执行两个环节

写回、交付还有其他的一些单元因为涉及到篇幅会在之后的写回、交付、存储器相关博文中介绍

EXU部分是蜂鸟E203的核心环节，代码量也很多，所以需要反复理解