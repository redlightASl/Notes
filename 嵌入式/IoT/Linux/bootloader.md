# 最简单的bootloader的实现

此处以stm32f407（Cortex-M4）为例





## 初始化硬件

1. 关闭看门狗





2. 设置时钟







3. 初始化SDRAM





4. 重定位







5. 执行main函数



## 重定位bootloader









## 将内核从NAND FLASH/DRAM加载入CPU能直接操作的SDRAM/Cache







## 设置要传递给操作系统内核的初始参数







## 加载操作系统内核

