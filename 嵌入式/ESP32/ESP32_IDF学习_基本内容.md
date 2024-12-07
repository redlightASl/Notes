学校老师留了个作业，让用剩下一半的寒假学学ESP32，做蓝牙透传+STA&AP模式下工作的http服务器，但是不准用Arduino

当场就傻了：ESP32我刚刚好就会一手Arduino；乐鑫那套ESPIDF太难啃，之前点了个灯就去快乐stm32了；micropython......刷完固件发现蓝牙支持跟【数据删除】一样，还不如用c写——一咬牙一跺脚，回头肝ESPIDF吧

**==总体思路：资源少，跟着官方走准没错，硬啃就完事了==**

这个系列笔记可以供只接触过单片机开发（STM32、51基础）和硬件相关知识但没有接触过网络相关知识的同学翻阅学习

# 项目文件夹构建

ESP-IDF项目由各种“组件”构成，你需要什么功能就要往里扔进去什么组件

如果你的代码里用了一堆WiFi的库函数，但是没把WiFi组件加入进去，你是没办法用WiFi功能的

项目保存在项目文件夹下，它的根目录如下所示：

```
├── CMakeLists.txt				Cmake使用的文件
├── other_documents				其他文件
├── main						存储主程序
│   ├── CMakeLists.txt			
│   ├── component.mk           组件的make file
│   └── main.c
└── Makefile                   由传统的GNU make程序使用的Makefile
```

需要注意的是：**ESP-IDF并不是项目文件夹的一部分**，它更像是一个自助编译器，项目文件夹通过idf.py esptools等工具和\${IDF_PATH}与ESP-IDF目录建立联系；同样，esp的开发工具链也独立于项目存在，通过\${PATH}对项目进行作用

项目建立前，esp-idf会通过idf.py menuconfig配置出Makefile，这些配置保存在sdkconfig中。sdkconfig会被保存在项目文件夹的根目录

CMakeLists.txt通过idf_component_register将项目文件夹下面的组件进行注册，如下所示

```cmake
idf_component_register(SRCS "foo.c" "bar.c"
                       INCLUDE_DIRS "include"
                       REQUIRES mbedtls)
```

SRCS给出了源文件清单，能支持的源文件后缀名为.c .cpp .cc .S

INCLUDE_DIRS给出了组件中文件的搜索路径

REQUIRES不是必须的，它声明了其他需要加入的组件

通过这个txt文档，esp-idf就能知道你往里扔了什么组件，然后在编译的时候就会把这些组件编译链接进去（可以理解成操作系统的静态链接）

当编译完成后，文件根目录下会多出build文件夹和sdkconfig文件，build文件夹用来存放编译过程中的文件和生成的文件，sdkconfig文件是在menuconfig的过程中产生的，如果曾经多次重新设置过menuconfig，还会发现多出了以.old结尾的config文件

另外组件也可以自制，详细内容参考官方教程；而idf.py 的底层是用Cmake、make工具实现的，所以也可以直接用这些工具进行编译（不过应该没人这么干）

## CMake与component组件

【摘自官方文档】**一个ESP-IDF项目可以看作是多个不同组件（component）的集合**，组件是模块化且独立的代码，会被编译成静态库并链接到应用程序。ESP-IDF自带一些组件，也可以去找开源项目已有的组件来用

ESP-IDF的组件其实是对CMake的封装，如果使用纯CMake风格的构建方式也可行（说到底还是交叉编译的那套流程，只是乐鑫针对ESP32进行了优化），如下所示

```cmake
cmake_minimum_required(VERSION 3.5)
project(my_custom_app C)

# 源文件 main.c 包含有 app_main() 函数的定义
add_executable(${CMAKE_PROJECT_NAME}.elf main.c)

# 提供 idf_import_components 及 idf_link_components 函数
include($ENV{IDF_PATH}/tools/cmake/idf_functions.cmake)

# 为 idf_import_components 做一些配置
# 使能创建构件（不是每个项目都必须）
set(IDF_BUILD_ARTIFACTS ON)
set(IDF_PROJECT_EXECUTABLE ${CMAKE_PROJECT_NAME}.elf)
set(IDF_BUILD_ARTIFACTS_DIR ${CMAKE_BINARY_DIR})

# idf_import_components 封装了 add_subdirectory()，为组件创建库目标，然后使用给定的变量接收“返回”的库目标。
# 在本例中，返回的库目标被保存在“component”变量中。
idf_import_components(components $ENV{IDF_PATH} esp-idf)

# idf_link_components 封装了 target_link_libraries()，将被 idf_import_components 处理过的组件链接到目标
idf_link_components(${CMAKE_PROJECT_NAME}.elf "${components}")
```

示例项目的目录树结构可能如下所示：

```cmake
- myProject/ #主目录
             - CMakeLists.txt #全局CMAke文档，用于配置项目CMake
             - sdkconfig #项目配置文件，可用menuconfig生成
             - components/ - component1/ - CMakeLists.txt #组件的CMake文档，用于配置组件CMake
                                         - Kconfig #用于定义menuconfig时展示的组件配置选项
                                         - src1.c
                           - component2/ - CMakeLists.txt
                                         - Kconfig
                                         - src1.c
                                         - include/ - component2.h
             - main/ #可以将main目录看作特殊的伪组件       - src1.c
                           - src2.c
             - build/ #用于存放输出文件
```

`main` 目录是一个特殊的“伪组件”，包含项目本身的源代码。`main` 是默认名称，CMake 变量 `COMPONENT_DIRS` 默认包含此组件，但您可以修改此变量。或者，您也可以在顶层 CMakeLists.txt 中设置 `EXTRA_COMPONENT_DIRS` 变量以查找其他指定位置处的组件。如果项目中源文件较多，建议将其归于组件中，而不是全部放在 `main` 中。

## 全局CMake编写

全局CMake文档应该至少包含如下三个部分：

```cmake
cmake_minimum_required(VERSION 3.5) #必须放在第一行，设置构建该项目所需CMake的最小版本号
include($ENV{IDF_PATH}/tools/cmake/project.cmake) #用于导入CMake的其余功能来完成配置项目、检索组件等任务
project(myProject) #指定项目名称并创建项目，改名成蕙作为最终输出的bin文件或elf文件的名字
```

==每个 CMakeLists 文件只能定义一个项目==

还可以包含以下可选部分

```cmake
COMPONENT_DIRS #组件搜索目录，默认为${IDF_PATH}/components、${PROJECT_PATH}/components和EXTRA_COMPONENT_DIRS
COMPONENTS #要构建进项目中的组件名称列表，默认为COMPONENT_DIRS目录下检索到的所有组件
EXTRA_COMPONENT_DIRS #用于搜索组件的其它可选目录列表，可以是绝对路径也可以是相对路径
COMPONENT_REQUIRES_COMMON #每个组件都需要的通用组件列表，这些通用组件会自动添加到每个组件的COMPONENT_PRIV_REQUIRES列表和项目的COMPONENTS列表中
```

使用set命令来设置以上变量，如下所示

```cmake
set(COMPONENTS "COMPONENTx")
```

注意：**set命令需要放在include之前，cmake_minimum_required之后**

特别地，可以重命名main组件，分为两种情况

1. main组件处于正常位置`${PROJECT_PATH}/main`，则会被自动添加到构建系统中，其他组件**自动成为main的依赖项**，方便处理依赖关系

2. main组件被重命名为xxx，需要在全局CMake设定中设置EXTRA_COMPONENT_DIRS=${PROJECT_PATH}/xxx，并在组件CMake目录中设置COMPONENT_REQUIRES或COMPONENT_PRIV_REQUIRES以指定依赖项

## 组件CMake编写

每个项目都包含一个或多个组件，这些组件可以是 ESP-IDF 的一部分，可以是项目自身组件目录的一部分，也可以从自定义组件目录添加

组件是**COMPONENT_DIRS列表中包含CMakeLists.txt文件的任何目录**

ESP-IDF会搜索COMPONENT_DIRS中的目录列表来查找项目的组件此列表中的目录可以是组件自身（即包含CMakeLists.txt文件的目录），也可以是子目录为组件的顶级目录；搜索顺序：【ESP-IDF内部组件】-【项目组件】-【EXTRA_COMPONENT_DIRS】中的组件，如果这些目录中的两个或者多个包含具有相同名字的组件，则**使用搜索到的最后一个位置的组件**，允许将组件复制到项目目录中再修改以覆盖ESP-IDF组件

最小的组件CMakeLists如下

```cmake
set(COMPONENT_SRCS "foo.c" "k.c") #用空格分隔的源文件列表
set(COMPONENT_ADD_INCLUDEDIRS "include") #用空格分隔的目录列表，里面的路径会被添加到所有需要该组件的组件（包括 main 组件）全局 include 搜索路径中
register_component() #构建生成与组件同名的库，并最终被链接到应用程序中
```

有以下预设变量，不建议修改

```cmake
COMPONENT_PATH #组件目录，是包含CMakeLists.txt文件的绝对路径，注意路径中不能包含空格
COMPONENT_NAME #组件名，等同于组件目录名
COMPONENT_TARGET #库目标名，由CMake在内部自动创建
```

有以下项目级别的变量，不建议修改，但可以在组件CMake文档中使用

```cmake
PROJECT_NAME #项目名，在全局CMake文档中设置
PROJECT_PATH #项目目录（包含项目 CMakeLists 文件）的绝对路径，与CMAKE_SOURCE_DIR相同
COMPONENTS #此次构建中包含的所有组件的名称
CONFIG_* #项目配置中的每个值在cmake中都对应一个以CONFIG_开头的变量
IDF_VER #ESP-IDF的git版本号，由git describe命令生成
IDF_TARGET #项目的硬件目标名称，一般是ESP32
PROJECT_VER #项目版本号

COMPONENT_ADD_INCLUDEDIRS #相对于组件目录的相对路径，会被添加到所有需要该组件的其他组件的全局include搜索路径中
COMPONENT_REQUIRES #用空格分隔的组件列表，列出了当前组件依赖的其他组件
```

【摘自官网】如果一个组件仅需要额外组件的头文件来编译其源文件（而不是全局引入它们的头文件），则这些被依赖的组件需要在 `COMPONENT_PRIV_REQUIRES` 中指出

有以下可选的组件特定变量，用于控制某组件的行为

```cmake
COMPONENT_SRCS #要编译进当前组件的源文件的路径，推荐使用此方法向构建系统中添加源文件

COMPONENT_PRIV_INCLUDEDIRS #相对于组件目录的相对路径，仅会被添加到该组件的include搜索路径中
COMPONENT_PRIV_REQUIRES #以空格分隔的组件列表，用于编译或链接当前组件的源文件
COMPONENT_SRCDIRS #相对于组件目录的源文件目录路径，用于搜索源文件，匹配成功的源文件会替代COMPONENT_SRCS中指定的源文件
COMPONENT_SRCEXCLUDE #需要从组件中 剔除 的源文件路径
COMPONENT_ADD_LDFRAGMENTS #组件使用的链接片段文件的路径，用于自动生成链接器脚本文件
```

## 组件配置文件Kconfig

每个组件都可以包含一个Kconfig文件，和CMakeLists.txt放在同一目录下

Kconfig文件中包含要添加到该组件配置菜单中的一些配置设置信息，运行menuconfig时，可以在Component Settings菜单栏下找到这些设置

# 有手就行的入门

```c
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "esp_log.h"
//固定需要include的头文件
//用于freertos支持和输出调试信息
```

以下内容头文件包含部分会省略这些

一般程序的入口是app_main()函数

```c
void app_main(void)
```

## 点灯

```c
#include "driver/gpio.h"

#define BLINK_GPIO CONFIG_BLINK_GPIO
/*Kconfig.projbuild文件内容如下

menu "Example Configuration"

    config BLINK_GPIO
        int "Blink GPIO number"
        range 0 34
        default 5
        help
            GPIO number (IOxx) to blink on and off.
            Some GPIOs are used for other purposes (flash connections, etc.) and cannot be used to blink.
            GPIOs 35-39 are input-only so cannot be used as outputs.

endmenu
这个文件的内容是在c预编译器之前进行的替换，会把CONFIG_BLINK_GPIO变成default的值（5）
*/

void app_main(void)
{
    gpio_pad_select_gpio(BLINK_GPIO);//选择的引脚
    gpio_set_direction(BLINK_GPIO,GPIO_MODE_OUTPUT);//设置输入输出方向
    while(1)
    {
		printf("Turning off the LED\n");//串口打印信息
        gpio_set_level(BLINK_GPIO, 0);//GPIO寄存器清零
        vTaskDelay(1000 / portTICK_PERIOD_MS);//vTaskDelay()用于任务中的延时，下面会提到这其实是将任务转入阻塞态

		printf("Turning on the LED\n");
        gpio_set_level(BLINK_GPIO, 1);//GPIO寄存器置位
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
}
```

## UART

官方给出的配置步骤为：

1. 设置uart_config_t配置结构体
2. 通过ESP_ERROR_CHECK(uart_param_config(uart_num, &uart_config));应用设置
3. 设置引脚
4. 安装驱动，设置buffer和事件处理函数等
5. 配置FSM并运行UART

```c
#include "string.h"
#include "esp_system.h"
#include "driver/uart.h"
#include "driver/gpio.h"
//include uart库和gpio库来实现相应功能

void UART_init(void)//uart初始化函数
{
    const uart_config_t uart_config =
    {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_APB,
    };//配置uart设置
    ESP_ERROR_CHECK(uart_param_config(UART_NUM_1, &uart_config));//应用设置
    //设置uart引脚
    ESP_ERROR_CHECK(uart_set_pin(UART_NUM_1, TXD_PIN, RXD_PIN, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));
    //使用buffer的情况,使用freertos提供的设备驱动
    ESP_ERROR_CHECK(uart_driver_install(UART_NUM_1, RX_BUF_SIZE * 2,0,0, NULL, 0));
}

int UART_send_data(const char* TAG, const char* data)//发送数据函数
{
    const int length = uart_write_bytes(UART_NUM_1, data, strlen(data));
    ESP_LOGI(TAG, "Wrote %d bytes", length);
    return length;
}

int UART_read_data(const char* TAG, const char* buffer)//收取数据函数
{
	int length = 0;
	ESP_ERROR_CHECK(uart_get_buffered_data_len(UART_NUM_1, (size_t*)&length));
	length = uart_read_bytes(UART_NUM_1,buffer,length,100);
    ESP_LOGI(TAG, "Read %d bytes", length);
    return length;
}

void app_main(void)
{
    UART_init();//初始化
    
    //分别配置发送和接收串口信息的任务
    xTaskCreate(rx_task, "uart_rx_task", 1024*2, NULL, configMAX_PRIORITIES, NULL);
    xTaskCreate(tx_task, "uart_tx_task", 1024*2, NULL, configMAX_PRIORITIES-1, NULL);
}
```

## console控制台

ESP提供了一个console用于串口调试，可以实现类似shell的操作

在固件中加入console相关组件后烧录，在串口中打出help就可以查看相关帮助

```c
void register_system(void)//系统相关指令
{
    register_free();
    register_heap();
    register_version();
    register_restart();
    register_deep_sleep();
    register_light_sleep();
#if WITH_TASKS_INFO
    register_tasks();
#endif
}
```

组件中两个目录 ：cmd_nvs用于指令的识别；cmd_system用于系统指令的实现（这部分功能需要与RTOS配合才行）

## NVS FLASH

NVS即Non-volatile storage非易失性存储

它相当于把ESP32的关键数据以**键值格式**存储在FLASH里，NVS通过`spi_flash_{read|write|erase}`三个API进行操作，NVS使用主flash的一部分。管理方式类似数据库的表，在NVS里面可以存储很多个不同的表，每个表下面有不同的键值，每个键值可以存储8位、16位、32位等等不同的数据类型，但**不能是浮点数**

1. 使用接口函数nvs_flash_init();进行初始化，如果失败可以使用nvs_flash_erase();先擦除再初始化
2. 应用程序可以使用nvs_open();选用NVS表中的分区或通过nvs_open_from_part()指定其名称后使用其他分区

注意：**NVS分区被截断时，其内容应该被擦除**

### 读写操作

```c
nvs_get_i8(my_handle,//表的句柄
           "nvs_i8",//键值
           &nvs_i8);//对应变量的指针
//使用这个API来读取8位数据，同理还有i16、u32等版本的API可用

nvs_set_i8(my_handle,//表的句柄
           "nvs_i8",//键值
           nvs_i8);//对应的变量
//使用这个API来写入8位数据，同理还有i16、u32等版本的API可用
```

### 表操作

```c
nvs_open("List",//表名
         NVS_READWRITE,//读写模式，可选读写模式或只读模式
         &my_handle);//表的句柄
//打开表

nvs_commit(my_handle);//提交表
nvs_close(my_handle);//关闭表
```

### NVS初始化示例程序

官方给出的示例程序中一般以以下形式初始化NVS

```c
//Initialize NVS
esp_err_t ret = nvs_flash_init();//初始化
if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)//如果初始化未成功
{
	ESP_ERROR_CHECK(nvs_flash_erase());//擦除NVS并查错
	ret = nvs_flash_init();//再次初始化
}
ESP_ERROR_CHECK(ret);//查错
```

# ESPIDF提供的常用库函数

## ESP_LOG打印系统日志到串口

```c
#include "esp_err.h"
//用于打印错误信息
```

*  ESP_LOGE - 错误日志 (最高优先级)
* ESP_LOGW - 警告日志
* ESP_LOGI - 信息级别的日志
* ESP_LOGD - 用于调试的日志
* ESP_LOGV - 仅仅用于提示的日志{最低优先级)

这些日志可以在menuconfig设置中打开或关闭，也可以在代码中手动设置关闭

## RTOS操作

1. vTaskDelay将任务置为阻塞状态，期间CPU继续运行其它任务

持续时间由参数xTicksToDelay指定，**单位是系统节拍时钟周期**

```c
void vTaskDelay(portTickTypexTicksToDelay)
```

常量portTickTypexTicksToDelay用来辅助计算真实时间，此值是系统节拍时钟中断的周期，单位是ms

在文件FreeRTOSConfig.h中，宏INCLUDE_vTaskDelay 必须设置成1，此函数才能有效

2. xTaskCreate创建新的任务并添加到任务队列

注意：**所有任务应当为死循环且永远不会返回，即嵌套在while(1)内**

```c
xTaskCreate(pdTASK_CODE pvTaskCode,//指向任务的入口函数
            const portCHAR * const pcName,//任务名
            unsigned portSHORT usStackDepth,//任务堆栈大小
            void *pvParameters,//任务参数指针
            unsigned portBASE_TYPE uxPriority,//任务优先级
            xTaskHandle *pvCreatedTask)//任务句柄，用于引用创建的任务
```

注意，**任务优先级0为最低，数字越大优先级越高**

3. FreeRTOS的神奇之处

一句话概论：**RTOS就是彳亍**，FreeRTOS可以实现任务之间的时间片轮转调度，两个任务可以你执行一会我执行一会，高优先级任务还能抢占低优先级任务，让它马上爪巴，高优先级任务先运行

- FreeRTOS的底层实现还没看明白，过一阵子再学，反正效果和RTThread差不多，先把作业肝完再说 =)

这种神奇的操作靠的就是上面两个API

需要注意的是：**所有任务应当为死循环且永远不会返回**（两次强调）

不过如果实在不想写死循环，可以在任务末尾加上

```c
vTaskDelete();//用于删除执行结束的任务
```

不过只执行一次的任务大多是在初始化阶段完成的，用的时候尽量小心些

4. 事件event

事件是一种实现任务间通信的机制，主要用于实现多任务间的同步，但事件通信只能是事件类型的通信，无数据传输。事件可以实现一对多和多对多的传输：一个任务可以等待多个事件的发生：可以是任意一个事件发生时唤醒任务进行事件处理；也可以是几个事件都发生后才唤醒任务进行事件处理

```c
#include "esp_event.h"
//include 这个文件才能使用event
```

事件使用**事件循环**来管理，事件循环分别为默认事件循环和自定义事件循环

默认事件循环不需要传入事件循环句柄；但自定义循环需要

```c
esp_event_loop_create(const esp_event_loop_args_t *event_loop_args,//事件循环参数
                      esp_event_loop_handle_t *event_loop)//事件循环句柄
//用于创建一个事件循环   
esp_event_loop_delete(esp_event_loop_handle_t event_loop)//删除事件循环
```

事件需要**注册**到事件循环

```c
/* 注册事件到事件循环 */
esp_event_handler_instance_register(esp_event_base_t event_base,//事件基本ID
                                    int32_t event_id,//事件ID
                                    esp_event_handler_t event_handler,//事件回调函数指针（句柄）
                                    void *event_handler_arg,//事件回调函数参数
                                    esp_event_handler_instance_t *instance)
//如果事件回调函数在事件删除之前还没有被注册，需要在这里注册来进行调用
    
esp_event_handler_instance_register_with(esp_event_loop_handle_t event_loop,//事件循环句柄
                                         esp_event_base_t event_base,//事件基本ID
                                         int32_t event_id,//事件ID
                                         esp_event_handler_t event_handler,//事件回调函数指针（句柄）
                                         void *event_handler_arg,//事件回调函数参数
                                         esp_event_handler_instance_t *instance)
//如果事件回调函数在事件删除之前还没有被注册，需要在这里注册来进行调用
    
esp_event_handler_register(esp_event_base_t event_base,//事件基本ID
                           int32_t event_id,//事件ID
                           esp_event_handler_t event_handler,//事件句柄
                           void *event_handler_arg)//事件参数
    
esp_event_handler_register_with(esp_event_loop_handle_t event_loop,//事件循环句柄
                                esp_event_base_t event_base,//事件基本ID
                                int32_t event_id,//事件ID
                                esp_event_handler_t event_handler,//事件回调函数指针（句柄）
                                void *event_handler_arg)//事件回调函数的参数
    
/* 取消注册 */
esp_event_handler_unregister(esp_event_base_t event_base,
                             int32_t event_id,
                             esp_event_handler_t event_handler)
esp_event_handler_unregister_with(esp_event_loop_handle_t event_loop,
                                  esp_event_base_t event_base,
                                  int32_t event_id,
                                  esp_event_handler_t event_handler)
```

默认事件循环default event loop是系统的基础事件循环，用于传递系统事件（如WiFi等），但是也可以注册用户事件，一般的蓝牙+WiFi用这一个循环就足够了

```c
esp_event_loop_create_default(void)//创建默认事件循环
esp_event_loop_delete_default(void)//删除默认事件循环
```

```c
esp_event_loop_run(esp_event_loop_handle_t event_loop,//事件循环句柄
                   TickType_t ticks_to_run)//运行时间
```

默认事件和自定义事件之间可以进行**发送**操作

```c
esp_event_post(esp_event_base_t event_base, int32_t event_id, void *event_data, size_t event_data_size, TickType_t ticks_to_wait)
```

使用宏

```c
ESP_EVENT_DECLARE_BASE()
ESP_EVENT_DEFINE_BASE()
```

来声明和定义事件，同时事件的ID应该用enum枚举变量来指出，如下所示

```c
/* 头文件 */
// Declarations for event source 1: periodic timer
#define TIMER_EXPIRIES_COUNT// number of times the periodic timer expires before being stopped
#define TIMER_PERIOD                1000000  // period of the timer event source in microseconds

extern esp_timer_handle_t g_timer;           // the periodic timer object

// Declare an event base
ESP_EVENT_DECLARE_BASE(TIMER_EVENTS);        // declaration of the timer events family

enum {// declaration of the specific events under the timer event family
    TIMER_EVENT_STARTED,                     // raised when the timer is first started
    TIMER_EVENT_EXPIRY,                      // raised when a period of the timer has elapsed
    TIMER_EVENT_STOPPED                      // raised when the timer has been stopped
};

// Declarations for event source 2: task
#define TASK_ITERATIONS_COUNT        5       // number of times the task iterates
#define TASK_ITERATIONS_UNREGISTER   3       // count at which the task event handler is unregistered
#define TASK_PERIOD                  500     // period of the task loop in milliseconds

ESP_EVENT_DECLARE_BASE(TASK_EVENTS);         // declaration of the task events family

enum {
    TASK_ITERATION_EVENT,                    // raised during an iteration of the loop within the task
};
/* 头文件 */

/* 源文件 */
ESP_EVENT_DEFINE_BASE(TIMER_EVENTS);
/* 源文件 */

/* 枚举定义的事件名应该放在头文件，宏函数应该放在源文件 */
```

可使用API esp_event_loop_create_default()来创建事件

```c
esp_event_loop_create_default()
```

