# EMIO

EMIO就是Extendable MIO，当PS部分的MIO对应片上引脚不够用时，就可以使用EMIO引出PL部分的bank引脚到片内

**EMIO实际上是PS端和PL端之间的接口**，可以让PS端的外设使用PL端的引脚、FPGA外设模块等

## EMIO与MIO之间的差异



## 通过EMIO点亮LED

PS端GPIO外设的GPIO有四个bank，其中bank0、bank1连接到MIO，bank2、bank3连接到EMIO，可经由EMIO连接到PL端引脚

