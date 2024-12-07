# 蜂鸟E203的交付与写回机制

在经典的五级流水线模型中并没有交付的概念，在这里**交付**（Commit）**指的是该指令不再是预测执行**（Speculative）**状态，而是被判定为可以真正地在处理器中被执行**

交付的反义词就是“**取消**”（Cancel），**表示该指令最后被判定为需要取消**

如果处理器流水线需要将没有交付的后续指令全部取消时，就会导致“**流水线冲刷**”的产生，下面依次来介绍

## 交付与流水线冲刷

**通常情况下交付都是顺序判定，理论上只有前一条指令完成交付之后才会轮到后一条指令交付**

以下因素会映像指令交付：

* 中断、异常、分支预测指令

  它们往往会导致流水线冲刷，将后续所有预取的指令都取消掉

* 条件码

  在一些指令集架构（比如典型的ARM架构）中，对于每条指令，只有其条件码满足条件为真才能真正交付，否则就会被取消，这里的取消只是取消它自己，并不会产生流水线冲刷

根据处理器性能不同，可以选择**低性能**的一个周期交付一条指令或者**高性能**的一个周期交付多条指令；并且交付的位置可以有所不同，常见的方案如下：

* 执行阶段交付

  在执行阶段将分支预测指令的结果解析完成并进行交付

* 写回阶段交付

  由于有些指令需要多个周期的执行以后才能写回，并且可能产生错误异常，所以有些微架构将交付放在写回阶段

* 重排序交付队列（Re-Order Commit Queue）

  对于高性能的超标量处理器而言，往往是乱序执行乱序写回，在写回阶段往往使用ROB或纯物理寄存器的方式，同时会配备一个较深的重排序交付队列来缓存乱序执行的指令信息，并对其进行按序交付

对于RISC-V而言，**指令没有条件码**、**所有运算指令都不会产生异常**这两个固有特点大幅简化了交付的硬件实现

在RISC-V的处理器核中只需要处理

1. 分支预测指令错误预测造成的后续指令流取消
2. 中断和异常造成的后续指令流取消

## 蜂鸟E203的交付实现

蜂鸟E203处理器将交付安排在执行阶段，并且可以保证：只要前序的指令没有发生分支预测错误、中断或异常就可以判定该指令能够被成功交付。对于分支预测错误的指令自身和遭遇了中断或者异常的指令自身而言，仍然是属于成功交付的指令，因为他们自身已经被真正执行并对处理器状态真正地产生了影响

对于分支预测指令，蜂鸟E203使用IFU中进行预测的分支指令为带条件跳转指令类型，有以下几个条件：

beq：两个整数操作数相等则跳转

bne：两个整数不相等则跳转

blt：有符号数小于则跳转

bltu：无符号数大于则跳转

bge：有符号数大于则跳转

bgeu：无符号数大于则跳转

这些跳转条件的决定由ALU完成，所以具体的跳转操作是在ALU之后完成的

相关代码位于rtl/e203/core/e203_exu_alu_bjp.v

ALU在计算出结果后会发送给交付模块，交付模块根据预测结果和真实结果进行判断，如果预测和真实的结果相符则预测成功，不会进行流水线冲刷，否则就进行流水线冲刷

相关模块位于rtl/e203/core/e203_exu_commit.v和e203_exu_branchslv.v（这是e203_exu_commit的子模块，用于对分支预测指令 的结果进行判断） 

对于多周期的长指令，交付同样在执行阶段完成，但是写回则需要在后续的周期内进行，并且对于特殊的长指令在写回时产生的错误异常会被当作异步异常进行处理，所以说并不会引起不必要的流水线冲刷

## 写回与写回仲裁

蜂鸟E203采用了因地制宜的混合策略，兼顾了面积最小化的原则和较好的性能，核心思想就是“分类讨论”：将指令划分为单周期指令和长指令，将长指令的交付和写回分开，使得即使执行了多周期长指令，仍然不会阻塞流水线。

写回部分主要由最终写回仲裁、长指令写回仲裁和OITF组成

### 最终写回仲裁

位于rtl/e203/core/e203_exu_wbck.v

E203具有两级写回仲裁模块，第一个就是最终写回仲裁模块（Final Write-Back Arbitration，FWBA）

该模块主要用于仲裁所有**来自ALU的单周期指令**的写回和所有**来自长指令写回仲裁模块的长指令**的写回

也就是说==FWBA用于所有指令最终写回的判断==

仲裁采用优先级仲裁的方式，由于长指令的写回比正在协会的ALU指令在程序流中处于更早的位置，长指令就具有更高的写回优先级，这就导致了以下情形发生：如果在长指令完成执行准备写回时，有单周期指令正在写回，它会被“打断”（指的是在上一条写回完成后不会继续写回下一条单周期指令，而是会转而写回长指令），长指令得到写回；如果在没有长指令写回的空闲周期，来自ALU的单周期指令则可以随便写回，这也就意味着在程序流中处于更迟位置的单周期指令可以比更早位置的长指令先写回寄存器组。这就是的蜂鸟E203处理器具有乱序写回的能力

代码片段如下：

```verilog
module e203_exu_wbck(
  // ALU写回接口
  input  alu_wbck_i_valid, // valid信号
  output alu_wbck_i_ready, // ready信号
  input  [`E203_XLEN-1:0] alu_wbck_i_wdat, // 写回的数据值
  input  [`E203_RFIDX_WIDTH-1:0] alu_wbck_i_rdidx, // 写回的寄存器索引值
  //如果ALU出错，就不会生成wback_valid信号到写回模块
  //所以这里不需要alu_wbck_i_err报错信号

  // 长指令写回接口
  input  longp_wbck_i_valid, // valid信号
  output longp_wbck_i_ready, // ready信号
  input  [`E203_FLEN-1:0] longp_wbck_i_wdat, // 写回的数据值
  input  [5-1:0] longp_wbck_i_flags, // 写回标志
  input  [`E203_RFIDX_WIDTH-1:0] longp_wbck_i_rdidx, // 写回的寄存器索引
  input  longp_wbck_i_rdfpu, // 写回到FPU的数据

  // 仲裁后写回寄存器组的接口
  output  rf_wbck_o_ena, // 写使能
  output  [`E203_XLEN-1:0] rf_wbck_o_wdat, // 写回的数据值
  output  [`E203_RFIDX_WIDTH-1:0] rf_wbck_o_rdidx, // 写回的寄存器索引
  
  input  clk,
  input  rst_n
  );

  // 使用优先级仲裁
  // 如果两种指令同时写回，则长指令拥有更高的优先级
  // 只有当没有长指令时，ALU单周期指令才能写回
  wire wbck_ready4alu = (~longp_wbck_i_valid);
  wire wbck_sel_alu = alu_wbck_i_valid & wbck_ready4alu;
  // 因为长指令优先级更高，所以可以优先写回 
  wire wbck_ready4longp = 1'b1;
  wire wbck_sel_longp = longp_wbck_i_valid & wbck_ready4longp;

  // 最终仲裁写回接口
  wire rf_wbck_o_ready = 1'b1; // 寄存器组因为只有单总线所以总是可以写回的

  wire wbck_i_ready;
  wire wbck_i_valid;
  wire [`E203_FLEN-1:0] wbck_i_wdat;
  wire [5-1:0] wbck_i_flags;
  wire [`E203_RFIDX_WIDTH-1:0] wbck_i_rdidx;
  wire wbck_i_rdfpu;

  assign alu_wbck_i_ready   = wbck_ready4alu   & wbck_i_ready;
  assign longp_wbck_i_ready = wbck_ready4longp & wbck_i_ready;

  assign wbck_i_valid = wbck_sel_alu ? alu_wbck_i_valid : longp_wbck_i_valid;
  `ifdef E203_FLEN_IS_32//{
  assign wbck_i_wdat  = wbck_sel_alu ? alu_wbck_i_wdat  : longp_wbck_i_wdat;
  `else//}{
  assign wbck_i_wdat  = wbck_sel_alu ? {{`E203_FLEN-`E203_XLEN{1'b0}},alu_wbck_i_wdat}  : longp_wbck_i_wdat;
  `endif//}
  assign wbck_i_flags = wbck_sel_alu ? 5'b0  : longp_wbck_i_flags;
  assign wbck_i_rdidx = wbck_sel_alu ? alu_wbck_i_rdidx : longp_wbck_i_rdidx;
  assign wbck_i_rdfpu = wbck_sel_alu ? 1'b0 : longp_wbck_i_rdfpu;

  //长指令写回异常产生部分，见下文
  //如果长指令出错或者因为某些原因没能写回，他就会被在执行阶段被取消掉
  //所以这个模块总是需要在这里将数据写回寄存器组
  assign wbck_i_ready  = rf_wbck_o_ready;
  wire rf_wbck_o_valid = wbck_i_valid;

  wire wbck_o_ena   = rf_wbck_o_valid & rf_wbck_o_ready;

  assign rf_wbck_o_ena   = wbck_o_ena & (~wbck_i_rdfpu);
  assign rf_wbck_o_wdat  = wbck_i_wdat[`E203_XLEN-1:0];
  assign rf_wbck_o_rdidx = wbck_i_rdidx;
endmodule
```

### 长指令写回仲裁与OITF

E203具有两级写回仲裁模块，第二个就是长指令写回仲裁模块（Long-Pipes Instructions Write-Back Arbitration，LPIWBA）

OITF和长指令写回仲裁模块协同合作完成所有长指令的写回操作，**长指令写回仲裁主要用于仲裁不同长指令之间的写回**，因为这些指令来自不同执行单元、执行的周期数不同、执行的顺序不同、写回的地方不一样，就需要记录这些指令的先后关系，这就用到了OITF

OITF在之前的执行部分已经介绍过，**它本质上是一个记录还未写回但是已经在执行的长指令的FIFO**。每个被派遣的长指令都会在OITF中分配一个表项（Entry），这个表项的FIFO指针就作为这个长指令的ITAG，***长指令不管被派遣到任何运算单元都会携带这个ITAG，同时写回时也要带着相同的ITAG***

OITF的深度就决定了能够派遣的滞外（Outstanding，也就是OITF中的“O”）长指令的个数。为了硬件实现的简洁，蜂鸟E203采用严格按照OITF的顺序写回到方法——OITF的读指针会指向最先进入此FIFO的表项，通过使用此读指针作为长指令写回仲裁的选择参考，就可以保证不同长指令的写回顺序和派遣顺序严格一致。

每次长指令写回仲裁模块成功写回一个长指令后，对应地OITF表项就被从FIFO中退出了

由于有些长指令可能发生执行错误，因此需要产生异常——长指令写回仲裁模块会和交付模块产生接口触发异常，如果长指令产生异常，则不会真正写回，而是在接口部分就被丢弃。

有关FWBA的代码部分见上面的源码

长指令写回仲裁和OITF部分的源码位于rtl/e203/core/e203_exu_disp.v、rtl/e203/core/e203_exu_oitf.v、rtl/e203/core/e203_exu_longwbck.v三个文件

这里直接复制粘贴了全部源码，推荐系统地看一下三个文件的代码来更好地理解实现思路

```verilog
/*                      e203_exu_disp                */
module e203_exu_disp(
  input  wfi_halt_exu_req,
  output wfi_halt_exu_ack,

  input  oitf_empty,
  input  amo_wait,
  //////////////////////////////////////////////////////////////
  // The operands and decode info from dispatch
  input  disp_i_valid, // Handshake valid
  output disp_i_ready, // Handshake ready 

  // The operand 1/2 read-enable signals and indexes
  input  disp_i_rs1x0,
  input  disp_i_rs2x0,
  input  disp_i_rs1en,
  input  disp_i_rs2en,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rs1idx,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rs2idx,
  input  [`E203_XLEN-1:0] disp_i_rs1,
  input  [`E203_XLEN-1:0] disp_i_rs2,
  input  disp_i_rdwen,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rdidx,
  input  [`E203_DECINFO_WIDTH-1:0]  disp_i_info,  
  input  [`E203_XLEN-1:0] disp_i_imm,
  input  [`E203_PC_SIZE-1:0] disp_i_pc,
  input  disp_i_misalgn,
  input  disp_i_buserr ,
  input  disp_i_ilegl  ,

  //////////////////////////////////////////////////////////////
  // Dispatch to ALU
  output disp_o_alu_valid, 
  input  disp_o_alu_ready,

  input  disp_o_alu_longpipe,

  output [`E203_XLEN-1:0] disp_o_alu_rs1,
  output [`E203_XLEN-1:0] disp_o_alu_rs2,
  output disp_o_alu_rdwen,
  output [`E203_RFIDX_WIDTH-1:0] disp_o_alu_rdidx,
  output [`E203_DECINFO_WIDTH-1:0]  disp_o_alu_info,  
  output [`E203_XLEN-1:0] disp_o_alu_imm,
  output [`E203_PC_SIZE-1:0] disp_o_alu_pc,
  output [`E203_ITAG_WIDTH-1:0] disp_o_alu_itag,
  output disp_o_alu_misalgn,
  output disp_o_alu_buserr ,
  output disp_o_alu_ilegl  ,

  //////////////////////////////////////////////////////////////
  // Dispatch to OITF
  input  oitfrd_match_disprs1,
  input  oitfrd_match_disprs2,
  input  oitfrd_match_disprs3,
  input  oitfrd_match_disprd,
  input  [`E203_ITAG_WIDTH-1:0] disp_oitf_ptr ,

  output disp_oitf_ena,
  input  disp_oitf_ready,

  output disp_oitf_rs1fpu,
  output disp_oitf_rs2fpu,
  output disp_oitf_rs3fpu,
  output disp_oitf_rdfpu ,

  output disp_oitf_rs1en ,
  output disp_oitf_rs2en ,
  output disp_oitf_rs3en ,
  output disp_oitf_rdwen ,

  output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs1idx,
  output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs2idx,
  output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs3idx,
  output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rdidx ,

  output [`E203_PC_SIZE-1:0] disp_oitf_pc ,

  
  input  clk,
  input  rst_n
  );

  wire [`E203_DECINFO_GRP_WIDTH-1:0] disp_i_info_grp  = disp_i_info [`E203_DECINFO_GRP];

  // Based on current 2 pipe stage implementation, the 2nd stage need to have all instruction
  //   to be commited via ALU interface, so every instruction need to be dispatched to ALU,
  //   regardless it is long pipe or not, and inside ALU it will issue instructions to different
  //   other longpipes
  //wire disp_alu  = (disp_i_info_grp == `E203_DECINFO_GRP_ALU) 
  //               | (disp_i_info_grp == `E203_DECINFO_GRP_BJP) 
  //               | (disp_i_info_grp == `E203_DECINFO_GRP_CSR) 
  //              `ifdef E203_SUPPORT_SHARE_MULDIV //{
  //               | (disp_i_info_grp == `E203_DECINFO_GRP_MULDIV) 
  //              `endif//E203_SUPPORT_SHARE_MULDIV}
  //               | (disp_i_info_grp == `E203_DECINFO_GRP_AGU);

  wire disp_csr = (disp_i_info_grp == `E203_DECINFO_GRP_CSR); 

  wire disp_alu_longp_prdt = (disp_i_info_grp == `E203_DECINFO_GRP_AGU)  
                             ;

  wire disp_alu_longp_real = disp_o_alu_longpipe;

  // Both fence and fencei need to make sure all outstanding instruction have been completed
  wire disp_fence_fencei   = (disp_i_info_grp == `E203_DECINFO_GRP_BJP) & 
                               ( disp_i_info [`E203_DECINFO_BJP_FENCE] | disp_i_info [`E203_DECINFO_BJP_FENCEI]);   

  // Since any instruction will need to be dispatched to ALU, we dont need the gate here
  //   wire   disp_i_ready_pos = disp_alu & disp_o_alu_ready;
  //   assign disp_o_alu_valid = disp_alu & disp_i_valid_pos; 
  wire disp_i_valid_pos; 
  wire   disp_i_ready_pos = disp_o_alu_ready;
  assign disp_o_alu_valid = disp_i_valid_pos; 
  
  //////////////////////////////////////////////////////////////
  // The Dispatch Scheme Introduction for two-pipeline stage
  //  #1: The instruction after dispatched must have already have operand fetched, so
  //      there is no any WAR dependency happened.
  //  #2: The ALU-instruction are dispatched and executed in-order inside ALU, so
  //      there is no any WAW dependency happened among ALU instructions.
  //      Note: LSU since its AGU is handled inside ALU, so it is treated as a ALU instruction
  //  #3: The non-ALU-instruction are all tracked by OITF, and must be write-back in-order, so 
  //      it is like ALU in-ordered. So there is no any WAW dependency happened among
  //      non-ALU instructions.
  //  Then what dependency will we have?
  //  * RAW: This is the real dependency
  //  * WAW: The WAW between ALU an non-ALU instructions
  //
  //  So #1, The dispatching ALU instruction can not proceed and must be stalled when
  //      ** RAW: The ALU reading operands have data dependency with OITF entries
  //         *** Note: since it is 2 pipeline stage, any last ALU instruction have already
  //             write-back into the regfile. So there is no chance for ALU instr to depend 
  //             on last ALU instructions as RAW. 
  //             Note: if it is 3 pipeline stages, then we also need to consider the ALU-to-ALU 
  //                   RAW dependency.
  //      ** WAW: The ALU writing result have no any data dependency with OITF entries
  //           Note: Since the ALU instruction handled by ALU may surpass non-ALU OITF instructions
  //                 so we must check this.
  //  And #2, The dispatching non-ALU instruction can not proceed and must be stalled when
  //      ** RAW: The non-ALU reading operands have data dependency with OITF entries
  //         *** Note: since it is 2 pipeline stage, any last ALU instruction have already
  //             write-back into the regfile. So there is no chance for non-ALU instr to depend 
  //             on last ALU instructions as RAW. 
  //             Note: if it is 3 pipeline stages, then we also need to consider the non-ALU-to-ALU 
  //                   RAW dependency.

  wire raw_dep =  ((oitfrd_match_disprs1) |
                   (oitfrd_match_disprs2) |
                   (oitfrd_match_disprs3)); 
               // Only check the longp instructions (non-ALU) for WAW, here if we 
               //   use the precise version (disp_alu_longp_real), it will hurt timing very much, but
               //   if we use imprecise version of disp_alu_longp_prdt, it is kind of tricky and in 
               //   some corner case. For example, the AGU (treated as longp) will actually not dispatch
               //   to longp but just directly commited, then it become a normal ALU instruction, and should
               //   check the WAW dependency, but this only happened when it is AMO or unaligned-uop, so
               //   ideally we dont need to worry about it, because
               //     * We dont support AMO in 2 stage CPU here
               //     * We dont support Unalign load-store in 2 stage CPU here, which 
               //         will be triggered as exception, so will not really write-back
               //         into regfile
               //     * But it depends on some assumption, so it is still risky if in the future something changed.
               // Nevertheless: using this condition only waiver the longpipe WAW case, that is, two
               //   longp instruction write-back same reg back2back. Is it possible or is it common? 
               //   after we checking the benmark result we found if we remove this complexity here 
               //   it just does not change any benchmark number, so just remove that condition out. Means
               //   all of the instructions will check waw_dep
  //wire alu_waw_dep = (~disp_alu_longp_prdt) & (oitfrd_match_disprd & disp_i_rdwen); 
  wire waw_dep = (oitfrd_match_disprd); 

  wire dep = raw_dep | waw_dep;

  // The WFI halt exu ack will be asserted when the OITF is empty
  //    and also there is no AMO oustanding uops 
  assign wfi_halt_exu_ack = oitf_empty & (~amo_wait);

  wire disp_condition = 
                 // To be more conservtive, any accessing CSR instruction need to wait the oitf to be empty.
                 // Theoretically speaking, it should also flush pipeline after the CSR have been updated
                 //  to make sure the subsequent instruction get correct CSR values, but in our 2-pipeline stage
                 //  implementation, CSR is updated after EXU stage, and subsequent are all executed at EXU stage,
                 //  no chance to got wrong CSR values, so we dont need to worry about this.
                 (disp_csr ? oitf_empty : 1'b1)
                 // To handle the Fence: just stall dispatch until the OITF is empty
               & (disp_fence_fencei ? oitf_empty : 1'b1)
                 // If it was a WFI instruction commited halt req, then it will stall the disaptch
               & (~wfi_halt_exu_req)   
                 // No dependency
               & (~dep)   
               ////  // If dispatch to ALU as long pipeline, then must check
               ////  //   the OITF is ready
               //// & ((disp_alu & disp_o_alu_longpipe) ? disp_oitf_ready : 1'b1);
               // To cut the critical timing  path from longpipe signal
               // we always assume the LSU will need oitf ready
               & (disp_alu_longp_prdt ? disp_oitf_ready : 1'b1);

  assign disp_i_valid_pos = disp_condition & disp_i_valid; 
  assign disp_i_ready     = disp_condition & disp_i_ready_pos; 

  wire [`E203_XLEN-1:0] disp_i_rs1_msked = disp_i_rs1 & {`E203_XLEN{~disp_i_rs1x0}};
  wire [`E203_XLEN-1:0] disp_i_rs2_msked = disp_i_rs2 & {`E203_XLEN{~disp_i_rs2x0}};
    // Since we always dispatch any instructions into ALU, so we dont need to gate ops here
  //assign disp_o_alu_rs1   = {`E203_XLEN{disp_alu}} & disp_i_rs1_msked;
  //assign disp_o_alu_rs2   = {`E203_XLEN{disp_alu}} & disp_i_rs2_msked;
  //assign disp_o_alu_rdwen = disp_alu & disp_i_rdwen;
  //assign disp_o_alu_rdidx = {`E203_RFIDX_WIDTH{disp_alu}} & disp_i_rdidx;
  //assign disp_o_alu_info  = {`E203_DECINFO_WIDTH{disp_alu}} & disp_i_info;  
  assign disp_o_alu_rs1   = disp_i_rs1_msked;
  assign disp_o_alu_rs2   = disp_i_rs2_msked;
  assign disp_o_alu_rdwen = disp_i_rdwen;
  assign disp_o_alu_rdidx = disp_i_rdidx;
  assign disp_o_alu_info  = disp_i_info;  
  
    // Why we use precise version of disp_longp here, because
    //   only when it is really dispatched as long pipe then allocate the OITF
  assign disp_oitf_ena = disp_o_alu_valid & disp_o_alu_ready & disp_alu_longp_real;

  assign disp_o_alu_imm  = disp_i_imm;
  assign disp_o_alu_pc   = disp_i_pc;
  assign disp_o_alu_itag = disp_oitf_ptr;
  assign disp_o_alu_misalgn= disp_i_misalgn;
  assign disp_o_alu_buserr = disp_i_buserr ;
  assign disp_o_alu_ilegl  = disp_i_ilegl  ;

  `ifndef E203_HAS_FPU//{
  wire disp_i_fpu       = 1'b0;
  wire disp_i_fpu_rs1en = 1'b0;
  wire disp_i_fpu_rs2en = 1'b0;
  wire disp_i_fpu_rs3en = 1'b0;
  wire disp_i_fpu_rdwen = 1'b0;
  wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs1idx = `E203_RFIDX_WIDTH'b0;
  wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs2idx = `E203_RFIDX_WIDTH'b0;
  wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs3idx = `E203_RFIDX_WIDTH'b0;
  wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rdidx  = `E203_RFIDX_WIDTH'b0;
  wire disp_i_fpu_rs1fpu = 1'b0;
  wire disp_i_fpu_rs2fpu = 1'b0;
  wire disp_i_fpu_rs3fpu = 1'b0;
  wire disp_i_fpu_rdfpu  = 1'b0;
  `endif//}
  assign disp_oitf_rs1fpu = disp_i_fpu ? (disp_i_fpu_rs1en & disp_i_fpu_rs1fpu) : 1'b0;
  assign disp_oitf_rs2fpu = disp_i_fpu ? (disp_i_fpu_rs2en & disp_i_fpu_rs2fpu) : 1'b0;
  assign disp_oitf_rs3fpu = disp_i_fpu ? (disp_i_fpu_rs3en & disp_i_fpu_rs3fpu) : 1'b0;
  assign disp_oitf_rdfpu  = disp_i_fpu ? (disp_i_fpu_rdwen & disp_i_fpu_rdfpu ) : 1'b0;

  assign disp_oitf_rs1en  = disp_i_fpu ? disp_i_fpu_rs1en : disp_i_rs1en;
  assign disp_oitf_rs2en  = disp_i_fpu ? disp_i_fpu_rs2en : disp_i_rs2en;
  assign disp_oitf_rs3en  = disp_i_fpu ? disp_i_fpu_rs3en : 1'b0;
  assign disp_oitf_rdwen  = disp_i_fpu ? disp_i_fpu_rdwen : disp_i_rdwen;

  assign disp_oitf_rs1idx = disp_i_fpu ? disp_i_fpu_rs1idx : disp_i_rs1idx;
  assign disp_oitf_rs2idx = disp_i_fpu ? disp_i_fpu_rs2idx : disp_i_rs2idx;
  assign disp_oitf_rs3idx = disp_i_fpu ? disp_i_fpu_rs3idx : `E203_RFIDX_WIDTH'b0;
  assign disp_oitf_rdidx  = disp_i_fpu ? disp_i_fpu_rdidx  : disp_i_rdidx;

  assign disp_oitf_pc  = disp_i_pc;

endmodule

/*                      e203_exu_oitf                */

module e203_exu_oitf (
  output dis_ready,

  input  dis_ena,
  input  ret_ena,

  output [`E203_ITAG_WIDTH-1:0] dis_ptr,
  output [`E203_ITAG_WIDTH-1:0] ret_ptr,

  output [`E203_RFIDX_WIDTH-1:0] ret_rdidx,
  output ret_rdwen,
  output ret_rdfpu,
  output [`E203_PC_SIZE-1:0] ret_pc,

  input  disp_i_rs1en,
  input  disp_i_rs2en,
  input  disp_i_rs3en,
  input  disp_i_rdwen,
  input  disp_i_rs1fpu,
  input  disp_i_rs2fpu,
  input  disp_i_rs3fpu,
  input  disp_i_rdfpu,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rs1idx,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rs2idx,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rs3idx,
  input  [`E203_RFIDX_WIDTH-1:0] disp_i_rdidx,
  input  [`E203_PC_SIZE    -1:0] disp_i_pc,

  output oitfrd_match_disprs1,
  output oitfrd_match_disprs2,
  output oitfrd_match_disprs3,
  output oitfrd_match_disprd,

  output oitf_empty,
  input  clk,
  input  rst_n
);

  wire [`E203_OITF_DEPTH-1:0] vld_set;
  wire [`E203_OITF_DEPTH-1:0] vld_clr;
  wire [`E203_OITF_DEPTH-1:0] vld_ena;
  wire [`E203_OITF_DEPTH-1:0] vld_nxt;
  wire [`E203_OITF_DEPTH-1:0] vld_r;
  wire [`E203_OITF_DEPTH-1:0] rdwen_r;
  wire [`E203_OITF_DEPTH-1:0] rdfpu_r;
  wire [`E203_RFIDX_WIDTH-1:0] rdidx_r[`E203_OITF_DEPTH-1:0];
  // The PC here is to be used at wback stage to track out the
  //  PC of exception of long-pipe instruction
  wire [`E203_PC_SIZE-1:0] pc_r[`E203_OITF_DEPTH-1:0];

  wire alc_ptr_ena = dis_ena;
  wire ret_ptr_ena = ret_ena;

  wire oitf_full ;
  
  wire [`E203_ITAG_WIDTH-1:0] alc_ptr_r;
  wire [`E203_ITAG_WIDTH-1:0] ret_ptr_r;

  generate
  if(`E203_OITF_DEPTH > 1) begin: depth_gt1//{
      wire alc_ptr_flg_r;
      wire alc_ptr_flg_nxt = ~alc_ptr_flg_r;
      wire alc_ptr_flg_ena = (alc_ptr_r == ($unsigned(`E203_OITF_DEPTH-1))) & alc_ptr_ena;
      
      sirv_gnrl_dfflr #(1) alc_ptr_flg_dfflrs(alc_ptr_flg_ena, alc_ptr_flg_nxt, alc_ptr_flg_r, clk, rst_n);
      
      wire [`E203_ITAG_WIDTH-1:0] alc_ptr_nxt; 
      
      assign alc_ptr_nxt = alc_ptr_flg_ena ? `E203_ITAG_WIDTH'b0 : (alc_ptr_r + 1'b1);
      
      sirv_gnrl_dfflr #(`E203_ITAG_WIDTH) alc_ptr_dfflrs(alc_ptr_ena, alc_ptr_nxt, alc_ptr_r, clk, rst_n);
      
      wire ret_ptr_flg_r;
      wire ret_ptr_flg_nxt = ~ret_ptr_flg_r;
      wire ret_ptr_flg_ena = (ret_ptr_r == ($unsigned(`E203_OITF_DEPTH-1))) & ret_ptr_ena;
      
      sirv_gnrl_dfflr #(1) ret_ptr_flg_dfflrs(ret_ptr_flg_ena, ret_ptr_flg_nxt, ret_ptr_flg_r, clk, rst_n);
      
      wire [`E203_ITAG_WIDTH-1:0] ret_ptr_nxt; 
      
      assign ret_ptr_nxt = ret_ptr_flg_ena ? `E203_ITAG_WIDTH'b0 : (ret_ptr_r + 1'b1);

      sirv_gnrl_dfflr #(`E203_ITAG_WIDTH) ret_ptr_dfflrs(ret_ptr_ena, ret_ptr_nxt, ret_ptr_r, clk, rst_n);

      assign oitf_empty = (ret_ptr_r == alc_ptr_r) &   (ret_ptr_flg_r == alc_ptr_flg_r);
      assign oitf_full  = (ret_ptr_r == alc_ptr_r) & (~(ret_ptr_flg_r == alc_ptr_flg_r));
  end//}
  else begin: depth_eq1//}{
      assign alc_ptr_r =1'b0;
      assign ret_ptr_r =1'b0;
      assign oitf_empty = ~vld_r[0];
      assign oitf_full  = vld_r[0];
  end//}
  endgenerate//}

  assign ret_ptr = ret_ptr_r;
  assign dis_ptr = alc_ptr_r;

 //// 
 //// // If the OITF is not full, or it is under retiring, then it is ready to accept new dispatch
 //// assign dis_ready = (~oitf_full) | ret_ena;
 // To cut down the loop between ALU write-back valid --> oitf_ret_ena --> oitf_ready ---> dispatch_ready --- > alu_i_valid
 //   we exclude the ret_ena from the ready signal
 assign dis_ready = (~oitf_full);
  
  wire [`E203_OITF_DEPTH-1:0] rd_match_rs1idx;
  wire [`E203_OITF_DEPTH-1:0] rd_match_rs2idx;
  wire [`E203_OITF_DEPTH-1:0] rd_match_rs3idx;
  wire [`E203_OITF_DEPTH-1:0] rd_match_rdidx;

  genvar i;
  generate //{
      for (i=0; i<`E203_OITF_DEPTH; i=i+1) begin:oitf_entries//{
  
        assign vld_set[i] = alc_ptr_ena & (alc_ptr_r == i);
        assign vld_clr[i] = ret_ptr_ena & (ret_ptr_r == i);
        assign vld_ena[i] = vld_set[i] |   vld_clr[i];
        assign vld_nxt[i] = vld_set[i] | (~vld_clr[i]);
  
        sirv_gnrl_dfflr #(1) vld_dfflrs(vld_ena[i], vld_nxt[i], vld_r[i], clk, rst_n);
        //Payload only set, no need to clear
        sirv_gnrl_dffl #(`E203_RFIDX_WIDTH) rdidx_dfflrs(vld_set[i], disp_i_rdidx, rdidx_r[i], clk);
        sirv_gnrl_dffl #(`E203_PC_SIZE    ) pc_dfflrs   (vld_set[i], disp_i_pc   , pc_r[i]   , clk);
        sirv_gnrl_dffl #(1)                 rdwen_dfflrs(vld_set[i], disp_i_rdwen, rdwen_r[i], clk);
        sirv_gnrl_dffl #(1)                 rdfpu_dfflrs(vld_set[i], disp_i_rdfpu, rdfpu_r[i], clk);

        assign rd_match_rs1idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs1en & (rdfpu_r[i] == disp_i_rs1fpu) & (rdidx_r[i] == disp_i_rs1idx);
        assign rd_match_rs2idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs2en & (rdfpu_r[i] == disp_i_rs2fpu) & (rdidx_r[i] == disp_i_rs2idx);
        assign rd_match_rs3idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs3en & (rdfpu_r[i] == disp_i_rs3fpu) & (rdidx_r[i] == disp_i_rs3idx);
        assign rd_match_rdidx [i] = vld_r[i] & rdwen_r[i] & disp_i_rdwen & (rdfpu_r[i] == disp_i_rdfpu ) & (rdidx_r[i] == disp_i_rdidx );
  
      end//}
  endgenerate//}

  assign oitfrd_match_disprs1 = |rd_match_rs1idx;
  assign oitfrd_match_disprs2 = |rd_match_rs2idx;
  assign oitfrd_match_disprs3 = |rd_match_rs3idx;
  assign oitfrd_match_disprd  = |rd_match_rdidx ;

  assign ret_rdidx = rdidx_r[ret_ptr];
  assign ret_pc    = pc_r [ret_ptr];
  assign ret_rdwen = rdwen_r[ret_ptr];
  assign ret_rdfpu = rdfpu_r[ret_ptr];

endmodule

/*                      e203_exu_longwbck                */
module e203_exu_longpwbck(
  //////////////////////////////////////////////////////////////
  // The LSU Write-Back Interface
  input  lsu_wbck_i_valid, // Handshake valid
  output lsu_wbck_i_ready, // Handshake ready
  input  [`E203_XLEN-1:0] lsu_wbck_i_wdat,
  input  [`E203_ITAG_WIDTH -1:0] lsu_wbck_i_itag,
  input  lsu_wbck_i_err , // The error exception generated
  input  lsu_cmt_i_buserr ,
  input  [`E203_ADDR_SIZE -1:0] lsu_cmt_i_badaddr,
  input  lsu_cmt_i_ld, 
  input  lsu_cmt_i_st, 

  //////////////////////////////////////////////////////////////
  // The Long pipe instruction Wback interface to final wbck module
  output longp_wbck_o_valid, // Handshake valid
  input  longp_wbck_o_ready, // Handshake ready
  output [`E203_FLEN-1:0] longp_wbck_o_wdat,
  output [5-1:0] longp_wbck_o_flags,
  output [`E203_RFIDX_WIDTH -1:0] longp_wbck_o_rdidx,
  output longp_wbck_o_rdfpu,
  //
  // The Long pipe instruction Exception interface to commit stage
  output  longp_excp_o_valid,
  input   longp_excp_o_ready,
  output  longp_excp_o_insterr,
  output  longp_excp_o_ld,
  output  longp_excp_o_st,
  output  longp_excp_o_buserr , // The load/store bus-error exception generated
  output [`E203_ADDR_SIZE-1:0] longp_excp_o_badaddr,
  output [`E203_PC_SIZE -1:0] longp_excp_o_pc,
  //
  //The itag of toppest entry of OITF
  input  oitf_empty,
  input  [`E203_ITAG_WIDTH -1:0] oitf_ret_ptr,
  input  [`E203_RFIDX_WIDTH-1:0] oitf_ret_rdidx,
  input  [`E203_PC_SIZE-1:0] oitf_ret_pc,
  input  oitf_ret_rdwen,   
  input  oitf_ret_rdfpu,   
  output oitf_ret_ena,
 
  `ifdef E203_HAS_NICE//{
  input  nice_longp_wbck_i_valid , 
  output nice_longp_wbck_i_ready ,
  input  [`E203_XLEN-1:0]  nice_longp_wbck_i_wdat ,
  input  [`E203_ITAG_WIDTH-1:0]  nice_longp_wbck_i_itag ,
  input  nice_longp_wbck_i_err,
  `endif//}

  input  clk,
  input  rst_n
  );

  // The Long-pipe instruction can write-back only when it's itag 
  //   is same as the itag of toppest entry of OITF
  wire wbck_ready4lsu = (lsu_wbck_i_itag == oitf_ret_ptr) & (~oitf_empty);
  wire wbck_sel_lsu = lsu_wbck_i_valid & wbck_ready4lsu;

  `ifdef E203_HAS_NICE//{
  wire wbck_ready4nice = (nice_longp_wbck_i_itag == oitf_ret_ptr) & (~oitf_empty);
  wire wbck_sel_nice = nice_longp_wbck_i_valid & wbck_ready4nice; 
  `endif//}

  //assign longp_excp_o_ld   = wbck_sel_lsu & lsu_cmt_i_ld;
  //assign longp_excp_o_st   = wbck_sel_lsu & lsu_cmt_i_st;
  //assign longp_excp_o_buserr = wbck_sel_lsu & lsu_cmt_i_buserr;
  //assign longp_excp_o_badaddr = wbck_sel_lsu ? lsu_cmt_i_badaddr : `E203_ADDR_SIZE'b0;

  assign {
         longp_excp_o_insterr
        ,longp_excp_o_ld   
        ,longp_excp_o_st  
        ,longp_excp_o_buserr
        ,longp_excp_o_badaddr } = 
             ({`E203_ADDR_SIZE+4{wbck_sel_lsu}} & 
              {
                1'b0,
                lsu_cmt_i_ld,
                lsu_cmt_i_st,
                lsu_cmt_i_buserr,
                lsu_cmt_i_badaddr
              }) 
              ;
  //////////////////////////////////////////////////////////////
  // The Final arbitrated Write-Back Interface
  wire wbck_i_ready;
  wire wbck_i_valid;
  wire [`E203_FLEN-1:0] wbck_i_wdat;
  wire [5-1:0] wbck_i_flags;
  wire [`E203_RFIDX_WIDTH-1:0] wbck_i_rdidx;
  wire [`E203_PC_SIZE-1:0] wbck_i_pc;
  wire wbck_i_rdwen;
  wire wbck_i_rdfpu;
  wire wbck_i_err ;

  assign lsu_wbck_i_ready = wbck_ready4lsu & wbck_i_ready;

  assign wbck_i_valid =   ({1{wbck_sel_lsu}} & lsu_wbck_i_valid)
                        `ifdef E203_HAS_NICE//{
                        |  ({1{wbck_sel_nice}} & nice_longp_wbck_i_valid)
                        `endif//}
                         ;
  `ifdef E203_FLEN_IS_32 //{
  wire [`E203_FLEN-1:0] lsu_wbck_i_wdat_exd = lsu_wbck_i_wdat;
  `else//}{
  wire [`E203_FLEN-1:0] lsu_wbck_i_wdat_exd = {{`E203_FLEN-`E203_XLEN{1'b0}},lsu_wbck_i_wdat};
  `endif//}
  `ifdef E203_HAS_NICE//{
  wire [`E203_FLEN-1:0] nice_wbck_i_wdat_exd = {{`E203_FLEN-`E203_XLEN{1'b0}},nice_longp_wbck_i_wdat};
  `endif//}
  
  assign wbck_i_wdat  = ({`E203_FLEN{wbck_sel_lsu}} & lsu_wbck_i_wdat_exd )
                        `ifdef E203_HAS_NICE//{
                        | ({`E203_FLEN{wbck_sel_nice}} & nice_wbck_i_wdat_exd )
                        `endif//}
                         ;
  assign wbck_i_flags  = 5'b0
                         ;
  `ifdef E203_HAS_NICE//{
  wire nice_wbck_i_err = nice_longp_wbck_i_err;
  `endif//}

  assign wbck_i_err   = wbck_sel_lsu & lsu_wbck_i_err 
                         ;
  assign wbck_i_pc    = oitf_ret_pc;
  assign wbck_i_rdidx = oitf_ret_rdidx;
  assign wbck_i_rdwen = oitf_ret_rdwen;
  assign wbck_i_rdfpu = oitf_ret_rdfpu;

  // If the instruction have no error and it have the rdwen, then it need to 
  //   write back into regfile, otherwise, it does not need to write regfile
  wire need_wbck = wbck_i_rdwen & (~wbck_i_err);

  // If the long pipe instruction have error result, then it need to handshake
  //   with the commit module.
  wire need_excp = wbck_i_err
                   `ifdef E203_HAS_NICE//{
                   & (~ (wbck_sel_nice & nice_wbck_i_err))   
                   `endif//}
                   ;

  assign wbck_i_ready = 
       (need_wbck ? longp_wbck_o_ready : 1'b1)
     & (need_excp ? longp_excp_o_ready : 1'b1);


  assign longp_wbck_o_valid = need_wbck & wbck_i_valid & (need_excp ? longp_excp_o_ready : 1'b1);
  assign longp_excp_o_valid = need_excp & wbck_i_valid & (need_wbck ? longp_wbck_o_ready : 1'b1);

  assign longp_wbck_o_wdat  = wbck_i_wdat ;
  assign longp_wbck_o_flags = wbck_i_flags ;
  assign longp_wbck_o_rdfpu = wbck_i_rdfpu ;
  assign longp_wbck_o_rdidx = wbck_i_rdidx;

  assign longp_excp_o_pc    = wbck_i_pc;

  assign oitf_ret_ena = wbck_i_valid & wbck_i_ready;

  `ifdef E203_HAS_NICE//{
  assign nice_longp_wbck_i_ready = wbck_ready4nice & wbck_i_ready;
  `endif//}

endmodule
```

综上所述，蜂鸟E203的执行结构是一种混合的策略：

* 单周期指令：顺序发射、顺序执行、顺序写回
* 长指令：顺序发射、乱序执行、顺序写回
* 所有指令混杂：顺序发射、乱序执行、乱序写回

在其中最核心的思想就是取得“更高的性能-面积比”，这套解决思路还是比较巧妙的