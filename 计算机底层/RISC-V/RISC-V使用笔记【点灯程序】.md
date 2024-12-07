# 编写第一个蜂鸟E203程序

芯来官方给出的helloworld程序如下所示

```c
/* C库 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
/* SDK函数库 */
#include "platform.h"
#include "plic/plic_driver.h"
#include "encoding.h"
#include "stdatomic.h"

void reset_demo(void); //示例程序

//用于注册中断处理函数的结构体和函数
typedef void (*function_ptr_t) (void);
void no_interrupt_handler(void){};
function_ptr_t g_ext_interrupt_handlers[PLIC_NUM_INTERRUPTS];

plic_instance_t g_plic; //例化PLIC对象
/* PLIC中断服务程序的进入点 */
void handle_m_ext_interrupt()
{
  	plic_source int_num = PLIC_claim_interrupt(&g_plic); //在PLIC中注册中断
  	if ((int_num >=1 ) && (int_num < PLIC_NUM_INTERRUPTS))
    {
    	g_ext_interrupt_handlers[int_num]();
  	}
  	else
    {
    	exit(1 + (uintptr_t) int_num);
  	}
  	PLIC_complete_interrupt(&g_plic, int_num); //中断完成
}

/* 定时器中断处理函数 */
void handle_m_time_interrupt()
{
	clear_csr(mie, MIP_MTIP); //关闭定时器中断
	
    //设置重装载计数值
  	volatile uint64_t * mtime 		= (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);
  	volatile uint64_t * mtimecmp 	= (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIMECMP);
  	uint64_t now = *mtime;
  	uint64_t then = now + 2 * RTC_FREQ;
  	*mtimecmp = then;

  	//读取当前GPIO输出值并翻转
  	uint32_t leds = GPIO_REG(GPIO_OUTPUT_VAL);
  	GPIO_REG(GPIO_OUTPUT_VAL) ^= ((0x1 << BLUE_LED_OFFSET));
  	
    set_csr(mie, MIP_MTIP); //重新使能定时器中断
}

//这是一个没什么用的串口输出数据
const char * instructions_msg = " \
\n\
                SIFIVE, INC.\n\
\n\
         5555555555555555555555555\n\
        5555                   5555\n\
       5555                     5555\n\
      5555                       5555\n\
     5555       5555555555555555555555\n\
    5555       555555555555555555555555\n\
   5555                             5555\n\
  5555                               5555\n\
 5555                                 5555\n\
5555555555555555555555555555          55555\n\
 55555           555555555           55555\n\
   55555           55555           55555\n\
     55555           5           55555\n\
       55555                   55555\n\
         55555               55555\n\
           55555           55555\n\
             55555       55555\n\
               55555   55555\n\
                 555555555\n\
                   55555\n\
                     5\n\
\n\
SiFive E-Series Software Development Kit 'demo_gpio' program.\n\
Every 2 second, the Timer Interrupt will invert the LEDs.\n\
(Arty Dev Kit Only): Press Buttons 0, 1, 2 to Set the LEDs.\n\
Pin 19 (HiFive1) or A5 (Arty Dev Kit) is being bit-banged\n\
for GPIO speed demonstration.\n\
\n\
 ";

//这是另一个没什么用的串口输出数据
const char * instructions_msg_sirv = " \
\n\
\n\
\n\
\n\
          #    #  ######  #####   ######\n\
          #    #  #       #    #  #\n\
          ######  #####   #    #  #####\n\
          #    #  #       #####   #\n\
          #    #  #       #   #   #\n\
          #    #  ######  #    #  ######\n\
\n\
\n\
                  #    #  ######\n\
                  #    #  #\n\
                  #    #  #####\n\
                  # ## #  #\n\
                  ##  ##  #\n\
                  #    #  ######\n\
\n\
\n\
                   ####    ####\n\
                  #    #  #    #\n\
                  #       #    #\n\
                  #  ###  #    #\n\
                  #    #  #    #\n\
                   ####    ####\n\
\n\
\n\
                !! HummingBird !! \n\
\n\
   ######    ###    #####   #####          #     #\n\
   #     #    #    #     # #     #         #     #\n\
   #     #    #    #       #               #     #\n\
   ######     #     #####  #        #####  #     #\n\
   #   #      #          # #                #   #\n\
   #    #     #    #     # #     #           # #\n\
   #     #   ###    #####   #####             #\n\
\n\
 ";

//输出函数
void print_instructions()
{
  	//write (STDOUT_FILENO, instructions_msg, strlen(instructions_msg));
  	//write (STDOUT_FILENO, instructions_msg_sirv, strlen(instructions_msg_sirv));
  	printf("%s",instructions_msg_sirv);
}

//如果之前定义过使用板载按钮，那么可以使用这几个按钮触发GPIO的函数
#ifdef HAS_BOARD_BUTTONS
void button_0_handler(void)
{
  	//红灯亮
  	GPIO_REG(GPIO_OUTPUT_VAL) |= (0x1 << RED_LED_OFFSET);
  	//通过写1清除GPIO输出，可等待下一次输入
  	GPIO_REG(GPIO_RISE_IP) = (0x1 << BUTTON_0_OFFSET);
};

void button_1_handler(void)
{
  	//绿灯亮
  	GPIO_REG(GPIO_OUTPUT_VAL) |= (1 << GREEN_LED_OFFSET);
	//通过写1清除GPIO输出，等待下一次输入
  	GPIO_REG(GPIO_RISE_IP) = (0x1 << BUTTON_1_OFFSET);
};


void button_2_handler(void)
{
  	//蓝灯亮
  	GPIO_REG(GPIO_OUTPUT_VAL) |= (1 << BLUE_LED_OFFSET);
	//通过写1清除GPIO输出，等待下一次输入
  	GPIO_REG(GPIO_RISE_IP) = (0x1 << BUTTON_2_OFFSET);
};
#endif

void reset_demo()
{
	//关闭外部中断和定时器中断，等待初始化完毕
  	clear_csr(mie, MIP_MEIP);
  	clear_csr(mie, MIP_MTIP);

    //初始化中断处理函数
 	for (int i = 0; i < PLIC_NUM_INTERRUPTS; i++)
    {
    	g_ext_interrupt_handlers[i] = no_interrupt_handler;
  	}

#ifdef HAS_BOARD_BUTTONS
    //使能中断
    //设置由按钮触发的外部中断
  	g_ext_interrupt_handlers[INT_DEVICE_BUTTON_0] = button_0_handler;
  	g_ext_interrupt_handlers[INT_DEVICE_BUTTON_1] = button_1_handler;
    g_ext_interrupt_handlers[INT_DEVICE_BUTTON_2] = button_2_handler;
#endif
	
    //串口打印一大堆没用的东西
  	print_instructions();

#ifdef HAS_BOARD_BUTTONS
    //使能中断
    //在GPIO和PLIC两部分使能中断
  	PLIC_enable_interrupt (&g_plic, INT_DEVICE_BUTTON_0);
  	PLIC_enable_interrupt (&g_plic, INT_DEVICE_BUTTON_1);
  	PLIC_enable_interrupt (&g_plic, INT_DEVICE_BUTTON_2);
	
    //设置中断优先级
    //要使用中断必须要让优先级设置大于0
  	PLIC_set_priority(&g_plic, INT_DEVICE_BUTTON_0, 1);
  	PLIC_set_priority(&g_plic, INT_DEVICE_BUTTON_1, 1);
  	PLIC_set_priority(&g_plic, INT_DEVICE_BUTTON_2, 1);

    //设置中断触发沿
  	GPIO_REG(GPIO_RISE_IE) |= (1 << BUTTON_0_OFFSET);
  	GPIO_REG(GPIO_RISE_IE) |= (1 << BUTTON_1_OFFSET);
  	GPIO_REG(GPIO_RISE_IE) |= (1 << BUTTON_2_OFFSET);
#endif

    //将定时器设置为3s触发一次中断
    volatile uint64_t * mtime       = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);
    volatile uint64_t * mtimecmp    = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIMECMP);
    uint64_t now = *mtime;
    uint64_t then = now + 2*RTC_FREQ;
    *mtimecmp = then;

    //在MIE中使能GPIO、定时器、全局中断
    set_csr(mie, MIP_MEIP);
    set_csr(mie, MIP_MTIP);
    set_csr(mstatus, MSTATUS_MIE);
}

int main(int argc, char **argv)
{
  	//设置GPIO的输入、输出模式
#ifdef HAS_BOARD_BUTTONS
  	GPIO_REG(GPIO_OUTPUT_EN)  &= ~((0x1 << BUTTON_0_OFFSET) | (0x1 << BUTTON_1_OFFSET) | (0x1 << BUTTON_2_OFFSET));
  	GPIO_REG(GPIO_PULLUP_EN)  &= ~((0x1 << BUTTON_0_OFFSET) | (0x1 << BUTTON_1_OFFSET) | (0x1 << BUTTON_2_OFFSET));
  	GPIO_REG(GPIO_INPUT_EN)   |=  ((0x1 << BUTTON_0_OFFSET) | (0x1 << BUTTON_1_OFFSET) | (0x1 << BUTTON_2_OFFSET));
#endif

	//  GPIO_REG(GPIO_INPUT_EN)    &= ~((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET));
	//  GPIO_REG(GPIO_OUTPUT_EN)   |=  ((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET)) ;
	//  GPIO_REG(GPIO_OUTPUT_VAL)  |=  ((0x1 << RED_LED_OFFSET) | (0x1 << GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET));
	//  GPIO_REG(GPIO_OUTPUT_VAL)  &=  ~((0x1 << RED_LED_OFFSET) | (0x1 << GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET)) ;

  	GPIO_REG(GPIO_INPUT_EN) &= ~((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET) | (0x1<< PIN_16_OFFSET) | (0x1<< PIN_17_OFFSET) | (0x1<< PIN_18_OFFSET) | (0x1<< PIN_19_OFFSET));
 	GPIO_REG(GPIO_OUTPUT_EN) |= ((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET) | (0x1<< PIN_16_OFFSET) | (0x1<< PIN_17_OFFSET) | (0x1<< PIN_18_OFFSET) | (0x1<< PIN_19_OFFSET));
  	GPIO_REG(GPIO_OUTPUT_VAL) |= ((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET) | (0x1<< PIN_16_OFFSET) | (0x1<< PIN_17_OFFSET) | (0x1<< PIN_18_OFFSET) | (0x1<< PIN_19_OFFSET));
  	GPIO_REG(GPIO_OUTPUT_VAL) &= ~((0x1<< RED_LED_OFFSET) | (0x1<< GREEN_LED_OFFSET) | (0x1 << BLUE_LED_OFFSET) | (0x1<< PIN_16_OFFSET) | (0x1<< PIN_17_OFFSET) | (0x1<< PIN_18_OFFSET) | (0x1<< PIN_19_OFFSET));
  // For Bit-banging with Atomics demo.
  
  	uint32_t bitbang_mask = 0;
	#ifdef _SIFIVE_HIFIVE1_H
  		bitbang_mask = (1 << PIN_19_OFFSET);
	#else
	#ifdef _SIFIVE_COREPLEXIP_ARTY_H
  		bitbang_mask = (0x1 << JA_0_OFFSET);
	#endif
#endif
  	GPIO_REG(GPIO_OUTPUT_EN) |= bitbang_mask;
  
	//按照之前的初始化结构体和参数设置PLIC
  	PLIC_init(&g_plic,PLIC_CTRL_ADDR,PLIC_NUM_INTERRUPTS,PLIC_NUM_PRIORITIES);
	//执行示例程序
  	reset_demo();
  
  	while (1)
  	{
    	atomic_fetch_xor_explicit(&GPIO_REG(GPIO_OUTPUT_VAL), bitbang_mask, memory_order_relaxed);
  	}
  	return 0;
}
```

## 解析官方demo









## 编写点灯程序并烧录进丐版蜂鸟E203





