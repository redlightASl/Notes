# 触发器实现



## D触发器

```verilog
module D_trigger(
    input d,
    input cp,
    input r,
    input s,
    output reg q,
    output reg qn,
);
    
always @(posedge cp) begin
	if({r,s}==2'b01) //判断是否有r=0,s=1
	begin
		q=1'b0;//
		qn=1'b1;
	end
	else if({r,s}==2'b10) //判断是否有r=1,s=0
	begin
		q=1'b1;//复位输出1
		qn=1'b0;
	end
	else if({r,s}==2'b11) //判断是否有r=1,s=1
	begin
		q=d;//保持原来状态
		qn=~d;
	end
end
endmodule
```





## 触发器









# 分频器实现

这里的分频器指的是时钟信号**数字分频器**，不同于模拟电路中使用运放和阻容网络实现的用于将输出信号频率变为原来的1/n的模拟分频器，数字分频器是一种能够将时钟信号频率按照选定的比例进行切分的电路

分频器主要分为奇数分频，偶数分频，半整数分频和小数分频

如果在FPGA上实现，分频器通常能通过计数器的循环来实现

## 奇数分频

奇数分频：首先，完全可以通过计数器来实现，如进行三分频，通过待分频时钟上升沿触发计数器进行模三计数，当计数器计数到邻近值进行两次翻转，比如可以在计数器计数到1时，输出时钟进行翻转，计数到2时再次进行翻转。即是在计数值在邻近的1和2进行了两次翻转。这样实现的三分频占空比为1/3或者2/3。如果要实现占空比为50%的三分频时钟，可以通过待分频时钟下降沿触发计数，和上升沿同样的方法计数进行三分频，然后下降沿产生的三分频时钟和上升沿产生的时钟进行相或运算，即可得到占空比为50%的三分频时钟。这种方法可以实现任意的奇数分频。归类为一般的方法为：对于实现占空比为50%的N倍奇数分频，首先进行上升沿触发进行模N计数，计数选定到某一个值进行输出时钟翻转，然后经过（N-1）/2再次进行翻转得到一个占空比非50%奇数n分频时钟。再者同时进行下降沿触发的模N计数，到和上升沿触发输出时钟翻转选定值相同值时，进行输出时钟时钟翻转，同样经过（N-1）/2时，输出时钟再次翻转生成占空比非50%的奇数n分频时钟。两个占空比非50%的n分频时钟相或运算，得到占空比为50%的奇数n分频时钟。



```verilog
module fenpin(
  input  i_clk,
  input  i_rst_n,
   
  output o_clk
);
  
// log2(3) = 1.5850 <= 2  
reg [1:0] cnt_p;                        // 上升沿计数子
  
// 3位上升沿计数器: 0 ~ 2
always @ (posedge i_clk, negedge i_rst_n)
begin
  if (!i_rst_n)
    cnt_p <= 0;
  else
    begin
    if (cnt_p == 2)            //2=3-1
      cnt_p <= 0;
    else
      cnt_p <= cnt_p + 1'b1;
    end
end
 
// log2(3) = 1.5850 <= 2  
reg [1:0] cnt_n;                        // 下降沿计数子
 
// 3位下降沿计数器: 0 ~ 2
// 2 = 3 - 1
always @ (negedge i_clk, negedge i_rst_n)
begin
  if (!i_rst_n)
    cnt_n <= 0;
  else
  begin
    if (cnt_n == 2)                  //2=3-1
      cnt_n <= 0;
    else
      cnt_n <= cnt_n + 1'b1;
  end
end
  
 
reg o_clk_p;                            // 上升沿时钟输出寄存器
 
// 输出上升沿时钟
// 0     ~ 1 ↑-> 1
// (1+1) ~ 2 ↑-> 0
// 1 = 3>>1
// 2 = 3 - 1
always @ (posedge i_clk, negedge i_rst_n)
begin
  if (!i_rst_n)
    o_clk_p <= 0;
  else
  begin
    if (cnt_p <= 1)                     // 1 = 3>>1 ,右移相当于除以2
      o_clk_p <= 1;
    else
      o_clk_p <= 0;
  end
end
  
reg o_clk_n;                            // 下降沿时钟输出寄存器
 
// 输出下降沿时钟
// 0     ~  1 ↓-> 1
// (1+1) ~  2 ↓-> 0
// 1 = 3>>1
// 2 = 3 - 1
always @ (negedge i_clk, negedge i_rst_n)
begin
  if (!i_rst_n)
    o_clk_n <= 0;
  else
  begin
    if (cnt_n <= 1)                     // 1 = 3>>1 
      o_clk_n <= 1;
    else
      o_clk_n <= 0;
  end
end
 
assign o_clk = o_clk_n & o_clk_p;       // 按位与(作用:掩码)
  
endmodule
```





由于奇分频需要保持分频后的时钟占空比为 50% ，所以不能像偶分频那样直接在分频系数的一半时使时钟信号翻转(高电平一半，低电平一半)。
　　　　在此我们需要利用输入时钟上升沿和下降沿来进行设计。

 　　　　接下来我们设计一个 5 分频的模块，设计思路如下：

　　　　　采用计数器 cnt1 进行计数，在时钟上升沿进行加 1 操作，计数器的值为 0、1 时，输出时钟信号 clk_div  为高电平；计数器的值为2、3、4 时，输出时钟信号 clk_div 为低电平，计数到 5 时清零，从头开始计数。我们可以得到占空比为 40%  的波形 clk_div1。

 　　　 采用计数器 cnt2进行计数，在时钟下降沿进行加 1 操作，计数器的值为 0、1 时，输出时钟信号 clk_div  为高电平；计数器的值为2、3、4 时，输出时钟信号 clk_div 为低电平，计数到 5 时清零，从头开始计数。我们可以得到占空比为 40%  的波形 clk_div2。
 　　　　 clk_div1 和clk_div2 的上升沿到来时间相差半个输入周期，所以将这两个信号进行或操作，即可得到占空比为 50% 的5分频时钟。程序如下：

设计代码：

```verilog
//rtl
module divider(
    clk,
    rst_n,
    clk_div
);
    input clk;
    input rst_n;
    output clk_div;
    reg clk_div;

    parameter NUM_DIV = 5;
    reg[2:0] cnt1;
    reg[2:0] cnt2;
    reg    clk_div1, clk_div2;

always @(posedge clk or negedge rst_n)
    if(!rst_n)
        cnt1 <= 0;
    else if(cnt1 < NUM_DIV - 1)
        cnt1 <= cnt1 + 1'b1;
    else
        cnt1 <= 0;

always @(posedge clk or negedge rst_n)
    if(!rst_n)
        clk_div1 <= 1'b1;
    else if(cnt1 < NUM_DIV / 2)
        clk_div1 <= 1'b1;
    else
        clk_div1 <= 1'b0;

always @(negedge clk or negedge rst_n)
    if(!rst_n)
       cnt2 <= 0;
    else if(cnt2 < NUM_DIV - 1)
       cnt2 <= cnt2 + 1'b1;
    else
       cnt2 <= 0;

always @(negedge clk or negedge rst_n)
    if(!rst_n)
        clk_div2 <= 1'b1;
    else if(cnt2 < NUM_DIV / 2)
        clk_div2 <= 1'b1;
    else
        clk_div2 <= 1'b0;

    assign clk_div = clk_div1 | clk_div2;
endmodule
```





## 偶数分频

由待分频的时钟触发计数器计数，当计数器从0计数到N/2-1时，输出时钟进行翻转，并给计数器一个复位信号，使得下一个时钟从零开始计数。以此循环下去。这种方法可以实现任意的偶数N分频

```verilog
module even_divider(
    input clk,
    input rst_n,
    output reg clk_div
);

    parameter NUM_DIV = N;
    reg [3:0] cnt;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) //复位
    begin
        cnt <= 4'd0;
        clk_div <= 1'b0;
    end
    else if(cnt < NUM_DIV / 2 - 1) //平常情况下计数器+1
    begin
        cnt <= cnt + 1'b1;
        clk_div <= clk_div;
    end
    else begin //到达N/2-1时进行输出反转达到N分频
        cnt <= 4'd0;
        clk_div <= ~clk_div;
    end
end
endmodule
```

## 半整数分频

 在verilog程序设计中，我们往往要对一个频率进行任意分频，而且占空比也有一定的要求这样的话，对于程序有一定的要求。
 现在在前面两个实验的基础上做一个简单的总结，实现对一个频率的任意占空比的任意分频。
 比如： FPGA系统时钟是50M Hz，而我们要产生的频率是880Hz，那么，我们需要对系统时钟进行分频。很容易想到用计数的方式来分频：50000000/880 = 56818。
 显然这个数字不是2的整幂次方，那么我们可以设定一个参数，让它到56818的时候重新计数就可以实现了。程序如下：

```verilog
//rtl
module div(
    clk,
    rst_n,
    clk_div
);
    input clk,rst_n;
    output clk_div;
    reg clk_div;

    reg [15:0] counter;

always @(posedge clk or negedge rst_n)
    if(!rst_n)
        counter <= 0;
    else if(counter==56817)
        counter <= 0;
    else
        counter <= counter+1;

   assign clk_div = counter[15];
endmodule
```







## 小数分频

继续让我们来看如何实现任意占空比，比如还是由50M分频产生880Hz，而分频得到的信号的占空比为30%。

56818×30%=17045

```verilog
//rtl
module div(
    clk,
    rst_n,
    clk_div,
    counter
);
    input clk,rst_n;
    output clk_div;
    reg clk_div;
    output [15:0] counter;
    reg [15:0] counter;

always @(posedge clk)
    if(!rst_n)
        counter <= 0;
    else if(counter==56817)
        counter <= 0;
    else counter <= counter+1;

always @(posedge clk)
  if(!rst_n)
    clk_div <= 0;
  else if(counter<17045)
    clk_div <= 1;
  else
    clk_div <= 0;
 endmodule
```











# 倍频及PLL实现







# 片上总线实现







# SPI实现









# USART实现

