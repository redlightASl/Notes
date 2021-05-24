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











