# GPIO的FPGA实现

> 通过调用FPGA厂商提供的IO原语可以部分实现GPIO功能

GPIO的基本功能如下：

* 只读的读寄存器和可读写的写寄存器
* 可控的内部上拉/下拉
* 可编程的复用功能

GPIO需要实现的高级功能如下：

* 推挽/开漏输出功能
* 浮空/模拟输出状态
* 多路复用选择器
* 相对良好的读写时序
* 高速翻转状态

下面给出一个可用的GPIO rtl设计

## 关键逻辑

这里选择实现了一个端口数可变的GPIO，支持

* 开漏输出
* 锁存输入
* 输入数字采样
* 端口复用

由于使用FPGA部署，因此模拟输出和高速翻转就无法实现了

> 模拟输出功能需要用到模拟电路，而FPGA内部的模拟电路需要专用的ADC通道，无法以RTL形式布局布线，因此无法实现。高速翻转功能需要用到高速时钟PLL，笔者使用的xc7z010能实现的最高速度IO大约在300MHz左右，能够达到MCU GPIO的平均水平，但较高速SoC的IO仍有差距

首先看一下端口

```verilog
`timescale 1ns/1ps

module gpio #(
           parameter GPIO_PORT_NUM = 32
       )(
           input wire sys_clk,
           input wire sys_rst_n,

           input wire [GPIO_PORT_NUM - 1: 0] ctrl_in_sel, //0, out; 1, in(hi-z)
           input wire [GPIO_PORT_NUM - 1: 0] ctrl_af_sel, //0, normal-io; 1, alter-function
           input wire [GPIO_PORT_NUM - 1: 0] ctrl_od_sel, //0, push-pull; 1, open-drain
           input wire [GPIO_PORT_NUM - 1: 0] ctrl_lo_sel, //0, no input latch; 1, input latch

           input wire [GPIO_PORT_NUM - 1: 0] gpio_af_io, //connect to alter-function module
           input wire [GPIO_PORT_NUM - 1: 0] gpio_output_val, //output data register, wr
           output reg [GPIO_PORT_NUM - 1: 0] gpio_input_val, //input data register, r

           input wire [GPIO_PORT_NUM - 1: 0] io_pin_in, //input pin
           output reg [GPIO_PORT_NUM - 1: 0] io_pin_out, //output pin
           output reg [GPIO_PORT_NUM - 1: 0] io_pin_oe //io select pin
       );
```

大致功能都在注释中强调了，需要注意的是IO口使用了三个引脚引出：`io_pin_in`是输入引脚，`io_pin_out`为输出引脚，`io_pin_oe`为输出使能引脚。这三个引脚需要被连接到顶层模块的三态门端口来完成GPIO

三态门原语如下

```verilog
IOBUF #(
    .DRIVE (12 ), // Specify the output drive strength
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD ("DEFAULT" ), // Specify the I/O standard
    .SLEW ("SLOW" ) // Specify the output slew rate
)
IOBUF_inst (
    .O ( io_pin_out[i] ), // Buffer output
    .IO ( io_pin_io[i] ), // Buffer inout port (connect directly to top-level port)
    .I ( io_pin_in[i] ), // Buffer input
    .T ( ~io_pin_oe[i] ) // 3-state enable input, high=input, low=output
);
```

在不使用原厂原语的情况下也可以使用verilog描述三态门rtl如下

```verilog
assign io_pin_io[i] = (io_pin_oe[i]) ? io_pin_out[i] : io_pin_in[i];
assign io_pin_in[i] = 'bz;
```

先看输入电路如下

```verilog
genvar i;
reg [GPIO_PORT_NUM - 1: 0] gpio_input_reg;
reg [GPIO_PORT_NUM - 1: 0] gpio_output_reg;

//input data sample
always @(posedge sys_clk) begin
    if (!sys_rst_n) begin
        gpio_input_reg <= 'b0;
    end
    else begin
        gpio_input_reg <= io_pin_in;
    end
end

//! Latch last input data
generate
    for (i = 0;i < GPIO_PORT_NUM;i = i + 1) begin
        always @(posedge sys_clk) begin
            if (!sys_rst_n) begin
                gpio_input_val[i] <= gpio_input_reg[i];
            end
            else begin
                if ((ctrl_in_sel[i]) && (ctrl_lo_sel[i]) ) begin //input && latch
                    gpio_input_val[i] <= gpio_input_val[i];
                end
                else begin //input only
                    gpio_input_val[i] <= gpio_input_reg[i];
                end
            end
        end
    end
endgenerate
```

这段电路就是简单的数字采样，理论上要使用2倍频系统时钟，但这里为了实现上简单就不再调用PLL了

后面直接调用了`ctrl_in_sel`和`ctrl_lo_sel`控制输入状态和锁存模式选择

而输出电路的开漏输出采用`~`逻辑运算实现，如下所示

```verilog
//output control
generate
    for (i = 0;i < GPIO_PORT_NUM;i = i + 1) begin
        always @( * ) begin
            if (ctrl_in_sel[i]) begin //output 1'bx when input-mode
                gpio_output_reg[i] <= 1'bx;
            end
            else begin //output-mode
                if (ctrl_od_sel[i]) begin //open-drain
                    gpio_output_reg[i] = ~gpio_output_val[i];
                end
                else begin //push-pull
                    gpio_output_reg[i] = gpio_output_val[i];
                end
            end
        end
    end
endgenerate
```

最后则是输入输出控制功能和端口复用功能。端口复用是在单片机中为了节省引脚部分逻辑电路面积很常用的技巧，通过配置寄存器将片上外设的输出引脚连接到GPIO，让SPI、I2C这样低速的外设可以把GPIO直接作为IO从而节省一部分专用IO电路

```verilog
//tri-state gate oe control
generate
    for (i = 0;i < GPIO_PORT_NUM;i = i + 1) begin
        always @( * ) begin
            io_pin_oe[i] = ~ctrl_in_sel[i];
        end
    end
endgenerate

//alter-function
generate
    for (i = 0;i < GPIO_PORT_NUM;i = i + 1) begin
        always @( * ) begin
            if (ctrl_af_sel[i]) begin
                io_pin_out[i] = gpio_af_io[i];
            end
            else begin
                io_pin_out[i] = gpio_output_reg[i];
            end
        end
    end
endgenerate
```



