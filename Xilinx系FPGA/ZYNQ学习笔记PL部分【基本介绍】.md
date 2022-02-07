# ZYNQ-PL简介

Zynq的PL即Programmable Logic部分，实质上是一个和PS端紧耦合的Artix-7 FPGA，具有与普通FPGA相似的片上资源和模拟外设，可以单纯的代替FPGA——事实上如果看LUT-价格比，Zynq比单纯的FPGA更高一些；但是Zynq的PL可以使用MIO与PS交互，这就使得Zynq可以“随用随编”

* PS运算速度不够？直接构造一个硬件加速核挂到AXI总线上
* PS缺内存？直接把PL的块RAM当分布式内存用
* PS的实时性不够？直接在PL上放一块MicroBlaze、Xtensa、RISC-V的MCU

Xilinx还想办法搞了个PYNQ，能够直接把PL当工具核用Python+opncv写自带硬件加速的图像处理应用

## 硬件资源







## 开发流程







## 与PS交互
