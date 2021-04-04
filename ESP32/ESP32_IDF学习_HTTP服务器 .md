# TCP/IP组件

ESP系列提供了实现TCP/IP协议栈的库函数，`#include <esp_netif.h>`即可使用这些库函数

特点如下：

* 提供TCP/IP协议栈的应用抽象层
* 提供线程保护
* 目前只用于lwIP TCP/IP协议栈（lwIP：Light Weight IP Protocol，支持在嵌入式设备中使用的小型TCP/IP协议栈，占用内存较少）
* 具有丰富的API库函数
* 大多数情况下，应用程序不需要直接调用组件的API，而是从默认的网络事件处理函数中调用
* 不兼容idf4.1以下使用的TCP/IP适配器相关函数，需修改代码进行迁移

ESP-NETIF结构如下

```
                 |          (A) USER CODE                 |
                 |                                        |
    .............| init          settings      events     |
    .            +----------------------------------------+
    .               .                |           *
    .               .                |           *
--------+        +===========================+   *     +-----------------------+
        |        | new/config     get/set    |   *     |                       |
        |        |                           |...*.....| init                  |
        |        |---------------------------|   *     |                       |
  init  |        |                           |****     |                       |
  start |********|  event handler            |*********|  DHCP                 |
  stop  |        |                           |         |                       |
        |        |---------------------------|         |                       |
        |        |                           |         |    NETIF              |
  +-----|        |                           |         +-----------------+     |
  | glue|----<---|  esp_netif_transmit       |--<------| netif_output    |     |
  |     |        |                           |         |                 |     |
  |     |---->---|  esp_netif_receive        |-->------| netif_input     |     |
  |     |        |                           |         + ----------------+     |
  |     |....<...|  esp_netif_free_rx_buffer |...<.....| packet buffer         |
  +-----|        |                           |         |                       |
        |        |                           |         |         (D)           |
  (B)   |        |          (C)              |         +-----------------------+
--------+        +===========================+
communication                                                NETWORK STACK
DRIVER                   ESP-NETIF
```

其中......代表初始化；---->---或---<----代表数据包走向；\*\*\*\*\*\*代表操作系统的事件调用；|代表用户代码的设置和运行时的配置

## 配置方法

### 初始化

1. 初始化IO驱动
2. 创建一个ESP-NETIF的实例并进行如下配置：
   1. 特殊属性
   2. 网络协议栈相关设置
   3. IO设置
3. 将IO驱动句柄和NETIF实例关联
4. 配置事件处理函数，至少需要：
   1. 默认处理函数：用于普通的来自IO驱动器或其他特殊的接口的事件调用
   2. register处理函数：用故意相关联的应用程序事件调用

### 运行时配置

1. 获取当前TCP/IP设置
2. 收取IP事件
3. 控制应用程序的FSM

# 配置的实例

## WiFi默认初始化

使用

```c
esp_netif_t *esp_netif_create_default_wifi_ap(void);//初始化wifi为ap模式
esp_netif_t *esp_netif_create_default_wifi_sta(void);//初始化wifi为STA模式
```

两个API进行默认状态的wifi初始化，函数会返回对应的esp-netif实例

注意：创建的实例如果不再运行时需要停止并释放内存空间，且不能被多次创建

==如果需要使用AP+STA模式，两个接口都需要被创建==

## 相关库函数

1. 初始化

```c
esp_netif_init(void);//初始化组件
esp_netif_deinit(void);//销毁组件
esp_netif_new(const esp_netif_config_t *esp_netif_config);//根据配置结构体esp_netif_config创建一个新esp-netif实例
esp_netif_destroy(esp_netif_t *esp_netif);//删除一个esp-netif实例
```

2. 配置

```c
esp_netif_set_driver_config(esp_netif_t *esp_netif, const esp_netif_driver_ifconfig_t *driver_config);
//设置与esp-netif对象关联的IO驱动器
esp_netif_attach(esp_netif_t *esp_netif, esp_netif_iodriver_handle driver_handle);
//关联esp-netif对象与IO驱动器
//可以在完成关联后调用处理函数来进行回调或启动驱动器任务
```

3. 使用

```c
esp_netif_receive(esp_netif_t *esp_netif, void *buffer, size_t len, void *eb);
//从应用向TCP/IP协议栈发送包
esp_netif_action_start(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
//自动启用TCP/IP协议（使能如DHCP的功能）
esp_netif_action_stop(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
//停止向TCP/IP协议栈发送包

esp_netif_action_got_ip(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
//获取当前IP
esp_netif_set_mac(esp_netif_t *esp_netif, uint8_t mac[]);
//设置当前MAC地址
esp_netif_set_hostname(esp_netif_t *esp_netif, const char *hostname);
//设置当前主机名
esp_netif_get_hostname(esp_netif_t *esp_netif, const char **hostname);
//获取当前主机名
esp_netif_get_ip_info(esp_netif_t *esp_netif, esp_netif_ip_info_t *ip_info);
//获取当前IP地址相关信息
esp_netif_set_ip_info(esp_netif_t *esp_netif, const esp_netif_ip_info_t *ip_info);
//设置当前IP地址相关信息

esp_netif_get_netif_impl_index(esp_netif_t *esp_netif);
//获取当前网络接口的代号

esp_netif_dhcps_option(esp_netif_t *esp_netif,
                       esp_netif_dhcp_option_mode_t opt_op,
                       esp_netif_dhcp_option_id_t opt_id,
                       void *opt_val,
                       uint32_t opt_len);
//配置DHCP服务器
esp_netif_dhcpc_option(esp_netif_t *esp_netif,
                       esp_netif_dhcp_option_mode_t opt_op,
                       esp_netif_dhcp_option_id_t opt_id,
                       void *opt_val,
                       uint32_t opt_len)
//配置DHCP客户端
esp_netif_dhcpc_start(esp_netif_t *esp_netif);//开启DHCP客户端
esp_netif_dhcpc_stop(esp_netif_t *esp_netif);//停止DHCP客户端
esp_netif_dhcps_start(esp_netif_t *esp_netif);//开启DHCP服务器
esp_netif_dhcps_stop(esp_netif_t *esp_netif);//关闭DHCP服务器
esp_netif_dhcpc_get_status(esp_netif_t *esp_netif, esp_netif_dhcp_status_t *status);
//获取当前DHCP客户端状态
esp_netif_dhcps_get_status(esp_netif_t *esp_netif, esp_netif_dhcp_status_t *status);
//获取当前DHCP服务器状态

esp_netif_set_dns_info(esp_netif_t *esp_netif, esp_netif_dns_type_t type, esp_netif_dns_info_t *dns);
//设置DNS服务器信息
esp_netif_get_dns_info(esp_netif_t *esp_netif, esp_netif_dns_type_t type, esp_netif_dns_info_t *dns);
//获取DNS服务器信息

esp_netif_create_ip6_linklocal(esp_netif_t *esp_netif);//创建本地IPv6地址
esp_netif_set_ip4_addr(esp_ip4_addr_t *addr, uint8_t a, uint8_t b, uint8_t c, uint8_t d);//设置本地IPv4地址
esp_netif_get_ip6_global(esp_netif_t *esp_netif, esp_ip6_addr_t *if_ip6)//创建全局IPv6地址
esp_netif_get_ip6_linklocal(esp_netif_t *esp_netif, esp_ip6_addr_t *if_ip6);//获取本地IPv6地址
```

4. 事件处理函数

```c
esp_wifi_set_default_wifi_sta_handlers(void);
esp_wifi_set_default_wifi_ap_handlers(void);
```

5. 默认设置

```c
esp_netif_create_default_wifi_ap(void);
esp_netif_create_default_wifi_sta(void);
esp_netif_create_default_wifi_mesh_netifs(esp_netif_t **p_netif_sta, esp_netif_t **p_netif_ap);
```

# HTTP Server组件

原文地址：https://docs.espressif.com/projects/esp-idf/zh_CN/release-v4.1/api-reference/protocols/esp_http_server.html

HTTP Server 组件提供了在 ESP32 上运行轻量级 Web 服务器的功能

使用步骤：

1. 使用httpd_start()创建HTTP Server的实例

API会根据具体配置为其分配内存和资源，该函数返回指向服务器实例的指针（句柄）

服务器使用两个套接字，其中一个用于监听HTTP流量（TCP类型），一个用来处理控制信号（UDP类型），它们在服务器的任务循环中轮流使用。TCP 流量被解析为 HTTP 请求，根据请求的 URI （Uniform Resource Identifier统一资源标志符，表示web上每一种可用的资源）来调用用户注册的处理程序，在处理程序中需要发送回 HTTP 响应数据包。

**URI通常由三部分组成：资源的命名机制；存放资源的主机名；资源自身的名称**。另外，常说的URL是URI的一个子集（Uniform Resource Locator统一资源定位符），URL是一种具体的URI，它是URI的一个子集，它不仅唯一标识资源，而且还提供了定位该资源的信息。URL是Internet上描述信息资源的字符串，主要用在各种WWW客户程序和服务器程序上，**URL的格式由三部分组成：第一部分是协议(或称为服务方式)；第二部分是存有该资源的主机IP地址(有时也包括端口号)；第三部分是主机资源的具体地址，如目录和文件名等**。第一部分和第二部分用“://”符号隔开，第二部分和第三部分用“/”符号隔开。第一部分和第二部分是不可缺少的，第三部分有时可以省略。 

使用结构体httpd_config_t来配置服务器的各种设定（任务优先级、堆栈大小）

API和结构体如下所示

```c
httpd_start(httpd_handle_t *handle, const httpd_config_t *config);//开启HTTP服务器并分配内存资源

//示例应用
httpd_handle_t start_webserver(void)
{
     //可以使用以下宏函数来初始化httpd_config为默认值
     httpd_config_t config = HTTPD_DEFAULT_CONFIG();
     //设置服务器句柄为空
     httpd_handle_t server = NULL;

     //启动HTTP服务器
     if (httpd_start(&server, &config) == ESP_OK)
     {
         //注册uri句柄
         httpd_register_uri_handler(server, &uri_get);
         httpd_register_uri_handler(server, &uri_post);
     }
     //返回服务器句柄，如果启动失败则句柄为空
     return server;
}

typedef struct httpd_config
{
    unsigned task_priority;//RTOS服务器任务优先级
    size_t stack_size;//服务器任务的最大栈大小
    BaseType_t core_id;//服务器任务运行在哪个CPU core上
    uint16_t server_port;//服务器使用的端口号
    uint16_t ctrl_port;//在服务器组件间异步交换控制信号的UDP端口号
    uint16_t max_open_sockets;//最大连接的套接字/客户端数量
    uint16_t max_uri_handlers;//最大允许的uri句柄数量
    uint16_t max_resp_headers;//最大允许的HTTP响应头
    uint16_t backlog_conn;//积压链接的数量
    bool lru_purge_enable;//是否清除最近使用的连接
    uint16_t recv_wait_timeout;//接收函数的超时时间
    uint16_t send_wait_timeout;//发送函数的超时时间
    void *global_user_ctx;//全局用户上下文，专门用于存储服务器上下文中的用户数据
    httpd_free_ctx_fn_t global_user_ctx_free_fn;//释放空间函数
    void *global_transport_ctx;//全局传输上下文，用于存储部分解码或加密使用到的数据，和全局用户上下文意昂需要用free()函数释放内存空间，除非global_transport_ctx_free_fn被指定
    httpd_free_ctx_fn_t global_transport_ctx_free_fn;//释放空间函数
    httpd_open_func_t open_fn;//自定义session开启回调函数，在新的session开启时被调用
    httpd_close_func_t close_fn;//自定义session关闭回调函数
    httpd_uri_match_func_t uri_match_fn;//URI匹配函数，用于在搜索到匹配的URI时调用
}httpd_config_t;
```

2. 配置URI处理程序

使用httpd_register_uri_handler()完成

```c
//API原型
esp_err_t httpd_register_uri_handler(httpd_handle_t handle, const httpd_uri_t *uri_handler)

//示例
//URI处理函数
esp_err_t my_uri_handler(httpd_req_t* req)
{
    //收取请求、处理并发送响应
    ....
    ....
    ....
    //出错状态
    if (....)
    {
        //返回错误
        return ESP_FAIL;
    }
    //成功状态
    return ESP_OK;
}

//URI句柄结构体
httpd_uri_t my_uri {
    .uri      = "/my_uri/path/xyz",//相关的URI
    .method   = HTTPD_GET,//方法
    .handler  = my_uri_handler,//URI处理函数
    .user_ctx = NULL//指向用户上下文数据的指针
};

//注册句柄
if (httpd_register_uri_handler(server_handle, &my_uri) != ESP_OK)
{
   //如果注册失败就....
   ....
}
```

通过传入httpd_uri_t结构体类型的对象来注册 URI 处理程序

3. 使用httpd_stop()函数停止HTTP服务器

该API会根据传入的句柄停止服务器并释放相关联的内存和资源。这是一个阻塞函数——首先给服务器任务发送停止信号，然后等待其终止。期间服务器任务会关闭所有已打开的连接，删除已注册的 URI 处理程序，并将所有会话的上下文数据重置为空。

```c
esp_err_t httpd_stop(httpd_handle_t handle);//根据传入的服务器句柄停止指向的服务器
```

可以使用以下的代码来安全地停止服务器

```c
//示例应用
void stop_webserver(httpd_handle_t server)
{
     //确保指针非空
     if (server != NULL)
     {
         httpd_stop(server);//停止服务器
     }
}
```

## 应用实例

```c
/* URI 处理函数，在客户端发起 GET /uri 请求时被调用 */
esp_err_t get_handler(httpd_req_t *req)
{
    /* 发送回简单的响应数据包 */
    const char[] resp = "URI GET Response";
    httpd_resp_send(req, resp, strlen(resp));
    return ESP_OK;
}

/* URI 处理函数，在客户端发起 POST /uri 请求时被调用 */
esp_err_t post_handler(httpd_req_t *req)
{
    /* 定义 HTTP POST 请求数据的目标缓存区
     * httpd_req_recv() 只接收 char* 数据，但也可以是任意二进制数据（需要类型转换）
     * 对于字符串数据，null 终止符会被省略，content_len 会给出字符串的长度 */
    char[100] content;

    /* 如果内容长度大于缓冲区则截断 */
    size_t recv_size = MIN(req->content_len, sizeof(content));

    int ret = httpd_req_recv(req, content, recv_size);
    if (ret <= 0)/* 返回 0 表示连接已关闭 */
    {
        /* 检查是否超时 */
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) 
        {
            /* 如果是超时，可以调用 httpd_req_recv() 重试
             * 简单起见，这里我们直接响应 HTTP 408（请求超时）错误给客户端 */
            httpd_resp_send_408(req);
        }
        /* 如果发生了错误，返回 ESP_FAIL 可以确保底层套接字被关闭 */
        return ESP_FAIL;
    }

    /* 发送简单的响应数据包 */
    const char[] resp = "URI POST Response";
    httpd_resp_send(req, resp, strlen(resp));
    return ESP_OK;
}

/* GET /uri 的 URI 处理结构 */
httpd_uri_t uri_get = {
    .uri      = "/uri",
    .method   = HTTP_GET,
    .handler  = get_handler,
    .user_ctx = NULL
};

/* POST /uri 的 URI 处理结构 */
httpd_uri_t uri_post = {
    .uri      = "/uri",
    .method   = HTTP_POST,
    .handler  = post_handler,
    .user_ctx = NULL
};

/* 启动 Web 服务器的函数 */
httpd_handle_t start_webserver(void)
{
    /* 生成默认的配置参数 */
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();

    /* 置空 esp_http_server 的实例句柄 */
    httpd_handle_t server = NULL;

    /* 启动 httpd server */
    if (httpd_start(&server, &config) == ESP_OK)
    {
        /* 注册 URI 处理程序 */
        httpd_register_uri_handler(server, &uri_get);
        httpd_register_uri_handler(server, &uri_post);
    }
    /* 如果服务器启动失败，返回的句柄是 NULL */
    return server;
}

/* 停止 Web 服务器的函数 */
void stop_webserver(httpd_handle_t server)
{
    if (server)
    {
        /* 停止 httpd server */
        httpd_stop(server);
    }
}
```



