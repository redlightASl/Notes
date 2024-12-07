# TCP协议栈

ESP使用lwIP作为嵌入式的TCP/IP协议栈支持

lwIP是一套在MCU层级上用C实现的IP协议栈，可以运行在裸机/RTOS/嵌入式Linux，乐鑫为ESP32提供了相关移植包

相关内容可以参考lwIP库函数，在LWIP和ESP-NETIF组件中得到支持

```c
esp_err_t esp_netif_init(void);
esp_err_t esp_netif_deinit(void);
esp_netif_t *esp_netif_new(const esp_netif_config_t *esp_netif_config);
void esp_netif_destroy(esp_netif_t *esp_netif);
esp_err_t esp_netif_set_driver_config(esp_netif_t *esp_netif, const esp_netif_driver_ifconfig_t *driver_config);
esp_err_t esp_netif_attach(esp_netif_t *esp_netif, esp_netif_iodriver_handle driver_handle);
esp_err_t esp_netif_receive(esp_netif_t *esp_netif, void *buffer, size_t len, void *eb);
void esp_netif_action_start(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
void esp_netif_action_stop(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
void esp_netif_action_connected(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
void esp_netif_action_disconnected(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
void esp_netif_action_got_ip(void *esp_netif, esp_event_base_t base, int32_t event_id, void *data);
esp_err_t esp_netif_set_mac(esp_netif_t *esp_netif, uint8_t mac[]);
esp_err_t esp_netif_set_hostname(esp_netif_t *esp_netif, const char *hostname);
esp_err_t esp_netif_get_hostname(esp_netif_t *esp_netif, const char **hostname);
bool esp_netif_is_netif_up(esp_netif_t *esp_netif);
esp_err_t esp_netif_get_ip_info(esp_netif_t *esp_netif, esp_netif_ip_info_t *ip_info);
esp_err_t esp_netif_get_old_ip_info(esp_netif_t *esp_netif, esp_netif_ip_info_t *ip_info);
esp_err_t esp_netif_set_ip_info(esp_netif_t *esp_netif, const esp_netif_ip_info_t *ip_info);
esp_err_t esp_netif_set_old_ip_info(esp_netif_t *esp_netif, const esp_netif_ip_info_t *ip_info);
int esp_netif_get_netif_impl_index(esp_netif_t *esp_netif);
esp_err_t esp_netif_dhcps_option(esp_netif_t *esp_netif, esp_netif_dhcp_option_mode_t opt_op, esp_netif_dhcp_option_id_t opt_id, void *opt_val, uint32_t opt_len);
esp_err_t esp_netif_dhcpc_option(esp_netif_t *esp_netif, esp_netif_dhcp_option_mode_t opt_op, esp_netif_dhcp_option_id_t opt_id, void *opt_val, uint32_t opt_len);
esp_err_t esp_netif_dhcpc_start(esp_netif_t *esp_netif);
esp_err_t esp_netif_dhcpc_stop(esp_netif_t *esp_netif);
esp_err_t esp_netif_dhcpc_get_status(esp_netif_t *esp_netif, esp_netif_dhcp_status_t *status);
esp_err_t esp_netif_dhcps_get_status(esp_netif_t *esp_netif, esp_netif_dhcp_status_t *status);
esp_err_t esp_netif_dhcps_start(esp_netif_t *esp_netif);
esp_err_t esp_netif_dhcps_stop(esp_netif_t *esp_netif);
```

esp_netif组件建立在lwip基础上，如上面的API所示，实现了

* TCP/IP协议初始化与内存分配
* 建立基于IP协议的通信
* 控制本机IP地址与查找目标IP
* DHCP功能
* 收发TCP报文的底层实现

注意：**这个组件并没有实现DNS功能**，需要使用单独的DNS组件才能实现DNS服务器/DNS解析功能

# HTTP客户端

ESP-IDF提供了可以实现稳定链接的HTTP-Client组件`<esp_http_client>`，实现从ESP-IDF应用程序发出HTTP/S请求的API

HTTP-Client可以理解成为一个没有画面的“浏览器”——它与服务器建立TCP/IP连接，并收发符合HTTP协议标准的TCP报文，其中包含消息头和数据包，数据包会以json格式传输

综上我们可以知道，如果要在ESP-IDF设备和HTTP网站（服务器）之间建立稳定的连接，需要五个组件：

* **wifi或ethernet组件**，提供底层联网功能
* **lwip组件**，提供IP协议的MCU实现
* **netif组件**，提供TCP协议的MCU实现
* **esp_http_client组件**，提供HTTP-Client/Server数据解析和连接处理的实现，其中HTTP-Server组件在之前的博文中已经介绍过
* **cJSON组件**，用于解析服务器回传的json数据/处理本地数据为json格式并POST到服务器

如果有必要，还需要使用freertos组件以方便多任务处理

使用HTTP-Client相关API的步骤如下：

> 在开始之前，需要先建立NVS存储、连接WiFi、初始化netif网络接口
>
> ```c
> esp_err_t ret = nvs_flash_init();
> if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
> {
> 	ESP_ERROR_CHECK(nvs_flash_erase());
> 	ret = nvs_flash_init();
> }
> ESP_ERROR_CHECK(ret);
> ESP_ERROR_CHECK(esp_netif_init());
> ESP_ERROR_CHECK(esp_event_loop_create_default());
> ESP_ERROR_CHECK(internet_connect()); //连接wifi或ethernet
> ```

1. `esp_http_client_init()`

    创建一个esp_http_client_config_t的实例（实例化对象），并配置HTTP-Client句柄

    ```c
    esp_http_client_config_t config = {
    	.host = WEB_SERVER,
    	.path = WEB_PATH_GET_TIME,
        .query = WEB_QUERY,
        .transport_type = HTTP_TRANSPORT_OVER_TCP,
        .event_handler = _http_event_handler,
        .user_data = local_response_buffer
    };
    ```

2. 执行HTTP客户端的各种操作

    包括打开链接、进行数据交换、抑或是关闭链接

    所有这些操作都可以通过封装好的函数配合上面步骤中指定的**event_handler**回调函数进行实现

    ```c
    esp_http_client_handle_t client = esp_http_client_init(&config);
    ```

    其中event_handler是基于状态机的，如下所示

    ```c
    esp_err_t _http_event_handler(esp_http_client_event_t* evt)
    {
        static char* output_buffer; // Buffer to store response of http request from event handler
        static int output_len; // Stores number of bytes read
    
        switch (evt->event_id)
        {
        case HTTP_EVENT_ERROR:
            ESP_LOGD(TAG, "HTTP_EVENT_ERROR");
            break;
        case HTTP_EVENT_ON_CONNECTED:
            ESP_LOGD(TAG, "HTTP_EVENT_ON_CONNECTED");
            break;
        case HTTP_EVENT_HEADER_SENT:
            ESP_LOGD(TAG, "HTTP_EVENT_HEADER_SENT");
            break;
        case HTTP_EVENT_ON_HEADER:
            ESP_LOGD(TAG, "HTTP_EVENT_ON_HEADER, key=%s, value=%s", evt->header_key, evt->header_value);
            break;
        case HTTP_EVENT_ON_DATA:
            ESP_LOGD(TAG, "HTTP_EVENT_ON_DATA, len=%d", evt->data_len);
            /*
             *  Check for chunked encoding is added as the URL for chunked encoding used in this example returns binary data.
             *  However, event handler can also be used in case chunked encoding is used.
             */
            if (!esp_http_client_is_chunked_response(evt->client))
            {
                // If user_data buffer is configured, copy the response into the buffer
                if (evt->user_data)
                {
                    memcpy(evt->user_data + output_len, evt->data, evt->data_len);
                }
                else
                {
                    if (output_buffer == NULL)
                    {
                        output_buffer = (char*)malloc(esp_http_client_get_content_length(evt->client));
                        output_len = 0;
                        if (output_buffer == NULL)
                        {
                            ESP_LOGE(TAG, "Failed to allocate memory for output buffer");
                            return ESP_FAIL;
                        }
                    }
                    memcpy(output_buffer + output_len, evt->data, evt->data_len);
                }
                output_len += evt->data_len;
            }
            break;
        case HTTP_EVENT_ON_FINISH:
            ESP_LOGD(TAG, "HTTP_EVENT_ON_FINISH");
            if (output_buffer != NULL)
            {
                // Response is accumulated in output_buffer. Uncomment the below line to print the accumulated response
                // ESP_LOG_BUFFER_HEX(TAG, output_buffer, output_len);
                free(output_buffer);
                output_buffer = NULL;
                output_len = 0;
            }
            break;
        case HTTP_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "HTTP_EVENT_DISCONNECTED");
            int mbedtls_err = 0;
            esp_err_t err = esp_tls_get_and_clear_last_error(evt->data, &mbedtls_err, NULL);
            if (err != 0)
            {
                if (output_buffer != NULL)
                {
                    free(output_buffer);
                    output_buffer = NULL;
                    output_len = 0;
                }
                ESP_LOGI(TAG, "Last esp error code: 0x%x", err);
                ESP_LOGI(TAG, "Last mbedtls failure: 0x%x", mbedtls_err);
            }
            break;
        }
        return ESP_OK;
    }
    ```

3. 通过`esp_http_client_cleanup()`关闭链接，并释放系统资源

    需要注意：**这个函数必须是操作完成后调用的最后一个函数**

需要注意一点：esp_http_client_init()建立的连接是**持久性**的，因此HTTP客户端可以在多个交换中重用相同的连接，只要服务器没有使用报头*connection: close*强行关闭，或者没有使*用esp_http_client_cleanup()*关闭链接，设备的HTTP链接就会保持打开状态

## 常用的HTTP-Client操作

### HTTP：GET

```c
// GET
esp_err_t err = esp_http_client_perform(client);
if (err == ESP_OK) 
{
	ESP_LOGI(TAG, "HTTP GET Status = %d, content_length = %d",
    esp_http_client_get_status_code(client),
    esp_http_client_get_content_length(client));
} 
else 
{
	ESP_LOGE(TAG, "HTTP GET request failed: %s", esp_err_to_name(err));
}
ESP_LOG_BUFFER_HEX(TAG, local_response_buffer, strlen(local_response_buffer)); 
//数据会保存到之前注册在http-client对象中的数据缓存区中
```

这里展示了两个常用的API

```c
esp_http_client_get_status_code(client) //获取HTTP返回状态码
esp_http_client_get_content_length(client) //获取HTTP返回数据的长度
```

其中esp_http_client_get_content_length()比较特殊，仅能应用于返回数据长度定长的状态下，也就是HTTP报头中不能有`chunked`情况，如果想要接收非定长数据，需要使用专用的API：`esp_http_client_is_chunked_response(esp_http_client_handle_t client)`先获取报文长度，再针对这个长度在回调函数中接收数据到HTTP报文缓存区

GitHub上的ESP-IDF repo中热心网友给出了下面的代码来实现简单快捷的request

```c
int http_request(char *http_response, int *http_response_length, int range_start, int range_end, int client_id)
{
	int err = -1;
	char range[64];
	int len_received = 0;

    if (range_end > range_start) 
    {
            sprintf(range, "bytes=%d-%d", range_start, range_end);
            esp_http_client_set_header(ota_client[client_id], "Range", range);
    }

    err = esp_http_client_open(ota_client[client_id], 0);
    if (err != ESP_OK) 
    {
            ESP_LOGE(LOG_TAG, "Failed to open HTTP connection: %s", esp_err_to_name(err));
    } 
    else 
    {
		int content_length = esp_http_client_fetch_headers(ota_client[client_id]);
		if (content_length < 0) 
        {
        	ESP_LOGE(LOG_TAG, "HTTP client fetch headers failed");
		} 
        else 
        {
        	len_received = esp_http_client_read_response(ota_client[client_id], http_response, *http_response_length);
			if (len_received >= 0) 
            {
                ESP_LOGI(LOG_TAG, "HTTP Status = %d, content_length = %lld",
                                esp_http_client_get_status_code(ota_client[client_id]),
                                esp_http_client_get_content_length(ota_client[client_id]));
			} 
            else 
            {
            	ESP_LOGE(LOG_TAG, "Failed to read response");    
            }
		}
    }

    esp_http_client_close(ota_client[client_id]);
    *http_response_length = len_received;
    return (err);
}
```

这段代码是基于esp_http_client_open的，速度也相对较快，推荐使用

### HTTP：POST

如下面示例：

```c
// POST
const char *post_data = "{\"field1\":\"value1\"}";
esp_http_client_set_url(client, "http://httpbin.org/post");
esp_http_client_set_method(client, HTTP_METHOD_POST); //设置当前method为POST
esp_http_client_set_header(client, "Content-Type", "application/json"); //设置请求报头
esp_http_client_set_post_field(client, post_data, strlen(post_data)); //设置POST时使用的数据包
//这个数据包一般是用cJSON格式化后输出的字符串
err = esp_http_client_perform(client);
if (err == ESP_OK) 
{
	ESP_LOGI(TAG, "HTTP POST Status = %d, content_length = %d",
                esp_http_client_get_status_code(client),
                esp_http_client_get_content_length(client));
} 
else 
{
	ESP_LOGE(TAG, "HTTP POST request failed: %s", esp_err_to_name(err));
}
```

注意：这里面的数据包一定要设置为格式正确的字符串，推荐使用cJSON组件而不是手动格式化

### 其他操作

可以查看官方示例代码<esp-idf目录>/example/protocols/esp_http_client来获得指令格式

篇幅所限不再过多介绍

## cJSON组件

ESP32提供了cJSON的移植（如果不提供其实自己移植也很简单）

cJSON是一套用于格式化处理JSON数据的C库，可以针对使用使用情景分为两类API：

* 将字符串处理为JSON对象
* 将JSON对象处理为字符串

C中的字符串用char类型数组描述，而JSON对象则被cJSON定义为一个结构体，如下所示

```c
typedef struct cJSON
{
    /* next/prev allow you to walk array/object chains. Alternatively, use GetArraySize/GetArrayItem/GetObjectItem */
    struct cJSON *next;
    struct cJSON *prev;
    /* An array or object item will have a child pointer pointing to a chain of the items in the array/object. */
    struct cJSON *child;

    /* The type of the item, as above. */
    int type;

    /* The item's string, if type==cJSON_String  and type == cJSON_Raw */
    char *valuestring;
    /* writing to valueint is DEPRECATED, use cJSON_SetNumberValue instead */
    int valueint;
    /* The item's number, if type==cJSON_Number */
    double valuedouble;

    /* The item's name string, if this item is the child of, or is in the list of subitems of an object. */
    char *string;
} cJSON;
```

它的“基类”是一个双向链表，同时支持扩展更多子类

type属性代表JSON的类型

valuestring、valueint、valuedouble分别表示JSON中可能包含的三个数据类型：字符串、整型、浮点型

string属性代表子类的名字或JSON实例化对象的名字

在代码中使用

```c
#include "cJSON.h"
```

即可调用cJSON组件

使用

```c
CJSON_PUBLIC(const char*) cJSON_Version(void)
    
#if (defined(__GNUC__) || defined(__SUNPRO_CC) || defined (__SUNPRO_C)) && defined(CJSON_API_VISIBILITY)
#define CJSON_PUBLIC(type)   __attribute__((visibility("default"))) type
#else
#define CJSON_PUBLIC(type) type
#endif
#endif
```

可以输出cJSON的版本号到一个指定字符串中，只要再将字符串输出就可以检查当前的cJSON版本是否符合要求

### 将字符串处理为JSON对象

常用于从服务器获取数据后将数据保存在本地时候的解析工作

json以**嵌套的键值对**或**值的有序列表**形式存在，通常如下

```json
{
    "code":0,
    "message":null,
    "data":1642959073193
}
//或
{
    "employees":
    {
		{ 
        	"firstName":"Bill",
        	"lastName":"Gates"
    	},
		{
    		"firstName":"George",
    		"lastName":"Bush"
		},
		{
            "firstName":"Thomas",
    		"lastName":"Carter"
        },
	},
	"message": 12345678
}
```

它采用完全独立于语言的文本格式，但是也使用了类似于C语言家族的习惯（包括C/C++/C#、Java、JavaScript、Perl、Python等），很多语言都有自己的JSON库实现

**嵌套的键值对**在不同语言中都有自己的理解：对象（Object）、记录（Record）、结构体（struct）、字典（dictionary）、哈希表（hash table）、键值对（Key-Value）、关联数组（associative array）等等，但都具有**一对一**或**一对多**的形式

**值的有序列表**，大部分语言都将其理解为数组（array）

这些常见的数据结构在同样基于这些结构的编程语言之间交换成为可能，这也是为什么JSON格式会在互联网中流行（甚至当今很多嵌入式设备也在考虑于实时性较低的应用中使用json）

json自己的实现中，将每个json串视为**json对象**，它是一个**无序**的**名称-值**成对组合的集合（可嵌套的无序的键值对）。**一个对象以左括号{开始，以右括号}结束，要求每个名称后都接一个冒号:，同时成对组合之间用逗号,分隔**

cJSON解析API的基本使用可以参考以下示例代码（收取的json数据如上面给出的第一个json格式示例）：

```c
/* 确认从local_response_buffer（HTTP报文缓存区）获得的数据是否为JSON格式 */
cJSON* response_json = cJSON_Parse(local_response_buffer);
if (response_json != NULL)
{
    /* 获取data这个键对应的值，这里data传输的实际上是时间戳 */
	cJSON* timestamp_json = cJSON_GetObjectItem(response_json, "data");
    /* 输出对应值到字符串 */
	char* timestamp_temp = cJSON_Print(timestamp_json);
    /* 打印输出字符串 */
	ESP_LOGI(TAG, "recv number:%s", timestamp_temp);

    /* 获取message这个键对应的值，这里的值固定为null */
	cJSON* message_json = cJSON_GetObjectItem(response_json, "message");
    /* 输出对应值到字符串 */
	char* message = cJSON_Print(message_json);
    /* 打印输出字符串 */
	ESP_LOGI(TAG, "recv msg:%s", message);
    if (!strcmp(message, "null")) //检验数据是否正确
    {
    	ESP_LOGI(TAG, "senting Queue msg:%s", timestamp); //用消息队列发送时间戳数据
        xQueueSend(trans_timestamp_Queue, timestamp, 0);
	}
}
```

### 将JSON对象处理为字符串

上面说过，**JSON对象是以链表为基础的**

在创建JSON对象时要先创建一个”根节点“，再从这个根节点上”生长“出更多数据。每多一个节点，就意味着大括号多了一层，比如上面给出的两个JSON示例，第一个就有一个根节点；第二个则有一个根节点、三个message子节点

可以参考以下示例代码：

```c
cJSON* cjson_root = cJSON_CreateObject(); //创建JSON根节点

/* 分别添加键和值对应的数据 */
/* 函数第一个参数是对应的根节点 */
/* 函数第二个参数是键 */
/* 函数第三个参数是值 */
cJSON_AddStringToObject(cjson_root, "value", "8399d88e3293cc89cacc1d735af12810");
cJSON_AddStringToObject(cjson_root, "location", "classroom");
cJSON_AddNumberToObject(cjson_root, "timestamp", timestamp);

/* 输出JSON数据为字符串格式 */
char* post_data = cJSON_Print(cjson_root);
/* 删除之前为JSON对象创建的根节点 */
cJSON_Delete(cjson_root);
/* 打印字符串格式的JSON数据 */
ESP_LOGI(TAG, "generate:%s", post_data);
```

这里需要注意：**建立了JSON对象就一定要记得删除，每建立一个就要记得删除对应的数据**，C可没有内存管理机制，都是要手动分配回收的！

*如果存在多个子节点和一个根节点，要先从顶层的子节点删除，最后删除根节点*
