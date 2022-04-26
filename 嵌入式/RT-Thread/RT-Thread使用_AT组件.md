[TOC]

# AT指令

AT指令最早是由发明拨号调制解调器（MODEM）的贺氏公司（Hayes）为了控制MODEM而发明的控制协议，随着网络带宽升级，MODEM退出一般使用市场后，AT指令保留了下来，当时主要的移动电话生产厂家GSM研制了一套AT命令用于控制手机的GSM模块，AT指令在此基础上演化并加入GSM 07.05标准和后来的GSM 07.07标准，实现了标准化。随后GPRS控制、3G模块等方面均采用AT指令来控制，AT指令爷爷广泛应用于嵌入式开发领域：**使用串口收发AT指令来实现主芯片和通讯模块的协议接口**，来让主设备能通过简单的命令和硬件设计完成多种操作

**AT命令集是一种应用于AT服务器（AT Server）于AT客户端（AT Client）间的设备连接于数据通信的方式**，基本结构图如下

![image-20210226145046745](RT-Thread使用_AT组件.assets/image-20210226145046745.png)

* AT Client会向AT Server发送AT指令。==AT指令由三部分构成：前缀（由字符AT构成）、主体（由命令、参数和可能用到的数据构成）和结束符（设置为\r\n）==
* AT Server会向AT Client发送响应数据和URC数据。==响应数据就是AT Client发送命令后收到的AT Server响应状态和信息==；==URC数据是AT Server主动发送给AT Client的数据，当出现特殊情况（如wifi断开、TCP接收数据等）时才会发送==

* AT功能的实现需要AT Server和AT Client两部分共同完成：AT Server主要用于接收AT Client发送的命令、判断接收的命令和参数格式，并下发对应的响应数据，也可以主动下发数据；AT Client主要用于发送命令、等待AT Server响应，并对AT Server响应数据或主动发送的数据进行解析处理

* 两者之间支持多种数据通讯方式（UART、SPI等），**目前最常用的是UART串口通讯**

虽然AT指令进行了标准化，但不同的芯片支持的AT命令并没有完全统一。RTT提供了AT组件用于统筹管理AT设备的连接和数据通讯

# AT组件

AT 组件基于RT-Thread系统的AT Server和AT Client实现。通过 AT 组件，设备可以作为AT Client使用串口连接其他设备发送并接收解析数据；可以作为AT Server 让其他设备甚至电脑端连接完成发送数据的响应；也可以在本地shell启动CLI（Command Line Shell命令行接口）模式使设备同时支持AT Server和AT  Client功能（该模式多用于设备开发调试）

**AT组件代码主要位于`rt-thread/components/net/at/`目录中**

## 简介

### 资源占用

AT组件资源占用极小

- AT Client 功能：4.6K ROM 和 2.0K RAM；
- AT Server 功能：4.0K ROM 和 2.5K RAM；
- AT CLI 功能： 1.5K ROM ，几乎没有使用 RAM。

### 主要功能

1. AT Server
   * 实现基础AT指令，指令支持忽略大小写，支持自定义参数表达式
   * 可实现接受命令参数自检测
   * **提供简单的用户自定义命令添加**
   * 支持CLI命令行交互调试

2. AT Client
   * 支持完整的URC数据处理
   * 支持自定义响应数据的解析
   * 支持通过AT指令收发实现标准的BSD Socket API来完成数据收发，**可以通过AT指令进行设备联网和数据通讯**
   * **支持多客户端同时运行**
   * 支持CLI命令行交互调试

## AT Server

### 启用和初始化

当我们使用 AT 组件中的 AT Server 功能时需要在 rtconfig.h 中定义如下配置：

| **宏定义**              | **描述**                                                     |
| ----------------------- | ------------------------------------------------------------ |
| RT_USING_AT             | 开启 AT 组件                                                 |
| AT_USING_SERVER         | 开启 AT Server 功能                                          |
| AT_SERVER_DEVICE        | 定义设备上 AT Server 功能使用的串口通讯设备名称，确保未被使用且设备名称唯一，例如 `uart3` 设备 |
| AT_SERVER_RECV_BUFF_LEN | AT Server 设备最大接收数据的长度                             |
| AT_CMD_END_MARK_CRLF    | 判断接收命令的行结束符                                       |
| AT_USING_CLI            | 开启服务器命令行交互模式                                     |
| AT_DEBUG                | 开启 AT 组件 DEBUG 模式，可以显示更多调试日志信息            |
| AT_PRINT_RAW_CMD        | 开启实时显示 AT 命令通信数据模式，方便调试                   |

对于不同的 AT 设备，发送命令的行结束符的格式有几种： `"\r\n"`、`"\r"`、`"\n"`，用户需要根据 AT Server 连接的设备类型选用对应的行结束符，进而判断发送命令行的结束， 定义的方式如下：

| **宏定义**           | **结束符** |
| -------------------- | ---------- |
| AT_CMD_END_MARK_CRLF | `"\r\n"`   |
| AT_CMD_END_MARK_CR   | `"\r"`     |
| AT_CMD_END_MARK_LF   | `"\n"`     |

也可以在ENV工具或RTT Studio中进行可视化配置

配置开启 AT Server 配置之后，需要在启动时对它进行初始化，开启 AT Server 功能，如果程序中已经使用了组件自动初始化，则不再需要额外进行单独的初始化，否则需要在初始化任务中调用如下函数：

```c
int at_server_init(void);//AT Server初始化函数
```

此函数应当在使用AT Server功能前被调用，该API会调配系统资源并单独创建at_server线程用于AT Server中数据的接收和解析

AT Server 初始化成功之后，设备就可以作为 AT 服务器与 AT 客户端的串口设备连接并进行数据通讯，或者使用串口转化工具连接 PC，使 PC 端串口调试助手作为 AT 客户端与其进行数据通讯

### 自定义AT指令添加

AT 组件中的 AT Server只支持了部分基础通用AT命令，AT Server目前默认支持的基础命令如下：

- AT：AT 测试命令
- ATZ：设备恢复出厂设置
- AT+RST：设备重启
- ATE：ATE1 开启回显，ATE0 关闭回显
- AT&L：列出全部命令列表
- AT+UART：设置串口设置信息

AT 命令根据传入的参数格式不同可以实现不同的功能，对于每个AT命令最多包含四种功能：

- 测试功能：`AT+<x>=?` 用于查询命令参数格式及取值范围
- 查询功能：`AT+<x>?` 用于返回命令参数当前值
- 设置功能：`AT+<x>=...` 用于用户自定义参数值
- 执行功能：`AT+<x>` 用于执行相关操作

每个命令的四种功能并不需要全部实现，用户自定义添加AT Server命令时，可根据自己需求实现一种或几种上述功能函数，未实现的功能可以使用 `NULL` 表示，再通过自定义命令添加函数添加到基础命令列表

使用以下API进行自定义命令：

```c
AT_CMD_EXPORT(_name_,//命令名称
              _args_expr_,//命令参数表达式，无参数为NULL，必须参数用<>括起，可选参数用[]括起
              _test_,//测试功能函数名
              _query_,//查询功能函数名
              _setup_,//设置功能函数名
              _exec_);//执行功能函数名
```

如果后面的几个函数没有实现则写入NULL

使用例：

```c
static at_result_t at_test_exec(void)
{
    at_server_printfln("AT test commands execute!");
    return 0;
}
static at_result_t at_test_query(void)
{
    at_server_printfln("AT+TEST=1,2");
    return 0;
}
AT_CMD_EXPORT("AT+TEST", =<value1>[,<value2>], NULL, at_test_query, NULL, at_test_exec);
```

### AT Server API

#### 发送数据

```c
void at_server_printf(const char *format, ...);//不换行发送
void at_server_printfln(const char *format, ...);//换行发送
```

这两个API用于AT Server通过串口设备发送固定格式的数据到对应的AT Client串口设备上，区别在于结尾带不带换行符。用于自定义AT Server中AT命令的功能函数中。

其中`format`表示自定义输入数据的表达式，`...`为输入数据列表，以可变参数实现

#### 发送命令执行结果至客户端

```c
void at_server_print_result(at_result_t result);
```

AT组件提供多种固定的命令执行结果类型，自定义命令时可以直接使用函数返回结果

结果类型如下

```c
AT_RESULT_OK //执行成功
AT_RESULT_FAILE //执行失败
AT_RESULT_NULL //无返回结果
AT_RESULT_CMD_ERR //输入命令错误
AT_RESULT_CHECK_FAILE //参数表达式匹配错误
AT_RESULT_PARSE_FAILE //参数解析错误
```

#### 解析输入命令参数

使用以下API解析传入字符串参数，得到对应的多个输入参数来执行后面操作

```c
int at_req_parse_args(const char *req_args,//请求命令的传入参数字符串
                      const char *req_expr,//自定义参数解析表达式，用于解析上述传入参数数据
                      ...);//输出的解析参数列表，为可变参数
```

这个解析语法使用的标准**sscanf解析语法**，语法较多，可以使用时查阅

#### 移植API

AT 组件源码src/at_server.c文件中给出了移植文件的*弱函数定义*，用户可在项目中新建移植文件实现如下函数来完成移植接口，也可以直接在文件中修改弱函数完成移植接口

1. 设备重启函数`void at_port_reset(void)`：用于完成设备软重启功能，用于实现AT+RST
2. 设备恢复出厂设置函数`void at_port_factory_reset(void)`：用于实现设备恢复出厂设置ATZ指令
3. 连接脚本中添加命令表（如果使用gcc工具链则需要在链接脚本中添加AT服务器命令表对应的section，使用keil、iar则不需要这一步）

## AT Client

当我们使用 AT 组件中的 AT Client 功能是需要在 rtconfig.h 中定义如下配置：

```c
#define RT_USING_AT //用于开启或关闭 AT 组件
#define AT_USING_CLIENT //用于开启 AT Client 功能
#define AT_CLIENT_NUM_MAX 1 //最大同时支持的 AT 客户端数量
#define AT_USING_SOCKET //用于 AT 客户端支持标准 BSD Socket API，开启 AT Socket 功能
#define AT_USING_CLI //用于开启或关闭客户端命令行交互模式
#define AT_PRINT_RAW_CMD //用于开启 AT 命令通信数据的实时显示模式
```

也可以在ENV工具或RTT Studio中进行可视化配置

配置开启 AT Client 配置之后，需要在启动时对它进行初始化，开启 AT client 功能，如果程序中已经使用了组件自动初始化，则不再需要额外进行单独的初始化，否则需要在初始化任务中调用如下函数：

```c
int at_client_init(const char *dev_name,  rt_size_t recv_bufsz);//AT Client初始化函数
```

此函数应当在使用AT Client功能前被调用，该API会完成AT Client设备初始化、操作函数初始化并调配系统资源，创建at_client线程处理AT Client数据的解析和对URC数据的处理

### AT Client的数据收发方式

RTT的AT组件使用AT指令响应数据控制块来控制AT命令的收发，定义如下：

```c
struct at_response
{
    char *buf;//响应数据缓冲区指针
    rt_size_t buf_size;//本次响应最大支持的接收数据长度
    rt_size_t line_num;//本次响应数据需要接收的行数
    rt_size_t line_counts;//本次响应数据总行数
    rt_int32_t timeout;//本次响应数据最大响应时间
};
typedef struct at_response *at_response_t;
```

注意：**buf中存放的数据是原始响应数据去除结束符\r\n后得到的数据**，buf中**每行数据以'\0'分割，按行获取数据**

**如果没有响应行数的需求，可以设置line_num=0**

#### 创建、删除响应结构体

使用以下API创建一个响应结构体，注意在调用之前一般不用设置响应结构体的内容，创建后可以使用下面的设置响应结构体参数API配置

```c
at_response_t at_create_resp(rt_size_t buf_size,//本次响应最大支持的接收数据的长度
                             rt_size_t line_num,//本次响应需要返回数据的行数
                             rt_int32_t timeout);//本次响应数据最大响应时间，如果超时则会返回错误
```

line_num设定中，行数是以标准结束符\r\n划分的；若设置为0，则接收到“OK”或“ERROR”数据后结束本次响应接收；若大于0，则接收完成当前设置行号的数据后返回成功

使用以下API删除创建的响应结构体对象

```c
void at_delete_resp(at_response_t resp);
```

应当与at_create_resp()函数成对使用

#### 设置响应结构体参数

```c
at_response_t at_resp_set_info(at_response_t resp,//已经创建的响应结构体指针
                               rt_size_t buf_size,//本次响应最大支持的接收数据的长度
                               rt_size_t line_num,//本次响应需要返回数据的行数，划分原理和注意事项同上
                               rt_int32_t timeout);//本次响应数据最大响应时间
```

用于设置已经创建的响应结构体信息，主要设置对响应数据的限制信息，一般用于创建结构体之后，发送AT命令之前

#### 发送命令并接收响应

```c
rt_err_t at_exec_cmd(at_response_t resp,//响应结构体指针
                     const char *cmd_expr,//自定义输入命令的表达式
                     ...);//输入命令数据列表，为可变参数
```

该函数用于AT Client发送命令到AT Server，并等待接收响应

注意：**使用该函数前需要对响应结构体完成初始化和设置**，**输入命令的结尾不需要添加命令结束符**

正常情况下需要先创建resp响应结构体传入at_exec_cmd()函数用于数据的接收，当at_exec_cmd()函数传入resp为NULL时说明本次发送数据**不考虑处理响应数据直接返回结果**

使用例如下：

```c
#include <rtthread.h>
#include <at.h> /* AT 组件头文件 */

int at_client_send(int argc, char**argv)
{
    at_response_t resp = RT_NULL;

    if (argc != 2)
    {
        LOG_E("at_cli_send [command]  - AT client send commands to AT server.");
        return -RT_ERROR;
    }

    /* 创建响应结构体，设置最大支持响应数据长度为 512 字节，响应数据行数无限制，超时时间为 5 秒 */
    resp = at_create_resp(512, 0, rt_tick_from_millisecond(5000));
    if (!resp)
    {
        LOG_E("No memory for response structure!");
        return -RT_ENOMEM;
    }

    /* 发送 AT 命令并接收 AT Server 响应数据，数据及信息存放在 resp 结构体中 */
    if (at_exec_cmd(resp, argv[1]) != RT_EOK)
    {
        LOG_E("AT client send commands failed, response error or timeout !");
        return -ET_ERROR;
    }
    /* 命令发送成功 */
    LOG_D("AT Client send commands to AT Server success!");
    /* 删除响应结构体 */
    at_delete_resp(resp);

    return RT_EOK;
}
```

### AT Client的数据解析方式

AT Client中数据的解析提供自定义解析表达式的解析形式，其解析语法使用标准的*sscanf解析语法*。开发者可以通过自定义数据解析表达式获取响应数据中有用信息

#### 获取指定行号的响应数据

使用以下API在AT Server的响应数据中获取指定行号的一行数据（行号是以标准数据结束符来判断的）

```c
const char *at_resp_get_line(at_response_t resp,//响应结构体指针
                             rt_size_t resp_line);//需要获取数据的行号
```

通过使用发送和接收函数at_exec_cmd()，对响应数据的数据和行号进行记录处理，存放于resp响应结构体中，这里可以直接获取对应行号的数据信息

#### 获取指定关键字的响应数据

```c
const char *at_resp_get_line_by_kw(at_response_t resp, const char *keyword);//关键字信息
```

用于在AT Server响应数据中通过关键字获取对应的一行数据

#### 解析指定行号的响应数据

使用以下API获取指定行号的一行数据, 并解析该行数据中的参数

```c
int at_resp_parse_line_args(at_response_t resp,//响应结构体指针
                            rt_size_t resp_line,//需要解析数据的行号，行号从1开始计数
                            const char *resp_expr,//自定义的参数解析表达式
                            ...);//解析参数列表，为可变参数
```

#### 解析指定关键字一行的响应数据

```c
int at_resp_parse_line_args_by_kw(at_response_t resp, const char *keyword, const char *resp_expr, ...);
```

该函数获取包含关键字keyword的一行数据, 并解析该行数据中的参数

### URC数据处理

**URC数据为服务器主动下发的数据，不能通过上述数据发送接收函数接收**；对于不同设备 URC 数据格式和功能不一样，URC数据处理的方式也需要用户自定义实现

RTT使用URC数据结构体控制块来匹配URC数据。一段数据只有完全匹配URC的前缀和后缀才能定义为URC数据，获取到匹配的URC数据后会立刻执行URC数据执行函数，开发自定义URC数据处理的方式就是**自定义匹配的前缀、后缀和执行函数**

结构体控制块定义如下：

```c
struct at_urc
{
    const char *cmd_prefix; // URC 数据前缀
    const char *cmd_suffix; // URC 数据后缀
    void (*func)(const char *data, rt_size_t size); // URC 数据执行函数
};
typedef struct at_urc *at_urc_t;
```

#### URC数据列表初始化

```c
void at_set_urc_table(const struct at_urc *table,//URC数据结构体数组指针
                      rt_size_t size);//URC数据的个数
```

该函数用于初始化开发者自定义的URC数据列表

### 其他API

```c
rt_size_t at_client_send(const char *buf, rt_size_t size);//发送指定长度数据
rt_size_t at_client_recv(char *buf, rt_size_t size,rt_int32_t timeout);//接收指定长度数据
void at_set_end_sign(char ch);//设置接收数据的行结束符
int at_client_wait_connect(rt_uint32_t timeout);//等待模块初始化完成
```

### 多客户端支持

（以下内容全部来自官方文档）

AT组件提供对多客户端连接的支持，并且提供两套不同的函数接口：**单客户端模式函数**和**多客户端模式函数**。

多客户端模式函数主要用于设备连接多个AT模块的情况

单客户端模式函数默认使用第一个初始化的AT客户端对象，多客户端模式函数可以传入用户自定义获取的客户端对象, 获取客户端对象的函数如下：

```c
at_client_t at_client_get(const char *dev_name);
```

该函数通过传入的设备名称获取该设备创建的AT客户端对象，用于多客户端连接时区分不同的客户端

单客户端模式和多客户端模式函数接口定义区别如下几个函数：

| 单客户端模式函数            | 多客户端模式函数                        |
| --------------------------- | --------------------------------------- |
| at_exec_cmd(...)            | at_obj_exec_cmd(client, ...)            |
| at_set_end_sign(...)        | at_obj_set_end_sign(client, ...)        |
| at_set_urc_table(...)       | at_obj_set_urc_table(client, ...)       |
| at_client_wait_connect(...) | at_client_obj_wait_connect(client, ...) |
| at_client_send(...)         | at_client_obj_send(client, ...)         |
| at_client_recv(...)         | at_client_obj_recv(client, ...)         |

使用例：

```c
/* 单客户端模式函数使用方式 */

at_response_t resp = RT_NULL;

at_client_init("uart2", 512);

resp = at_create_resp(256, 0, 5000);

/* 使用单客户端模式函数发送命令 */
at_exec_cmd(resp, "AT+CIFSR");

at_delete_resp(resp);
/**************************************************************************************************/
/* 多客户端模式函数使用方式 */
at_response_t resp = RT_NULL;
at_client_t client = RT_NULL;

/* 初始化两个 AT 客户端 */
at_client_init("uart2", 512);
at_client_init("uart3", 512);

/* 通过名称获取对应的 AT 客户端对象 */
client = at_client_get("uart3");

resp = at_create_resp(256, 0, 5000);

/* 使用多客户端模式函数发送命令 */
at_obj_exec_cmd(client, resp, "AT+CIFSR");

at_delete_resp(resp);
```