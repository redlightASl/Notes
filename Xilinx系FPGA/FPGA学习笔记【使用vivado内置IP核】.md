# 时钟IP核的使用

Vivado内置了使用FPGA中时钟资源实现的时钟IP核，可以实现分频、倍频、调节相位、控制占空比等功能

可以使用时钟IP核对内/对外输出不同频率的时钟信号

## FPGA时钟资源

Xilinx的7系列FPGA都配置了专用的**全局**时钟和**区域**时钟资源

**CMT**（Clock Management Tiles时钟管理片）提供时钟合成（Clock frequency synthesis）、倾斜校正（deskew）、抖动过滤（jitter filtering）的功能。1个CMT中包括1个MMCM混合时钟管理电路和1个PLL锁相环电路

不同的FPGA包含的CMT数量不一样

FPGA中的CMT被分为了多个时钟区域（Clock Region），时钟区域可以单独工作，也可以通过全局时钟线主干道（Clock Backbone）和水平时钟线（HROW）统一调配资源共同工作

## FPGA时钟IP核的使用

在【IP Catalog】搜索clock出现`clock wizard`，双击即可进行设置

配置好自定义选项后生成IP核代码，打开IP视图可以找到示例的例化代码，将其复制到顶层模块，在顶层模块中加入IP核相关代码的例化就可以使用IP核了。

主要能使用的选项是

* PLL与MMCM选择

    分别对应FPGA内部的PLL和MMCM资源

    PLL是模拟电路实现，相对于MMCM产生时钟的频率更加精准，而且时钟抖动过滤效果也更好；但PLL无法动态调整相位

    MMCM（Mix Mode Clock Manager混合模式时钟管理器）实际上就是PLL+DCM相移功能的结合体——这是一个PLL，加上了DCM的一小部分以进行精细的相移（这就是它被称为混合模式的原因：PLL是模拟电路，但是DCM使用数字方法实现相移）

* 抖动设置：设置优化目标是“减小输出抖动”还是“加大输入抖动抑制”

* 时钟特性设置

* 输入时钟频率和输出时钟频率

# RAM IP核的使用

Xilinx家的FPGA自带称为**块RAM**（Block RAM）的片上资源，根据具体器件型号不同具有各种各样的配置数量

这些块RAM实际上使用FPGA内部的配置RAM实现，它们本来用于存储FPGA的控制块配置并供LUT存储数据使用，但是通过特殊的内部指令可以将它们汇总成为具有一般RAM功能的片上资源。

而LUT本身是基于RAM的，因此也可以“积少成多”用于RAM，它被称为**Distributed Memory**

只要使用Vivado内置的IP核就可以将块RAM加入自己的设计中

## RAM IP核的使用

点击【IP Catalog】-搜索【RAM】-【Memories & storage Elements】

可以看到两个和RAM有关的创建入口

* Distributed Memory Generator：使用LUT实现RAM IP
* Block Memory Generator：使用块RAM实现RAM IP

用户可以根据自己的需求选择不同的入口，消耗不同的片上资源创建RAM IP

1. 选择接口类型为Native（常规接口）
2. RAM类型为Simple Dual Port RAM，简单双口RAM（也可以根据需要配置为其他类型）
3. 选择输入端口位宽，设置输入深度
4. 选择是否使用使能控制信号
5. 配置输出端口位宽、是否使用输出寄存器（Latch），注意输出端口深度是由输入端口深度和位宽决定的

之后正常调用生成的模块即可

# FIFO IP核的使用

FIFO就是**队列**的硬件实现，分为*同步*和*异步*两种

同步FIFO读写端的时钟是同步的，因此可以实现一边读一边写

异步FIFO读写端使用不同的时钟，因此不能一边读一边写，但是异步FIFO常常用作跨时钟域传输信号——实际上也只有用异步FIFO才能在两个不同频率时钟域之间实现信号传输

**FIFO是使用触发器级联实现的**，这就导致同步FIFO在高速情形下具有不稳定性，因为内部的触发器具有一定的响应时间（建立时间、保持时间），如果外部时钟过快，内部数据来不及变化就要输出，就会导致亚稳态发送

## FIFO和RAM

FIFO和RAM都可以存储数据，并且都具有控制读写的信号；但是FIFO没有内部地址，只能以先入先出的形式读写数据，它的读写可以同时进行；而且如果FIFO满，那么就不能再写入数据，需要先将队头数据读出才能继续写入，否则电路会在此卡死，同理如果FIFO空，它也不能再读出新数据；

## 异步FIFO的Verilog实现

下面是一个典型的异步FIFO实现

作者使用了 **加两级寄存器同步 + 格雷码**的方法尽可能消除亚稳态，做到严谨的异步高速数据传递

转载自https://blog.csdn.net/u012357001/article/details/89945457

```verilog
module fifo_async#(
                 parameter   data_width = 16,
                 parameter   data_depth = 256,
                 parameter   addr_width = 8
)
(
                  input                           rst,
                  input                           wr_clk,
                  input                           wr_en,
                  input      [data_width-1:0]     din,         
                  input                           rd_clk,
                  input                           rd_en,
                  output reg                     valid,
                  output reg [data_width-1:0]     dout,
                  output                          empty,
                  output                          full
    );


reg    [addr_width:0]    wr_addr_ptr;//地址指针，比地址多一位，MSB用于检测在同一圈
reg    [addr_width:0]    rd_addr_ptr;
wire   [addr_width-1:0]  wr_addr;//RAM 地址
wire   [addr_width-1:0]  rd_addr;

wire   [addr_width:0]    wr_addr_gray;//地址指针对应的格雷码
reg    [addr_width:0]    wr_addr_gray_d1;
reg    [addr_width:0]    wr_addr_gray_d2;
wire   [addr_width:0]    rd_addr_gray;
reg    [addr_width:0]    rd_addr_gray_d1;
reg    [addr_width:0]    rd_addr_gray_d2;


reg [data_width-1:0] fifo_ram [data_depth-1:0];

//=========================================================write fifo 
genvar i;
generate 
for(i = 0; i < data_depth; i = i + 1 )
begin:fifo_init
always@(posedge wr_clk or posedge rst)
    begin
       if(rst)
          fifo_ram[i] <= 'h0;//fifo复位后输出总线上是0，并非ram中真的复位。可无
       else if(wr_en && (~full))
          fifo_ram[wr_addr] <= din;
       else
          fifo_ram[wr_addr] <= fifo_ram[wr_addr];
    end   
end    
endgenerate    
//========================================================read_fifo
always@(posedge rd_clk or posedge rst)
   begin
      if(rst)
         begin
            dout <= 'h0;
            valid <= 1'b0;
         end
      else if(rd_en && (~empty))
         begin
            dout <= fifo_ram[rd_addr];
            valid <= 1'b1;
         end
      else
         begin
            dout <=   'h0;//fifo复位后输出总线上是0，并非ram中真的复位，只是让总线为0；
            valid <= 1'b0;
         end
   end
assign wr_addr = wr_addr_ptr[addr_width-1-:addr_width];
assign rd_addr = rd_addr_ptr[addr_width-1-:addr_width];
//=============================================================格雷码同步化
always@(posedge wr_clk )
   begin
      rd_addr_gray_d1 <= rd_addr_gray;
      rd_addr_gray_d2 <= rd_addr_gray_d1;
   end
always@(posedge wr_clk or posedge rst)
   begin
      if(rst)
         wr_addr_ptr <= 'h0;
      else if(wr_en && (~full))
         wr_addr_ptr <= wr_addr_ptr + 1;
      else 
         wr_addr_ptr <= wr_addr_ptr;
   end
//=========================================================rd_clk
always@(posedge rd_clk )
      begin
         wr_addr_gray_d1 <= wr_addr_gray;
         wr_addr_gray_d2 <= wr_addr_gray_d1;
      end
always@(posedge rd_clk or posedge rst)
   begin
      if(rst)
         rd_addr_ptr <= 'h0;
      else if(rd_en && (~empty))
         rd_addr_ptr <= rd_addr_ptr + 1;
      else 
         rd_addr_ptr <= rd_addr_ptr;
   end

//========================================================== translation gary code
assign wr_addr_gray = (wr_addr_ptr >> 1) ^ wr_addr_ptr;
assign rd_addr_gray = (rd_addr_ptr >> 1) ^ rd_addr_ptr;

assign full = (wr_addr_gray == {~(rd_addr_gray_d2[addr_width-:2]),rd_addr_gray_d2[addr_width-2:0]}) ;//高两位不同
assign empty = ( rd_addr_gray == wr_addr_gray_d2 );

endmodule
```

推荐阅读《Verilog数字系统设计教程》（夏宇闻老师的经典著作），其中展示了一个非常经典的基于SRAM的FIFO设计

笔者能力有限，还处于学习阶段，暂时做不出这样优秀的硬件设计，因此不再多写

## FIFO IP核的使用

Vivado中提供了FIFO的IP核供开发者使用，用户只要选择【IP Catalog】-搜索【fifo】-【Memories & storage Elements】，选择下方的【FIFO Generate】就可以进行可视化配置

1. 修改FIFO名称
2. 选择Native类型FIFO接口
3. 选择【Independent Clock Block RAM】（独立时钟块RAM）实现FIFO（FIFO Implementation选项）
4. Read Mode选择【First Word Fall Through】
5. 设置输入数据尾款、读数据位宽、FIFO深度（注意FIFO深度必须是2的n次幂）
6. 选择是否使用Reset控制复位、状态标志位、数据计数位等设置

最后直接点击OK即可通过FPGA内部的块RAM资源实现FIFO，可以达到比直接使用Verilog调用块RAM实现FIFO更高的效率

如果还想要更高效的FIFO实现，可以考虑专门使用Verilog配合Xilinx的Tcl语句优化

FIFO IP核可以配置成同步或异步，并快速加入SoC设计
