# RTT的内核与内核移植

**内核移植：将操作系统的内核在不同CPU架构和不同外围硬件环境下运行，能够具有线程管理和调度、内存管理、线程间同步与通信、定时器管理等基本功能的过程**

内核移植可以分为**CPU架构移植**和**BSP（Board Support Package板级支持包）移植**两部分

# CPU架构移植

RTT提供了**libcpu抽象层**来适配不同的CPU架构

可支持arm系、mips系、RISC-V、avr系、xilinx系等多种流行的嵌入式cpu架构

## libcpu抽象层

libcpu的上层对内核提供运行接口，下层对CPU提供架构移植接口

总体上讲，CPU架构移植主要需要移植下表所述的内容

| 函数和变量接口内容                                           | 描述                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| rt_base_t rt_hw_interrupt_disable(void);                     | 关闭全局中断                                                 |
| void rt_hw_interrupt_enable(rt_base_t level);                | 打开全局中断                                                 |
| rt_uint8_t *rt_hw_stack_init(void *tentry, void *parameter, rt_uint8_t *stack_addr, void *texit); | 线程栈初始化（线程创建和初始化时调用该函数）                 |
| void rt_hw_context_switch_to(rt_uint32 to);                  | 没有来源线程的上下文切换（调度器启动第一个线程时和signal中调用） |
| void rt_hw_context_switch(rt_uint32 from,rt_uint32 to);      | 线程切换接口：从from线程切换到to线程                         |
| void rt_hw_context_switch_interrupt(rt_uint32 from, rt_uint32 to); | 中断线程切换接口：从from线程切换到to线程                     |
| rt_uint32_t rt_thread_switch_interrupt_flag;                 | 表示需要在中断里进行切换的标志                               |
| rt_uint32_t rt_interrupt_from_thread,rt_interrupt_to_thread; | 在上下文切换时用于保存from和to线程                           |

## 全局中断开关的实现

所有临界区处理时用到的线程间同步和通信机制都依赖libcpu中提供的全局中断开关函数

```c
rt_hw_interrupt_disable(void);//关闭全局中断
rt_hw_interrupt_enable(rt_base_t level);//打开全局中断
```

Cortex-M架构中使用CPS指令实现这两个函数

```assembly
CPSID I ;PRIMASK=1,  ; 关中断
CPSID I ;PRIMASK=0,  ; 开中断
```

### Cortex-M架构的移植示例

#### 关闭全局中断 

rt_hw_interrupt_disable()函数功能是

		1. 保存当前全局中断状态
  		2. 把状态作为函数返回值

基于MDK汇编实现代码如下

```assembly
;/*
; * rt_base_t rt_hw_interrupt_disable();
; */
rt_hw_interrupt_disable    PROC			; PROC伪指令定义函数
    EXPORT  rt_hw_interrupt_disable		; EXPORT输出定义的函数，类似C语言的extern
    MRS     r0, PRIMASK		; 读取PRIMASK寄存器的值到r0寄存器
    CPSID   I		; 关闭全局中断
    BX      LR		; 函数返回
    ENDP	; 函数结束
```

#### 打开全局中断

基于MDK汇编实现代码如下

```assembly
;/*
; * void rt_hw_interrupt_enable(rt_base_t level);
; */
rt_hw_interrupt_enable    PROC			; PROC伪指令定义函数
    EXPORT  rt_hw_interrupt_enable		; EXPORT输出定义的函数，类似C语言的extern
    MSR     PRIMASK, r0		; 把r0寄存器的值写入到PRIMASK寄存器
    BX      LR		; 函数返回
    ENDP	; 函数结束
```

开关全局中断的移植思路：通用寄存器内保存了希望中断锁处于的状态，用寄存器转移指令将通用寄存器内数据和中断控制寄存器内的数据交换，借助CPU自带的中断生效指令对全局中断状态进行生效

#### 线程栈初始化

线程初始化函数 _rt_thread_init()进行操作系统内部的线程初始化

栈初始化函数rt_hw_stack_init()会手动构造上下文，这个上下文内容作为每个线程第一次执行的初始值

**线程栈自顶向下生长**

_rt_thread_init()和rt_hw_stack_init()函数如下所示

```c
static rt_err_t _rt_thread_init(struct rt_thread *thread,
                                const char       *name,
                                void (*entry)(void *parameter),
                                void             *parameter,
                                void             *stack_start,
                                rt_uint32_t       stack_size,
                                rt_uint8_t        priority,
                                rt_uint32_t       tick)
{
    /* init thread list */
    rt_list_init(&(thread->tlist));

    thread->entry = (void *)entry;
    thread->parameter = parameter;

    /* stack init */
    thread->stack_addr = stack_start;
    thread->stack_size = stack_size;

    /* init thread stack */
    rt_memset(thread->stack_addr, '#', thread->stack_size);
    thread->sp = (void *)rt_hw_stack_init(thread->entry, thread->parameter,
                                          (void *)((char *)thread->stack_addr + thread->stack_size - 4),
                                          (void *)rt_thread_exit);

    /* priority init */
    RT_ASSERT(priority < RT_THREAD_PRIORITY_MAX);
    thread->init_priority    = priority;
    thread->current_priority = priority;

    thread->number_mask = 0;
#if RT_THREAD_PRIORITY_MAX > 32
    thread->number = 0;
    thread->high_mask = 0;
#endif

    /* tick init */
    thread->init_tick      = tick;
    thread->remaining_tick = tick;

    /* error and flags */
    thread->error = RT_EOK;
    thread->stat  = RT_THREAD_INIT;

    /* initialize cleanup function and user data */
    thread->cleanup   = 0;
    thread->user_data = 0;

    /* init thread timer */
    rt_timer_init(&(thread->thread_timer),
                  thread->name,
                  rt_thread_timeout,
                  thread,
                  0,
                  RT_TIMER_FLAG_ONE_SHOT);

    /* initialize signal */
#ifdef RT_USING_SIGNALS
    thread->sig_mask    = 0x00;
    thread->sig_pending = 0x00;

    thread->sig_ret     = RT_NULL;
    thread->sig_vectors = RT_NULL;
    thread->si_list     = RT_NULL;
#endif

#ifdef RT_USING_LWP
    thread->lwp = RT_NULL;
#endif

    RT_OBJECT_HOOK_CALL(rt_thread_inited_hook, (thread));

    return RT_EOK;
}
//上面这个函数想必是要刻进DNA罢（确信）

//下面这个函数有手就行
rt_uint8_t *rt_hw_stack_init(void       *tentry,//线程入口函数的地址
                             void       *parameter,//参数
                             rt_uint8_t *stack_addr,//传入栈地址
                             void       *texit)//线程退出函数的地址
{
    struct stack_frame *stack_frame;
    rt_uint8_t         *stk;
    unsigned long       i;

    //对传入的栈指针作对齐处理，使其能适应硬件的内存
    stk  = stack_addr + sizeof(rt_uint32_t);
    stk  = (rt_uint8_t *)RT_ALIGN_DOWN((rt_uint32_t)stk, 8);
    stk -= sizeof(struct stack_frame);

    stack_frame = (struct stack_frame *)stk;//获取上下文的栈帧的指针

    /* 初始化所有寄存器的默认值为0xdeadbeef */
    for (i = 0; i < sizeof(struct stack_frame) / sizeof(rt_uint32_t); i ++)
    {
        ((rt_uint32_t *)stack_frame)[i] = 0xdeadbeef;
    }
	
    //根据ARM APCS调用标准，将第一个参数保存在r0寄存器
    stack_frame->exception_stack_frame.r0  = (unsigned long)parameter;
    
    //将剩下的参数寄存器都设置为0
    stack_frame->exception_stack_frame.r1  = 0;                        /* r1 */
    stack_frame->exception_stack_frame.r2  = 0;                        /* r2 */
    stack_frame->exception_stack_frame.r3  = 0;                        /* r3 */
    
    //将IP（Intra-Procedure-cell scratch register）设置为0
    stack_frame->exception_stack_frame.r12 = 0;                        /* r12 */
    
    //将线程退出函数的地址保存在lr寄存器
    stack_frame->exception_stack_frame.lr  = (unsigned long)texit;     /* lr */
    
    //将线程入口函数的地址保存在pc寄存器
    stack_frame->exception_stack_frame.pc  = (unsigned long)tentry;    /* 进入点为 pc */
    
    //设置psr的值为0x01_000_000L，表示默认切换过去是Thumb模式
    stack_frame->exception_stack_frame.psr = 0x01000000L;              /* PSR */

    /* 返回当前线程的栈地址 */
    return stk;
}
```

#### 上下文切换

在不同的CPU架构中，线程间的上下文切换和中断到线程的上下文切换，上下文的寄存器部分可能是有差异的，也可能是一样的，**RTT的libcpu抽象层实现三个线程切换相关的函数**

| 函数                              | 说明                                                         |
| --------------------------------- | ------------------------------------------------------------ |
| rt_hw_context_switch_to()         | 没有来源线程，切换到目标线程，在调度器启动第一个线程时被调用 |
| rt_hw_context_switch()            | **线程环境**下，从当前线程切换到目标线程                     |
| rt_hw_context_switch_interrupt () | **中断环境**下，从当前线程切换到目标线程                     |

线程环境下进行切换和中断环境下进行切换是存在差异的：==线程环境下调用rt_hw_context_switch可马上进行上下文切换；终端环境下需要等待中断处理函数完成后才能进行切换==

在Cortex-M系列CPU中基于自动部分压栈和PendSV特性，上下文切换都是统一使用PendSV异常来完成，更加简洁，切换部分没有差异；但在ARM9等平台，两个函数的实现并不一样。中断处理程序中如果触发了线程的调度，调度函数里会调用rt_hw_context_switch_interrupt ()触发上下文切换，中断处理程序执行完毕后在中断退出之前会检查rt_hw_context_switch_interrupt_flag变量，如果变量值为1，则根据rt_interrupt_from_thread 变量和 rt_interrupt_to_thread 变量，完成线程的上下文切换

【PendSV异常】PendSV也称为可悬起的系统调用，**它是一种异常**，可以像普通中断一样被挂起，他专门用来辅助操作系统进行上下文切换，PendSV异常始终被初始化为最低优先级的异常

Cortex-M系列CPU的线程切换过程如下图所示

![image-20210126153612568](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210126153612568.png)

线程-线程切换过程可以描述为：保护现场（from线程寄存器压栈）——进入PendSV异常——替换参数（保存from线程参数并恢复to线程参数）——退出PendSV异常——替换恢复现场（to线程寄存器出栈）

![image-20210126153650909](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210126153650909.png)

中断-线程切换过程可以描述为：保护现场（from线程寄存器压栈）——执行中断服务程序——【咬尾中断】——进入PendSV异常——替换参数（保存from线程参数并恢复to线程参数）——退出PendSV异常——替换恢复现场（to线程寄存器出栈）

所以在Cortex-M内核中rt_hw_context_switch()和rt_hw_context_switch_interrupt()功能一致，所以只需实现一份代码即可

rt_hw_context_switch_to()的实现如下

```assembly
;/*
; * void rt_hw_context_switch_to(rt_uint32 to);
; * r0 --> to
; * this fucntion is used to perform the first thread switch
; */
rt_hw_context_switch_to    PROC
    EXPORT rt_hw_context_switch_to
    ; r0的值是一个指向to线程的线程控制块的SP成员（线程栈的栈顶指针）的指针
    ; 将r0的值保存到rt_interrupt_to_thread变量里
    LDR     r1, =rt_interrupt_to_thread
    STR     r0, [r1]

    IF      {FPU} != "SoftVFP"
    ; CLEAR CONTROL.FPCA
    MRS     r2, CONTROL             ; read
    BIC     r2, #0x04               ; modify
    MSR     CONTROL, r2             ; write-back
    ENDIF

    ; 设置from线程为空，表示不需要保存from的上下文
    LDR     r1, =rt_interrupt_from_thread
    MOV     r0, #0x0
    STR     r0, [r1]

    ; 设置切换标志为1，代表需要切换线程，此变量rt_thread_switch_interrupt_flag将在PendSV异常处理函数中切换时清零
    LDR     r1, =rt_thread_switch_interrupt_flag
    MOV     r0, #1
    STR     r0, [r1]

    ; 设置PendSV和SysTick异常优先级为最低优先级
    LDR     r0, =NVIC_SYSPRI2
    LDR     r1, =NVIC_PENDSV_PRI
    LDR.W   r2, [r0,#0x00]       ; read
    ORR     r1,r1,r2             ; modify
    STR     r1, [r0]             ; write-back

    ; 触发将引起PendSV异常处理程序的PendSV异常
    LDR     r0, =NVIC_INT_CTRL
    LDR     r1, =NVIC_PENDSVSET
    STR     r1, [r0]

    ; 放弃芯片启动到第一次上下文切换之前的栈内容，将MSP设置为启动时的值
    LDR     r0, =SCB_VTOR
    LDR     r0, [r0]
    LDR     r0, [r0]
    MSR     msp, r0

    ; 在处理器级别使能全局中断和全局异常，使能后直接进入PendSV异常处理函数
    CPSIE   F
    CPSIE   I

    ; 程序不会执行到这里
    ENDP
```

rt_hw_context_switch_interrupt()和rt_hw_context_switch()的实现如下

```assembly
;/*
; * void rt_hw_context_switch(rt_uint32 from, rt_uint32 to);
; * r0 --> from
; * r1 --> to
; */
rt_hw_context_switch_interrupt
    EXPORT rt_hw_context_switch_interrupt	; 俩函数放一块了
rt_hw_context_switch    PROC
    EXPORT rt_hw_context_switch

    ; 检查rt_thread_switch_interrupt_flag是否为1
    ; 如果变量为1则表明需要切换线程，直接跳过更新from线程的内容
    LDR     r2, =rt_thread_switch_interrupt_flag
    LDR     r3, [r2]
    CMP     r3, #1
    BEQ     _reswitch
    ; 设置rt_thread_switch_interrupt_flag的值为1
    MOV     r3, #1
    STR     r3, [r2]

	; 从参数r0里更新rt_interrupt_from_thread变量
    LDR     r2, =rt_interrupt_from_thread
    STR     r0, [r2]

_reswitch
	; 从参数r1里更新rt_interrupt_to_thread变量
    LDR     r2, =rt_interrupt_to_thread
    STR     r1, [r2]

	; 触发将引起PendSV异常处理程序的PendSV异常，直接进入PendSV异常处理函数里完成上下文切换
    LDR     r0, =NVIC_INT_CTRL
    LDR     r1, =NVIC_PENDSVSET
    STR     r1, [r0]
    BX      LR
    ENDP
```

PendSV异常处理函数被命名为PendSV_Handler()

异常处理函数的实现如下

```assembly
; r0 --> switch from thread stack
; r1 --> switch to thread stack
; psr, pc, lr, r12, r3, r2, r1, r0 are pushed into [from] stack
PendSV_Handler   PROC
    EXPORT PendSV_Handler	;PendSV异常处理函数

    ; 关闭中断，保护程序进行
    MRS     r2, PRIMASK
    CPSID   I

    ; 检查rt_thread_switch_interrupt_flag是否为0
    ; 如果为0则跳转到pendsv_exit
    LDR     r0, =rt_thread_switch_interrupt_flag
    LDR     r1, [r0]
    CBZ     r1, pendsv_exit         ; pendsv already handled

    ; 清零rt_thread_switch_interrupt_flag
    MOV     r1, #0x00
    STR     r1, [r0]

	; 检查rt_interrupt_from_thread变量，如果为0则不进行from线程的上下文切换
    LDR     r0, =rt_interrupt_from_thread
    LDR     r1, [r0]
    CBZ     r1, switch_to_thread    ; 跳过在第一次的切换
	
	; 保存from线程上下文
    MRS     r1, psp                 ; 获取from线程的栈指针SP
    
    ; 下面是针对FPU寄存器的处理
    IF      {FPU} != "SoftVFP"
    TST     lr, #0x10               ; if(!EXC_RETURN[4])
    VSTMFDEQ  r1!, {d8 - d15}       ; push FPU register s16~s31
    ENDIF

	; 还是保存from线程上下文
    STMFD   r1!, {r4 - r11}         ; 将r4 - r11入栈

	; 下面是针对FPU寄存器的处理
    IF      {FPU} != "SoftVFP"
    MOV     r4, #0x00               ; flag = 0
    TST     lr, #0x10               ; if(!EXC_RETURN[4])
    MOVEQ   r4, #0x01               ; flag = 1
    STMFD   r1!, {r4}               ; push flag
    ENDIF
	
	; 依旧是保存from线程上下文
    LDR     r0, [r0]
    STR     r1, [r0]                ; 更新线程控制块的SP指针

switch_to_thread	; 线程替换
    LDR     r1, =rt_interrupt_to_thread
    LDR     r1, [r1]
    LDR     r1, [r1]                ; 获取to线程的栈指针SP

	; 下面是针对FPU寄存器的处理
    IF      {FPU} != "SoftVFP"
    LDMFD   r1!, {r3}               ; pop flag
    ENDIF

    LDMFD   r1!, {r4 - r11}         ; 恢复to线程寄存器值：r4 - r11寄存器出栈

	; 下面是针对FPU寄存器的处理
    IF      {FPU} != "SoftVFP"
    CMP     r3,  #0                 ; if(flag_r3 != 0)
    VLDMFDNE  r1!, {d8 - d15}       ; pop FPU register s16~s31
    ENDIF
	
	; 更新r1的值到栈指针psp
    MSR     psp, r1

	; 下面是针对FPU寄存器的处理
    IF      {FPU} != "SoftVFP"
    ORR     lr, lr, #0x10           ; lr |=  (1 << 4), clean FPCA.
    CMP     r3,  #0                 ; if(flag_r3 != 0)
    BICNE   lr, lr, #0x10           ; lr &= ~(1 << 4), set FPCA.
    ENDIF

pendsv_exit
    ; 恢复全局中断状态
    MSR     PRIMASK, r2

	; 修改lr寄存器的bit2，确保进程使用PSP堆栈指针！
    ORR     lr, lr, #0x04
    ; 退出异常处理函数
    BX      lr
    ENDP
```

#### 时钟节拍SysTick的实现

RTT依靠时钟节拍进行线程调度、延时、软件定时器等操作

只要确保rt_tick_increase()函数在时钟节拍中断里被周期性调用即可，**调用周期取决于rtconfig.h的宏RT_TICK_PER_SECOND的值**

在Cortex-M系列CPU里通过SysTick的中断处理函数实现时钟节拍

实现如下

```c
void SysTick_Handler(void)
{
    /* 告知系统进入中断 */
    rt_interrupt_enter();
    HAL_IncTick();//systick++
    rt_tick_increase();//周期性调用rt_tick_increase()
    /* 告知系统退出中断 */
    rt_interrupt_leave();
}

__weak void HAL_IncTick(void)
{
  uwTick++;
}
```

# BSP移植

为了适配板卡具有的硬件资源，RTT提供了BSP抽象层来适配常见的板卡

**BSP移植可以让操作系统控制开发板/产品板上除CPU外的硬件资源，建立让操作系统合理运行的环境**

需要完成的主要工作如下

1. ==初始化CPU内部寄存器==，设定==RAM工作时序==
2. 实现==时钟驱动==及==中断控制器驱动==，完善中断管理
3. 实现==串口==和==GPIO==驱动
4. 初始化动态内存堆，实现==动态堆内存管理==

详细的BSP移植需要参考RTT驱动设计及使用部分