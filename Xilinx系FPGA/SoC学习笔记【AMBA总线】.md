# AMBA总线规范

AMBA规范由AR公司制定，用于SoC内IP互联

AMBA即（Advanced Microcontroller Bus Architecture，AMBA）规范是一种开放式标准片上互联规范，用于连接和管理片上系统中的各个功能模块（IP）

AMBA中有以下几个主要接口：

* 高级外设总线APB：用于低速外设连接
* 高级高性能总线AHB：用于高速外设连接
* 高级可扩展接口AXI：最普遍使用的高性能总线
* 高级跟踪总线ATB：用于在芯片外围移动跟踪数据
* AXI一致性扩展接口ACE：用于移动设备的大小核之间高速连接
* 相关集线器接口CHI：用于网络和服务器设备的高带宽高性能数据传输

## APB规范

APB总线包含8根信号线：

* PCLK：总线时钟
* PADDR：总线地址信号
* PWRITE：总线方向信号
* PSEL：总线选择信号
* PENABLE：总线数据传输使能
* PWDATA：写数据信号
* PRDATA：读数据信号
* PREADY：总线准备信号

### 读写时序

1. 无等待状态写
    1. 需要一个建立周期寄存PADDR、PWDATA、PWRITE、PSEL，这些信号会在PCLK上升沿完成寄存
    2. 在第二个周期，PENABLE和PREADY寄存，PENABLE表示传输访问周期开始；PREADY表示PCLK的下一个上升沿从设备可以完成传输
    3. 第三个周期完成之前，PADDR、PWDATA和控制信号会一直保持有效
    4. 第四个周期，PENABLE和PSEL变成无效，等待下一个传输开始
2. 有等待状态写
3. 无等待状态读
4. 有等待状态读





### 错误响应









## AHB规范