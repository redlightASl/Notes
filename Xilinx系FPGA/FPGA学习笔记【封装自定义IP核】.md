# 封装带AXI接口的自定义IP核

为了更方便地使用外部接口驱动或进行系统级的设计时，可以考虑将RTL设计打包制作成自定义的IP核，Vivado会自动生成相关的IP核接口；或者为了在ZYNQ中使用AXI总线将硬核与FPGA硬件部分互联，可以将FPGA部分的RTL设计打包成自定义IP核，Vivado会自动将生成的IP核的接口制作好，使用图形化界面就能快速实现SoC设计。特别地，可以使用这种方法在硬核外挂载软核

在Vivado的设计思想中，一个IP核就相当于一个函数，可以通过重用IP核做到模块化设计的效果

可以参考Xilinx Vivado封装自定义IP参考手册【代号ug1118】来获得更详细的操作指示

第一部分仅说明带AXI接口的自定义IP核封装方法

## 创建与封装自定义IP的意义

在Vivado中含有一个IP Catalog流程，可以将下列源文档封装成自定义的IP

* RTL级HDL源文件
* 模拟模型文件
* 示例设计文件
* Testbench
* 项目文件目录
* Block Design

同时Vivado也内置了Xilinx自制IP、第三方IP、用户定义IP的库

比起传统“Add Module”将RTL代码以中间级模块的方式例化添加到顶层模块，再封装出统一的顶层模块这样的操作流程，通过可视化的IP核管理可以更快速地实现项目模块化和后期完善修改流程

## 创建自定义IP

示例程序使用自定义的IP实现LED呼吸灯效果

这个IP使用AXI接口与ZYNQ的硬核连接，可以使用软件控制IP核的“外设控制寄存器”来对自定义IP核的工作状况进行控制

### 创建IP工程

为了更好管理自定义IP核，通常将用户的RTL代码统一管理在独立目录下

在Vivado开始界面选择【Tasks】-【Manage IP】，选择新建一个IP核管理目录或打开已有目录，并新建项目

根据自己的硬件设备和习惯使用的HDL选择针对性的选项

完成创建后，选择【Tools】-【Create and Package New IP】

![image-20210511132753582](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511132753582.png)

如果准备创建一个单独的IP，可以直接Next，相关内容在下一部分介绍；在这里因为准备创建的项目需要使用到AXI4接口与硬核交互，所以选择最后这个选项

设置IP核名称后如下图进行AXI接口设置

![image-20210511162506573](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511162506573.png)

其中AXI接口有三种类型：

* Lite：适合数据量较小、速度较快的信号传输
* Full：全规格的AXI总线，适合标准类型的数据传输
* Stream：数据流传输，适合音视频信号等大规模数据的高速传输

还有两种模式：

* Slave：从模式，IP接受外部数据控制
* Master：主模式，IP控制外部设备

完成设置后可以看到右侧User Repository中出现了自定义IP核

![image-20210511162609747](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511162609747.png)

这里右键IP核，选择【Edit in IP Packager】，之后Vivado会打开一个新界面用于管理IP核的RTL代码

自动生成的RTL代码分为两部分，一个是顶层模块，另一个是AXI总线接口逻辑；RTL代码中还默认生成了AXI总线相关逻辑的例化和提供给用户使用的区域（包括**自定义参数**、**自定义端口**、**自定义顶层模块例化**），但是需要注意：如果在AXI总线上开辟了独立的新端口，需要将相关代码单独添加到AXI总线逻辑的RTL代码中

### 编写IP内部RTL代码

顶层例化代码如下所示：

```verilog
`timescale 1 ns / 1 ps

	module breath_LED_IP_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Parameters of Axi Slave Bus Interface S0_AXI
		parameter integer C_S0_AXI_DATA_WIDTH	= 32,
		parameter integer C_S0_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line
        
		// Ports of Axi Slave Bus Interface S0_AXI
		input wire  s0_axi_aclk,
		input wire  s0_axi_aresetn,
		input wire [C_S0_AXI_ADDR_WIDTH-1 : 0] s0_axi_awaddr,
		input wire [2 : 0] s0_axi_awprot,
		input wire  s0_axi_awvalid,
		output wire  s0_axi_awready,
		input wire [C_S0_AXI_DATA_WIDTH-1 : 0] s0_axi_wdata,
		input wire [(C_S0_AXI_DATA_WIDTH/8)-1 : 0] s0_axi_wstrb,
		input wire  s0_axi_wvalid,
		output wire  s0_axi_wready,
		output wire [1 : 0] s0_axi_bresp,
		output wire  s0_axi_bvalid,
		input wire  s0_axi_bready,
		input wire [C_S0_AXI_ADDR_WIDTH-1 : 0] s0_axi_araddr,
		input wire [2 : 0] s0_axi_arprot,
		input wire  s0_axi_arvalid,
		output wire  s0_axi_arready,
		output wire [C_S0_AXI_DATA_WIDTH-1 : 0] s0_axi_rdata,
		output wire [1 : 0] s0_axi_rresp,
		output wire  s0_axi_rvalid,
		input wire  s0_axi_rready
	);
// Instantiation of Axi Bus Interface S0_AXI
	breath_LED_IP_v1_0_S0_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S0_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S0_AXI_ADDR_WIDTH)
	) breath_LED_IP_v1_0_S0_AXI_inst (
		.led(led),
		.S_AXI_ACLK(s0_axi_aclk),
		.S_AXI_ARESETN(s0_axi_aresetn),
		.S_AXI_AWADDR(s0_axi_awaddr),
		.S_AXI_AWPROT(s0_axi_awprot),
		.S_AXI_AWVALID(s0_axi_awvalid),
		.S_AXI_AWREADY(s0_axi_awready),
		.S_AXI_WDATA(s0_axi_wdata),
		.S_AXI_WSTRB(s0_axi_wstrb),
		.S_AXI_WVALID(s0_axi_wvalid),
		.S_AXI_WREADY(s0_axi_wready),
		.S_AXI_BRESP(s0_axi_bresp),
		.S_AXI_BVALID(s0_axi_bvalid),
		.S_AXI_BREADY(s0_axi_bready),
		.S_AXI_ARADDR(s0_axi_araddr),
		.S_AXI_ARPROT(s0_axi_arprot),
		.S_AXI_ARVALID(s0_axi_arvalid),
		.S_AXI_ARREADY(s0_axi_arready),
		.S_AXI_RDATA(s0_axi_rdata),
		.S_AXI_RRESP(s0_axi_rresp),
		.S_AXI_RVALID(s0_axi_rvalid),
		.S_AXI_RREADY(s0_axi_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
```

默认生成的顶层代码大同小异，无非是AXI总线有无的区别

这里省略AXI总线逻辑代码（太长了）

注意改动代码时如果涉及到接口，需要同时修改顶层代码和AXI总线实现

其中比较常用的部分已经被Vivado自动空出来，如下所示：

```verilog
//在开头有这四行代码
	// Users to add parameters here
//中间可以存放自定义的参数
	// User parameters ends
	......
	// Users to add ports here
//中间可以存放自定义的端口代码
	// User ports ends
	......
//在末尾有这两行代码
	// Add user logic here
//中间就可以存放自定义的模块顶层例化代码
	// User logic ends
```

右键点击【Design Sources】，选择添加新的HDL文件，编写呼吸灯控制代码，如下所示，并保存

```verilog
module breath_led(
    input          clk            , //时钟信号
    input          _rst           , //复位信号
    input          sw_ctrl        , //控制寄存器：呼吸灯开关控制信号 1：亮 0:灭
    input          led_en         , //控制寄存器：设置呼吸灯频率设置使能信号
    input   [9:0]  set_freq_step  , //控制寄存器：设置呼吸灯频率变化步长
    
    output         led              //输出引脚，控制LED
);

parameter  START_FREQ_STEP = 10'd100; //设置频率步长初始值

reg  [15:0]  period_cnt  ;      //周期计数器
reg  [9:0]   freq_step   ;      //呼吸灯频率间隔步长
reg  [15:0]  duty_cycle  ;      //设置高电平占空比的计数点
reg          inc_dec_flag;      //用于表示高电平占空比的计数值,是递增还是递减
                                //为1时表示占空比递减,为0时表示占空比递增
wire         led_t       ;

//将周期信号计数值与占空比计数值进行比较，以输出驱动led的PWM信号
assign led_t = ( period_cnt <= duty_cycle ) ? 1'b1 : 1'b0 ;
assign led = led_t & sw_ctrl;

//周期信号计数器在0-50_000之间计数
always @ (posedge clk)
begin
    if (!_rst)
        period_cnt <= 16'd0;
    else if(!sw_ctrl)
        period_cnt <= 16'd0;
    else if( period_cnt == 16'd50_000 )
        period_cnt <= 16'd0;
    else
        period_cnt <= period_cnt + 16'd1;
end

//设置频率间隔
always @(posedge clk)
begin
    if(!_rst)
        freq_step <= START_FREQ_STEP;
    else if(led_en)
    begin
        if(set_freq_step == 0)
            freq_step <= 10'd1;
        else if(set_freq_step >= 10'd1_000)
            freq_step <= 10'd1_000;
        else    
            freq_step <= set_freq_step;
    end        
end

//设定高电平占空比的计数值
always @(posedge clk)
begin
    if (_rst == 1'b0)
    begin
        duty_cycle <= 16'd0;
        inc_dec_flag <= 1'b0;
    end  
    else if(!sw_ctrl)
    begin
        duty_cycle <= 16'd0; //呼吸灯开关关闭时，信号清零
        inc_dec_flag <= 1'b0;
    end
    else if(period_cnt == 16'd50_000) //每次计数完了一个周期，就调节占空比计数值
    begin
        if(inc_dec_flag) //占空比递减
        begin
            if(duty_cycle == 16'd0)     
                inc_dec_flag <= 1'b0;
            else if(duty_cycle < freq_step)
                duty_cycle <= 16'd0;
            else    
                duty_cycle <= duty_cycle - freq_step;
    	end
    	else
        begin //占空比递增
           	if(duty_cycle >= 16'd50_000)
                inc_dec_flag <= 1'b1;
            else
                duty_cycle <= duty_cycle + freq_step;
        end 
    end
    else
        duty_cycle <= duty_cycle; //未计数完一个周期时，占空比保持不变
end
  
endmodule
```

在Vivado自动生成的AXI总线逻辑文件中如下编写例化：

```verilog
// Users to add parameters here
		parameter  START_FREQ_STEP = 10'd100, //参数设置
// User parameters ends

// Users to add ports here
		output led, //LED端口
// User ports ends

// Add user logic here
	breath_led #(
		.START_FREQ_STEP (START_FREQ_STEP) //例化参数
	)
	u_breath_led(
		.clk          	 (S_AXI_ACLK),		//时钟信号
		._rst         	 (S_AXI_ARESETN),	//复位信号
		.sw_ctrl      	 (slv_reg0[0]),		//AXI信号线0最低位为控制信号
		.led_en       	 (slv_reg1[31]),	//AXI信号线1最高位为使能信号
		.set_freq_step	 (slv_reg1[9:0]),	//AXI信号线1第10位表示步长
		.led			 (led)				//输出信号
	);
// User logic ends
```

在Vivado自动生成的顶层文件中如下编写例化：

```verilog
// Users to add parameters here
		parameter  START_FREQ_STEP = 10'd100, //初始参数值
// User parameters ends

// Users to add ports here
		output led, //LED输出端口例化
// User ports end

breath_LED_IP_v1_0_S0_AXI # ( 
		.START_FREQ_STEP(START_FREQ_STEP),  //例化参数默认值
		.C_S_AXI_DATA_WIDTH(C_S0_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S0_AXI_ADDR_WIDTH)
	) breath_LED_IP_v1_0_S0_AXI_inst (
		.led(led), //例化LED输出端口
		.S_AXI_ACLK(s0_axi_aclk),
		.S_AXI_ARESETN(s0_axi_aresetn),
		.S_AXI_AWADDR(s0_axi_awaddr),
		.S_AXI_AWPROT(s0_axi_awprot),
		.S_AXI_AWVALID(s0_axi_awvalid),
		.S_AXI_AWREADY(s0_axi_awready),
		.S_AXI_WDATA(s0_axi_wdata),
		.S_AXI_WSTRB(s0_axi_wstrb),
		.S_AXI_WVALID(s0_axi_wvalid),
		.S_AXI_WREADY(s0_axi_wready),
		.S_AXI_BRESP(s0_axi_bresp),
		.S_AXI_BVALID(s0_axi_bvalid),
		.S_AXI_BREADY(s0_axi_bready),
		.S_AXI_ARADDR(s0_axi_araddr),
		.S_AXI_ARPROT(s0_axi_arprot),
		.S_AXI_ARVALID(s0_axi_arvalid),
		.S_AXI_ARREADY(s0_axi_arready),
		.S_AXI_RDATA(s0_axi_rdata),
		.S_AXI_RRESP(s0_axi_rresp),
		.S_AXI_RVALID(s0_axi_rvalid),
		.S_AXI_RREADY(s0_axi_rready)
	);
```

编辑完成后即可退回原菜单

点击左侧流程中的【Run Synthesis】即可进行IP核的综合

### 设置IP的可视化界面

打开xml文件后即可在Vivado中进行编辑，

按顺序设置即可

其中在【Customization Parameters】菜单下会出现“更新参数”的选项提示，更新后会现多出一行自定义的参数，双击它如下图进行设置，即可将这个参数反映到IP可视化界面

![image-20210511201028511](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511201028511.png)

完成所有设置并确认无误后，即可在最后选项【Review and Package】中点击【Re-Package IP】即可封装IP

关闭项目后可以在原来的Vivado窗口中看到如下显示

![image-20210511201745806](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511201745806.png)

证明完成了IP封装

## 使用自定义IP

### 硬件部分

完成封装IP后，在任意工程中点击左侧【IP INTERGRATOR】-【Create Block Design】创建基于IP核的FPGA设计

但此时IP选项列表中没有自定义IP核，需要自己将IP核添加到工程

选择【Tools】-【Settings】-【IP】-【Repository】-【Add（加号+）】选择存放自定义IP的文件目录，即可将自定义的IP核添加到项目

如下图对IP核进行设置

![image-20210511204531656](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511204531656.png)

设置ZYNQ系统的DDR控制器和外设后，先进行自动生成原理图，再进行自动布线即可

注意要在led引脚处右键选择【Make External】生成一个引出的外部引脚，并将其改名为led

**生成外部引脚的过程就是使能逻辑块与IO块连接的过程**

接下来按照正常步骤生成硬件平台配置

由于led端口连接到PL部分，所以需要进行管脚约束才能使用

点击左侧综合按钮，综合后打开引脚设置（I/O Ports），将led_0的引脚映射到PL部分MIO上

根据手头的开发板选择引出引脚即可

![image-20210511210615915](F:\Git_repository\Notes\Xilinx系FPGA\FPGA学习笔记【封装自定义IP核】.assets\image-20210511210615915.png)

这里选用的是PL Bank的P15引脚

最后生成比特流并导出到硬件即可

### 软件部分

还是原来的步骤从.xsa文件导入配置到Vitis，并创建一个新应用程序

使用的软件代码如下所示

总体思路就是读写外设寄存器映射来的地址对外设寄存器进行操作

```c
#include "stdio.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "breath_led_ip.h"
#include "xil_io.h"
#include "sleep.h"

#define  LED_IP_BASEADDR   XPAR_BREATH_LED_IP_0_S0_AXI_BASEADDR
#define  LED_IP_REG0       BREATH_LED_IP_S0_AXI_SLV_REG0_OFFSET
#define  LED_IP_REG1       BREATH_LED_IP_S0_AXI_SLV_REG1_OFFSET

int main()
{
	int freq_flag;
    int led_state;

	xil_printf("LED User IP Test!\n");
    while(1)
    {
		if(freq_flag == 0)
     	{
    		BREATH_LED_IP_mWriteReg(LED_IP_BASEADDR,LED_IP_REG1,0x800000ef);
        	freq_flag = 1;
     	}
    	else
     	{
    	 	BREATH_LED_IP_mWriteReg(LED_IP_BASEADDR,LED_IP_REG1,0x8000002f);
         	freq_flag = 0;
     	}
     	led_state = BREATH_LED_IP_mReadReg(LED_IP_BASEADDR,LED_IP_REG0);

     	if(led_state == 0)
     	{
    	 	BREATH_LED_IP_mWriteReg (LED_IP_BASEADDR, LED_IP_REG0, 1);
         	xil_printf("Breath LED ON\n");
     	}
     	sleep(5);
     	led_state = BREATH_LED_IP_mReadReg(LED_IP_BASEADDR,LED_IP_REG0);
     	
        if(led_state == 1)
     	{
    	 	BREATH_LED_IP_mWriteReg (LED_IP_BASEADDR, LED_IP_REG0, 0);
         	xil_printf("Breath LED OFF\n");
     	}
     	sleep(1);
 	}
}
```

烧录后LED呈呼吸灯效果，且可以看到呼吸灯闪烁频率变化

# 封装不带AXI接口的IP核

Vivado支持将独立的RTL代码封装为IP核，方便以类似函数的方式重用IP核，同时可使用用户自定义的IP核接口协议

参考【ug1118】手册来获取详细信息

## 创建自定义IP

### IP核逻辑封装

1. 创建一个RTL工程
2. 编辑IP核的RTL代码
3. 验证IP核逻辑并进行仿真
4. 创建一个基于已有RTL代码的IP核封装
5. 修改顶层文件
6. 设置IP核端口和控制引脚端口输入输出模式（端口映射）
7. 修改IP核的可视化界面配置进行封装
8. 创建接口定义

### 接口封装

1. 编辑接口协议的RTL实现
2. 在IP核封装完成后在配置接口定义部分对接口进行相关设置
3. 依次调整接口协议封装
4. 添加接口协议的RTL文件
5. 进行接口RTL文件的顶层文件端口映射
6. 点击【Package IP】完成IP核封装

### 使用自定义IP核

封装好的IP核如果出现适用设备相关的错误，可以直接删除对应的封装信息

使用IP核前需要先对IP核进行验证，可以选择编写testbench（普普通通的ZYNQ-7020板子配那么小的LUT规模直接烧就完事了！），也可以直接烧录到开发板（如果开发板很贵就别这样干了）

IP核验证完毕后就可以随意使用了

### 封装IP核时可能遇到的问题

1. 封装的IP核中包含了其他IP核

   如果包含了.xci文件（IP核的配置文件），Vivado会直接用新生成的子IP创建输出文件

   如果包含IP核的输出文件，Vivado则会从IP设置中生成HDL和XDC代码

   封装时推荐直接使用包含.xci文件的方式打包IP核，这样会方便重用IP和生成输出文件

   只要在打包当前IP的时候选择相关选项即可

2. 如果在封装前分配好了引脚约束应该怎么办

   一般来说使用IP核的时候再进行引脚约束的过程会把之前的引脚约束覆盖掉

   但是为了保证不出错，一般在打包前或打包后将IP核的.xdc文件删除