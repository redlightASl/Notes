# 加法器









# 减法器







# 乘法器







# 除法器

**除法器**（除法算法）是一类算法：给定两个整数 N（分子、被除数）和 D（分母、除数），计算它们的商和（或）余数

除法算法主要分为两类：**慢除法**和**快除法**

慢除法在每次迭代的过程中给出商的一位数字。慢除法包括复原法、非复原法和SRT除法等；快除法从商的一个近似估计开始，在每次迭代过程中产生有效位数为最终商的两倍的中间值

**简单的二进制除法器本质上是多次减法，循环执行直到余数小于除数为止**

也就是说硬件除法使用类似以下逻辑

```c
int divide=4;//除数
int p=32;//被除数
int i=1;//商
int rest=0;//余数

do
{
	p=p-divide;
  	rest=p;
  	i++;
} while (rest>divide);

return i;
```

## 常见除法逻辑

除法遵循的基本逻辑就是

被除数=**商**\*除数+**余数**



### 恢复余数除法

两个N位二进制数相除：

1. 设置2N位寄存器A的低N位存放被除数，设置2N位寄存器B的高N位存放除数，设置N位寄存器C存放商，设置计数器cnt。

2. 将A左移一位，与B比较高N位大小

   若$A[2N-1:N] \geq B[2N-1:N]$，则令A=A-B，再令C左移一位，最低位为1；

   若$A[2N-1:N] < B[2N-1:N]$，则令C左移一位，最低为0；

3. 计数器cnt加1，

   若小于N则继续进行步骤2，否则结束计算。

4. 得到A中剩余的高N位为余数，C中的为商。

恢复余数除法采用串行结构，计算速度慢，且需要的时钟周期数不确定，不利于进行控制设计

verilog实现如下

```verilog
`timescale 1ns/1ps

module divider(a,b,start,clk,rst,q,r,busy,ready,cnt);
    input   [31:0]  a;//被除数
    input   [15:0]  b;//除数
	input           start,rst,clk;//控制信号
    
    output  [31:0]  q;//商
    output  [15:0]  r;//余数
	output          busy,ready;//状态指示
    output  [4:0]   cnt;//计数器
    
	wire    [31:0]  a;
	wire    [15:0]  b;
	wire            ready,start,rst,clk;
	wire    [31:0]  q;
	wire    [15:0]  r;
	wire    [16:0]  sub_out;
	wire    [15:0]  mux_out;
    
	reg     [31:0]  reg_quotient;
	reg     [15:0]  reg_remainder;
	reg     [15:0]  reg_b;
	reg     [4:0]   cnt;
	reg             busy,busy2;
	
always@(posedge clk or posedge rst)
begin
    if(!rst)//复位
    begin
		cnt   <= 0;
		busy  <= 0;
		busy2 <= 0; 
	end else
    begin
		busy2 <= busy;//等待1个时钟周期脱离忙状态
        if(start)//开启
        begin
			reg_quotient  <= a;
			reg_remainder <= 16'b0;
			reg_b         <= b;
			cnt           <= 5'b0;
			busy          <= 1'b1;
        end	else if(busy)
        begin//执行32个循环
            reg_quotient  <= {reg_quotient[30:0],~sub_out[16]};//
			reg_remainder <= mux_out;   
			cnt  		  <= cnt + 1;
			if(cnt == 5'h1f)
				busy <= 0;//完成
		end
	end
end
	
assign ready   = (~busy)&busy2;//当不忙碌时就说明准备好了
assign sub_out = {r,q[31]} - {1'b0,reg_b};//减法输出
assign mux_out = sub_out[16]?{r[14:0],q[31]}:sub_out[15:0];//是否存储
assign q       = reg_quotient;//输出商
assign r       = reg_remainder;//输出余数
	
endmodule
```

### 交替加减法

交替加减法可以采用脉动阵列的形式，实现更高并行度，增加效率

verilog实现如下

```verilog

```







# 微分与积分电路









# DSP