# ***【已弃坑】***

# 使用CubeMX在STM32上移植FreeRTOS

基本方法非常简单，只要在界面中的【Middeware】中选中FreeRTOS，选择一个合适的版本即可将FreeRTOS移植到STM32。

在这一过程中，CubeMX为用户做了如下工作

* 将FreeRTOS内核组件源文件加入工程
* 选择合适的内核移植文件
* 修改systick和pendSV中断汇编
* 将FreeRTOS的API用宏定义封装风格统一的函数和宏
* 加入FreeRTOS外设驱动
* 使用CubeMX统一配置内核对象



## FreeRTOS的底层移植























# 使用RT-Thread Studio移植RT-Thread











## RTT的底层移植











