# RT-Thread启动流程

rtthread_startup()是RTT规定的同意启动入口

启动顺序：

1. 从启动文件开始运行

2. 进入rtthread_startup()

3. 进行RTT系统功能初始化

4. 进入用户入口main()

   ![image-20210104163931753](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210104163931753.png)

components.c

```c
int $Sub$$main(void)
{
    rt_hw_interrupt_disable();
    rtthread_startup();<-----------------------
    return 0;
}

/*省略其他代码*/

int rtthread_startup(void)
{
    rt_hw_interrupt_disable();//关闭中断

    /* 板级初始化：需要在该函数内部进行系统堆的初始化*/
    rt_hw_board_init();
    /* 打印RTT版本信息 */
    rt_show_version();
    /* 定时器初始化 */
    rt_system_timer_init();
    /* 调度器初始化 */
    rt_system_scheduler_init();
#ifdef RT_USING_SIGNALS
    /* 信号初始化 */
    rt_system_signal_init();
#endif

    /* 创建一个用户main线程 */
    rt_application_init();

    /* 定时器线程初始化 */
    rt_system_timer_thread_init();
    /* 空闲线程初始化 */
    rt_thread_idle_init();
    /* 启动调度器 */
    rt_system_scheduler_start();

    /* 不会执行至此 */
    return 0;
}
```

启动调度器之前，系统创建的线程在执行rt_thread_startup()后并不会马上执行，而是**处于就绪状态等待系统调度**，启动调度器后系统才转入第一个线程开始允许，根据调度规则，选择的是就绪队列中优先级最高的线程

rt_hw_board_init()中完成了**系统时钟设置、串口初始化、将系统输入输出绑定到串口**

用户在main()函数内添加自己的应用

![image-20210107174857535](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210107174857535.png)

主线程经过以上流程进入用户应用