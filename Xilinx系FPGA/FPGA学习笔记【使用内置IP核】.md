# 时钟IP核的使用

Vivado内置了使用FPGA中时钟资源实现的时钟IP核，可以实现分频、倍频、调节相位、控制占空比等功能

可以使用时钟IP核对内/对外输出不同频率的时钟信号

## FPGA时钟资源

Xilinx的7系列FPGA都配置了专用的**全局**时钟和**区域**时钟资源

CMT（Clock Management Tiles时钟管理片）提供时钟合成（Clock frequency synthesis）、倾斜校正（deskew）、抖动过滤（jitter filtering）的功能。1个CMT中包括1个MMCM混合时钟管理电路和1个PLL锁相环电路

不同的FPGA包含的CMT数量不一样

FPGA中的CMT被分为了多个时钟区域（Clock Region），时钟区域可以单独工作，也可以通过全局时钟线主干道（Clock Backbone）和水平时钟线（HROW）统一调配资源共同工作

## FPGA时钟IP核的使用

在【IP Catalog】搜索clock出现clock wizard，双击即可进行设置

配置好自定义选项后生成IP核代码，打开IP视图可以找到示例的例化代码，将其复制到顶层模块，在顶层模块中加入IP核相关代码的例化就可以使用IP核了。

# FIFO IP核的使用









# RAM IP核的使用







