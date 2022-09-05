# Verilog HDL中的状态机

在写verilog的时候，难免要用到状态机来实现控制逻辑，这里面有很多需要仔细研究的电路特性，笔者将自己的部分学习感悟列举在本文中

> 下面内容仅针对verilog进行探讨，并且尽量以RTL描述而不是行为级描述给出代码

## 参考博文与教程

https://blog.csdn.net/weixin_39269366/article/details/120550409

https://www.cnblogs.com/lifan3a/articles/4583577.html

https://blog.csdn.net/Jackiezhang1993/article/details/85045621

## 状态机基本概念

在数字电路中，**有限状态机**（Finite State Machine，FSM）简称状态机，是一种基于状态转移描述顺序逻辑的组合逻辑时序逻辑混合电路。FSM源自“通用的”序列信号发生器电路。

### 状态机分类与基本描述

状态机模型分为两类：

* **Moore**状态机：时序逻辑的输出只与当前状态有关
* **Mealy**状态机：时序逻辑的输出不仅取决于当前状态，还与输入有关

FSM是一种在有限个状态之间按一定规律转换的时序电路，可以认为是组合逻辑和时序逻辑的一种组合，因此包含有组合逻辑和时序逻辑两部分。这就导致笔者在使用Verilog HDL描述时经常会有疑问：该怎么描述才能把时序逻辑和组合逻辑区分开并做到最稳定的时序？

为了深入探讨这个问题，我们不妨回顾一下状态机的硬件结构框图

下面是Moore型状态机的结构框图，不难发现，它由三块主要逻辑构成：**负责状态转移的组合逻辑F、负责产生输出的组合逻辑G、负责记录当前状态的时序逻辑R**

![image-20220905224628410](FPGA学习笔记【对状态机的讨论】.assets/image-20220905224628410.png)

如果使用代码描述，我们可以如下尝试：

下列代码有四种状态，使用一个寄存器来存储，同时搭配了输入和输出的两套组合逻辑

```verilog
module Moore_FSM(
    input wire in,
    output wire out
);
    reg [1:0] current_state; //当前状态
    reg [1:0] next_state; //下一状态
    
    //负责状态转移的逻辑R
    always @(posedge clk) begin
        current_state <= next_state; //根据下一状态next_state激励信号完成当前状态切换
    end
    
    //产生下一状态的组合逻辑F
    always @(*) begin
        case(current_state)
            2'b00: begin
                if(in) begin //根据输入条件判断
                    next_state = 2'b01; //状态转移,以下省略
                end
                else begin
                    next_state = 2'b00;
                end
            end
            2'b01: begin
                //...
            end
            2'b10: begin
                //...
            end
            2'b11: begin
                //...
            end
            default: begin
                next_state = 2'b00; //满足自启动条件
            end
        endcase
    end
    
    //产生输出的组合逻辑G
    always @(*) begin
        case(current_state)
            2'b00: begin
                out = 1'b1;
            end
            2'b01: begin
                //...
            end
            2'b10: begin
                //...
            end
            2'b11: begin
                //...
            end
            default: begin
                out = 1'b1;
            end
        endcase
    end
        
endmodule
```

如果你经常使用状态机，那么肯定表示“*这不就是个三段式状态机吗*”。没错，这一段按照结构框图的RTL写法正好符合三段式状态机的要求，或者说三段式状态机的严谨性就来自于它严格按照了结构框图对硬件进行描述而不过于依赖综合器，至于这段代码对我们的启发，我们之后再谈，现在再来看Mealy型状态机的Verilog写法

> 你可能会发现组合逻辑G部分代码里面使用了current_state而不是next_state。这个问题很关键，但我们下个部分再详细说

Mealy状态机并没有复杂多少

![image-20220905230232305](FPGA学习笔记【对状态机的讨论】.assets/image-20220905230232305.png)

```verilog
module Mealy_FSM(
    input wire in,
    output wire out
);
    reg [1:0] current_state; //当前状态
    reg [1:0] next_state; //下一状态
    
    //负责状态转移的逻辑R
    always @(posedge clk) begin
        current_state <= next_state; //根据下一状态next_state激励信号完成当前状态切换
    end
    
    //产生下一状态的组合逻辑F
    always @(*) begin
        case(current_state)
            2'b00: begin
                if(in) begin //根据输入条件判断
                    next_state = 2'b01; //状态转移,以下省略
                end
                else begin
                    next_state = 2'b00;
                end
            end
            2'b01: begin
                //...
            end
            2'b10: begin
                //...
            end
            2'b11: begin
                //...
            end
            default: begin
                next_state = 2'b00; //满足自启动条件
            end
        endcase
    end
    
    //产生输出的组合逻辑G
    always @(*) begin
        case(current_state)
            2'b00: begin
                if(in) begin //根据当前输入和状态产生输出
                    out = 1'b1;
                end
                else begin
                    out = 1'b0;
                end
            end
            2'b01: begin
                //...
            end
            2'b10: begin
                //...
            end
            2'b11: begin
                //...
            end
            default: begin
                out = 1'b1;
            end
        endcase
    end
        
endmodule
```

这段代码只不过在Moore型状态机的基础上加入了一对ifelse语句来满足Mealy状态机输出同时取决于输入和当前状态的特性——这也是实际应用中最常见的写法

需要说明一点：状态机的输出电路G，可以在后面加入一个寄存器用于满足后续电路的同步要求，还可以减少竞争冒险，不过这样的后果就是状态机输出相对输入会往后延迟一个时钟周期。在Verilog中只要把第三个always块改成时钟边沿触发即可

```verilog
always @(posedge clk)
```

## 如何写状态机

从上面标准的两个状态机模型上，我们可以发现：任何状态机都可以被抽象成标准的Mealy和Moore状态机，因此三段式状态机代码可以用于良好描述任何状态机。这就是为什么大伙都在说三段式状态机性能好。

不过一段式和两段式状态机也是能见到的。

一段式状态机**只有一个时序逻辑always块**，把所有的逻辑（输入控制状态转换F、输出控制G、状态轮转R）都在同一个always块内实现。代码看起来很简洁，而且很符合顺序执行的软件写法，但是不利于维护，如果状态复杂一些就很容易出错，在简单的状态机情形下倒是经常使用









### RTL状态机和可综合的行为级描述状态机









### 独热码or普通二进制or格雷码？







### 处理自启动问题







