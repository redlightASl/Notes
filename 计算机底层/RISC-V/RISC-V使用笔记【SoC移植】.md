# 蜂鸟E203及配套SoC移植

蜂鸟E203的移植流程并不复杂，基本就是【复制rtl源文件】-【用对应厂商的时序约束和物理约束进行修改】-【用对应厂商的工具综合实现】这老三样，但是由于蜂鸟的时钟系统相对复杂且整体SoC在FPGA和IC上的实现不同，所以时序约束并不好修改，笔者在进行移植过程中还面临JTAG失灵的问题，这里提出笔者尝试移植的思路供读者参考

## 标准移植步骤

自己看官网、E203的书和网上教程罢！

这东西到处都有，买他家的开发板就可以直接一步make完成部署

## 丐版移植步骤

穷b学生哪买得起那【嵌入式粗口】贵上天的板子，想办法搞一块片上LUT资源大于20k，有PLL块的FPGA来做移植吧！

这里使用的两个方案

* Perf-V

  一个初创企业澎峰科技做的板子，看起来还不错，官方支持E203的移植，相对比较方便

  预算700：开发板600+烧录器100

* ZYNQ7020开发板

  一块ZYNQ开发板能学STM32（嵌入式开发）+树莓派（嵌入式Linux）+FPGA（内部资源能顶Artix7，还是-2速度等级的！），价格贵了点，但是四舍五入省了好多钱（确信）

  单纯使用ZYNQ的PL端资源完全能移植E203，甚至还能富裕一大堆资源写个硬件加速挂到EAI上面

  最丐的版本就是闲鱼矿板，50包邮，但是入手难度大上天，能把那玩意从头到脚玩明白了那就是从PCB到片上设计都会的dalao

  常见的丐板围绕500RMB浮动

  比较高级点的就是1k左右的那些，比如官方的PYNQ-Z1、Z2还有ALINX那几套入门板

  到2k左右的板子就很高级了，不符合穷b学生垃圾佬定位，所以不推荐（有那钱都能买官方板子了）

移植到ZYNQ上难度比较大，不过一通百通，做完以后在其他设备上移植就没什么难度了

下面分两个移植部分来说明

## Perf-V半官方版

Perf-V提供了官方的移植包，只要按部就班烧录即可，这里只做简述，重点放在下面的zynq移植上

### 标准移植步骤

这个开发板的官方基于Vivado的工程模式给出了全套工程文件，对应自己的开发板找到源文件，分别修改：

* 时钟引脚
* 分频器
* 时序约束

需要说明：蜂鸟的rtl文件只是SoC的部分，不包含时钟和GPIO，需要使用FPGA的时钟输入到SoC，并通过FPGA的IO实现GPIO功能，最顶层的文件以system.v命名，可以复制原工程的system并在上面修改

时钟引脚要参考开发板的原理图，Perf-V板子上只有一个50MHz的晶振可用，对应找到引脚，确认一下引脚约束即可

分频器部分要分别实现一个50MHz转16MHz分频器供给CPU和一个16MHz转32.768kHz分频器供给SoC，分别通过SoC的两个时钟输入`clk_16M`和`slowclk`接入，需要注意修改官方分频器实现

```verilog
module clkdivider
(
  	input wire clk,
  	input wire reset,
  	output reg clk_out
);
  	reg [7:0] counter;

    always @(posedge clk) begin
        if (reset) begin
      		counter <= 8'd0;
      		clk_out <= 1'b0;
    	end
    	
        //官方把这里的分频系数改了一下，用户需要按照需要修改
        //else if (counter == 8'hff)
        else if (counter == 8'h7f) begin
      		counter <= 8'd0;
      		clk_out <= ~clk_out;
    	end
    	else begin
      		counter <= counter+1;
    	end
  	end
endmodule
```

在Perf-V版本中还包含了`clk_8388`这个信号用于在16MHz和32.768kHz之间桥接，上面的256分频器就是用于把8.388MHz时钟转换成32.768kHz的。

时序约束部分则需要保证xc7a50t使用

```tcl
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK50MHZ]
```

period后面的数字代表时钟周期，片外时钟不应超过50MHz

## ZYNQ省钱版

由于笔者手头性能最好的FPGA就是Zynq-7020，所以这里简述一下在Zynq上完好地移植蜂鸟E203 SoC

### 编写分频器模块

Zynq板子上的晶振和官方开发板的晶振频率不一致，需要使用分频器来获取SoC需要的32.768kHz和16MHz时钟

Zynq板载50MHz晶振，笔者选择了通过Xilinx的mmcm ip实现50MHz-16MHz转换，**不使用**另一个mmcm实现16MHz-8.388MHz转换，通过一个自己写的分频器实现16MHz-32.768kHz的转换

因为如果使用16MHz-8.388MHz转换，**需要分别在Vivado内使用IP Catalog例化两个mmcm**，导致后续的时序要求无法满足

自己写的分频器则使用了*488分频*，实现如下

```verilog
module divide (
    input   wire clk,
    input   wire rst_n,
    output  reg clkout
);
    
    reg [7:0] counter;
    
    always @(posedge clk) begin
        if (rst_n) begin
            counter <= 8'd0;
            clkout  <= 1'b0;
        end
        // else if (counter == 8'h7f) begin
        else if (counter == 8'hf4) begin
            counter <= 8'd0;
            clkout  <= ~clkout;
        end
        else begin
            counter <= counter+1;
        end
    end
endmodule
```

### 重写引脚顶层模块

复制原工程中的rtl文件到自己的Vivado工程，并使用原工程中FPGA/ddr/下面的system.v文件进行修改

主要更改了时钟总线和SoC的连接，并且通过IP Catalog例化一个复位模块接入SoC，如下所示：

```verilog
mmcm ip_mmcm
(
    .resetn(ck_rst),
    .clk_in1(CLK50MHZ),
    .clk_out1(clk_16M), //16MHz clock
    .clked(mmcm_locked)
);

assign ck_rst = fpga_rst & mcu_rst;

divide div
(
    .clk(clk_16M),
    .rst_n(ck_rst),
    .clkout(CLK32768KHZ)
);

reset_sys ip_reset_sys
(
    .slowest_sync_clk(clk_16M),
    .ext_reset_in(ck_rst), //Active low
    .aux_reset_in(1'b1),
    .mb_debug_sys_rst(1'b0),
    .dcm_locked(mmcm_locked),
    .mb_reset(),
    .bus_struct_reset(),
    .peripheral_reset(reset_periph),
    .interconnect_aresetn(),
    .peripheral_aresetn()
);
```

这里的`reset_sys`模块就是从Xilinx IP中例化的复位模块，需要改动的部分只有其中的`mmcm_locked`和`clk_16M`——这两个引脚。divide模块就是自己实现的分频器，这里的`CLK32768KHZ`总线就是用于输入SoC的低频时钟

### 修改QSPI接口







### 修改预设Flash大小







### 修改mcs配置对应的Flash









### 重封装顶层模块









### 配置管脚约束



