# WiFi外设配置

ESP32/8266的Wi-Fi库支持配置及监控Wi-Fi连网功能

相关内容参考乐鑫的ESP32/8266文档https://docs.espressif.com/projects/esp-idf/zh_CN/release-v4.1/api-reference/network/esp_wifi.html

## 基本模式

1. 基站模式（又称**STA模式**或Client模式）：将ESP连接到附近的AP，此时**相当于ESP在蹭网**

2. **AP模式**（又称Soft-AP模式或Server模式）：将ESP设置为AP，可供周围设备连接，此时**相当于ESP开热点**
3. AP-STA**共存模式**：ESP32既是接入点，同时又作为基站连接到另外一个接入点，此时**相当于ESP连着隔壁wifi开热点给自家用**

同时支持以上模式的安全模式（WPA、WPA2、WEP等），可以理解成**安全蹭网**

## 基本功能

1. 主动/被动扫描附近AP，**主动找别人家网蹭**
2. 使用混杂模式监控IEEE802.11 Wi-Fi数据包，**可以理解成ESP能看到你上了什么不可描述的网站**

## 库函数

1. 初始化与设置

```c
esp_wifi_init(const wifi_init_config_t *config)//WiFi功能初始化，config为初始化结构体句柄
esp_wifi_set_config(wifi_interface_t interface, wifi_config_t *conf)//使能设置
esp_wifi_set_mode(wifi_mode_t mode)//模式设置
    
//可如下配置
WIFI_MODE_NULL=0
WIFI_MODE_STA//STA模式
WIFI_MODE_AP//软AP模式
WIFI_MODE_APSTA//混合模式
WIFI_MODE_MAX
    
esp_wifi_get_mode(wifi_mode_t *mode)//获取当前模式
esp_wifi_get_config(wifi_interface_t interface, wifi_config_t *conf)//获取当前设置
```

2. 关闭WiFi

```c
esp_wifi_stop()//STA模式下断开wifi连接，AP模式下关闭热点并释放内存，共用模式下断开连接并关闭热点
esp_wifi_deinit()//释放曾在esp_wifi_init中申请的资源并停止WiFi工作，不需要wifi功能时可以使用
```

3. 连接/断开WiFi

```c
/* 用于STA模式 */
esp_wifi_connect()//连接WiFi
esp_wifi_disconnect()//断开WiFi

/* 用于AP模式 */
esp_wifi_deauth_sta(uint16_t aid)//停止对接入设备的授权——不让别人蹭网
esp_wifi_ap_get_sta_aid(const uint8_t mac[6], uint16_t *aid)//获取当前接入的设备信息
esp_wifi_ap_get_sta_list(wifi_sta_list_t *sta)//获取当前接入的设备列表
```

4. 扫描附近

```c
esp_wifi_scan_start(const wifi_scan_config_t *config, bool block)//扫描AP以蹭网
/* 推荐最大扫描时间为1500ms */
esp_wifi_scan_stop()//在途中停止扫描
esp_wifi_scan_get_ap_num(uint16_t *number)//获得最后一次扫描得到的AP号码
esp_wifi_scan_get_ap_records(uint16_t *number, wifi_ap_record_t *ap_records)//获取扫描记录
esp_wifi_sta_get_ap_info(wifi_ap_record_t *ap_info)//获取当前连接wifi的相关信息
    
//返回如下结构体的指针
uint8_t bssid[6]//MAC地址
uint8_t ssid[33]//SSID
uint8_t primary//AP通道
wifi_second_chan_t second//AP第二通道
int8_t rssi//信号强度
wifi_auth_mode_t authmode//认证模式
wifi_cipher_type_t pairwise_cipher//PTK成对传输密钥，用于单播数据帧的加密解密
wifi_cipher_type_t group_cipher//GTK组临时密钥，用于组播数据帧和广播数据帧的加密和解密
wifi_ant_t ant//用于接收信号的天线引脚
/* 相关控制寄存器位 */
uint32_t phy_11b : 1//11b模式开启标志
uint32_t phy_11g : 1//11g模式开启标志
uint32_t phy_11n : 1//11n模式开启标志
uint32_t phy_lr : 1//低频模式开启标志
uint32_t wps : 1//WPS支持情况标志
uint32_t reserved : 27//寄存器保留位
/* 相关控制寄存器位 */
wifi_country_t country//AP的国家信息
```

6. 操作系统相关

```c
esp_wifi_set_event_mask(uint32_t mask)//设置事件掩码
```

7. 其他

```c
esp_wifi_set_protocol(wifi_interface_t ifx, uint8_t protocol_bitmap)//设置特殊接口的协议类型
//可选WIFI_PROTOCOL_11B、WIFI_PROTOCOL_11G、WIFI_PROTOCOL_11N)
esp_wifi_get_protocol(wifi_interface_t ifx, uint8_t *protocol_bitmap)//获取当前协议类型
    
sp_wifi_set_bandwidth(wifi_interface_t ifx, wifi_bandwidth_t bw)//设置带宽
esp_wifi_get_bandwidth(wifi_interface_t ifx, wifi_bandwidth_t *bw)//获取当前带宽
    
sp_wifi_set_channel(uint8_t primary, wifi_second_chan_t second)//设置primary/secondary通道
esp_wifi_get_channel(uint8_t *primary, wifi_second_chan_t *second)//获取当前使用的通道
    
esp_wifi_set_country(const wifi_country_t *country)//设置当前的国家信息
esp_wifi_get_country(wifi_country_t *country)//获取当前的国家信息
    
esp_wifi_set_mac(wifi_interface_t ifx, const uint8_t mac[6])//设置当前mac地址
esp_wifi_get_mac(wifi_interface_t ifx, uint8_t mac[6])//获取当前mac地址
    
esp_wifi_set_ant_gpio(const wifi_ant_gpio_config_t *config)//设置天线引脚
esp_wifi_get_ant_gpio(wifi_ant_gpio_config_t *config)//获取当前天线引脚
esp_wifi_set_ant(const wifi_ant_config_t *config)//设置天线设定
esp_wifi_get_ant(wifi_ant_config_t *config)//获取当前天线设定
    
esp_wifi_set_promiscuous(bool en)//使能混杂模式
esp_wifi_get_promiscuous(bool *en)//获取混杂模式
esp_wifi_set_promiscuous_filter(const wifi_promiscuous_filter_t *filter)//设置混杂模式过滤器，默认过滤除WIFI_PKT_MISC外的包
esp_wifi_get_promiscuous_filter(wifi_promiscuous_filter_t *filter)//获取混杂模式过滤器
esp_wifi_set_promiscuous_ctrl_filter(const wifi_promiscuous_filter_t *filter)//使能混杂类型过滤器的子类型过滤
esp_wifi_get_promiscuous_ctrl_filter(wifi_promiscuous_filter_t *filter)//获取混杂类型过滤器的子类型过滤
esp_wifi_set_promiscuous_rx_cb(wifi_promiscuous_cb_t cb)//设置混杂模式监控回调函数  
```

8. 低功耗相关

```c
esp_wifi_set_inactive_time(wifi_interface_t ifx, uint16_t sec)//设置暂时休眠时间
esp_wifi_get_ant(wifi_ant_config_t *config)//获取暂时休眠时间
```

特征：大部分API都有对应的set和get两个方向，需要回传数据时使用get\*，初始设置时使用set\*

### AP模式初始化

```c
void wifi_init_softap(void)
{
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        NULL));

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = EXAMPLE_ESP_WIFI_SSID,
            .ssid_len = strlen(EXAMPLE_ESP_WIFI_SSID),
            .channel = EXAMPLE_ESP_WIFI_CHANNEL,
            .password = EXAMPLE_ESP_WIFI_PASS,
            .max_connection = EXAMPLE_MAX_STA_CONN,
            .authmode = WIFI_AUTH_WPA_WPA2_PSK
        },
    };
    if (strlen(EXAMPLE_ESP_WIFI_PASS) == 0)
    {
        wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    }

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI(TAG, "wifi_init_softap finished. SSID:%s password:%s channel:%d",
             EXAMPLE_ESP_WIFI_SSID, EXAMPLE_ESP_WIFI_PASS, EXAMPLE_ESP_WIFI_CHANNEL);
}
```

其中主要用到了wifi_config_t这个结构体，它的内容如下所示

```c
typedef struct {
    uint8_t ssid[32];//SSID
    uint8_t password[64];//密码
    uint8_t ssid_len;//SSID长度，若设为0则会自动查找到终止字符；否则会在规定长度处截断
    uint8_t channel;//AP的通道
    wifi_auth_mode_t authmode;//授权模式
    uint8_t ssid_hidden;//是否广播SSID，默认为0-广播；设为1则不广播
    uint8_t max_connection;//能连接的最大节点数量，默认为4，最大为4
    uint16_t beacon_interval;//信标间隔，默认100ms，应设置在100-60000ms内
} wifi_ap_config_t;
```

### STA模式初始化

```c
void wifi_init_sta(void)
{
    s_wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = EXAMPLE_ESP_WIFI_SSID,
            .password = EXAMPLE_ESP_WIFI_PASS,
            /* Setting a password implies station will connect to all security modes including WEP/WPA.
             * However these modes are deprecated and not advisable to be used. Incase your Access point
             * doesn't support WPA2, these mode can be enabled by commenting below line */
	     	.threshold.authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {
                .capable = true,
                .required = false
            },
        },
    };
    
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA) );
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config) );
    ESP_ERROR_CHECK(esp_wifi_start() );

    ESP_LOGI(TAG, "wifi_init_sta finished.");

    /* Waiting until either the connection is established (WIFI_CONNECTED_BIT) or connection failed for the maximum
     * number of re-tries (WIFI_FAIL_BIT). The bits are set by event_handler() (see above) */
    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
            WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
            pdFALSE,
            pdFALSE,
            portMAX_DELAY);

    /* xEventGroupWaitBits() returns the bits before the call returned, hence we can test which event actually
     * happened. */
    if (bits & WIFI_CONNECTED_BIT) {
        ESP_LOGI(TAG, "connected to ap SSID:%s password:%s",
                 EXAMPLE_ESP_WIFI_SSID, EXAMPLE_ESP_WIFI_PASS);
    } else if (bits & WIFI_FAIL_BIT) {
        ESP_LOGI(TAG, "Failed to connect to SSID:%s, password:%s",
                 EXAMPLE_ESP_WIFI_SSID, EXAMPLE_ESP_WIFI_PASS);
    } else {
        ESP_LOGE(TAG, "UNEXPECTED EVENT");
    }

    /* The event will not be processed after unregister */
    ESP_ERROR_CHECK(esp_event_handler_instance_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, instance_got_ip));
    ESP_ERROR_CHECK(esp_event_handler_instance_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, instance_any_id));
    vEventGroupDelete(s_wifi_event_group);
}
```

其中主要用到了wifi_sta_config_t这个结构体，它的内容如下所示

```c
typedef struct {
    uint8_t ssid[32];//SSID
    uint8_t password[64];//密码
    bool bssid_set;//是否设置目标AP的MAC地址，一般设为0；只有用户需要查看AP的MAC地址时才设为1
    uint8_t bssid[6];//目标AP的MAC地址
    uint8_t channel;//目标AP的通道，如果未知设为0；范围是1-13
} wifi_sta_config_t;
```

### AP-STA共存模式

```c
esp_err_t event_handler(void *ctx, system_event_t *event)
{
    switch (event->event_id)
    {
    case SYSTEM_EVENT_STA_START:
        ESP_LOGI(TAG, "Connecting to AP");
        esp_wifi_connect();
    break;

    case SYSTEM_EVENT_STA_GOT_IP:
        ESP_LOGI(TAG, "Connected");
    break;

    case SYSTEM_EVENT_STA_DISCONNECTED:
        //ESP_LOGI(TAG, "Wifi disconnected, try to connect again...");
        esp_wifi_connect();
    break;

    default:
    break;
    }
    
    return ESP_OK;
}

void ESP_net_init(void)
{
    ESP_ERROR_CHECK(esp_event_loop_init(event_handler, NULL));
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK( esp_wifi_init(&cfg) );
    ESP_ERROR_CHECK( esp_wifi_set_storage(WIFI_STORAGE_RAM) );
    ESP_ERROR_CHECK( esp_wifi_set_mode(WIFI_MODE_APSTA) );

    wifi_config_t sta_config = {
        .sta = {
            .ssid = TARGET_ESP_WIFI_SSID,
            .password = TARGET_ESP_WIFI_PASS,
            .bssid_set = false
        }
    };
    wifi_config_t ap_config = {
        .ap = {
            .ssid = AP_ESP_WIFI_SSID,
            .password = AP_ESP_WIFI_PASS,
            .ssid_len = 0,
            .max_connection = AP_MAX_STA_CONN,
            .authmode = WIFI_AUTH_WPA_PSK
        }
    };
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_config));
    esp_err_t tmp=esp_wifi_set_config(WIFI_IF_AP, &ap_config);

    ESP_ERROR_CHECK(esp_wifi_start());
    esp_wifi_connect();
}

void app_main(void)
{
    //init NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    //init wifi ap and station
    ESP_net_init();
}
```

在这里使用了状态机（SM）的编程思路，【开始连接】-【连接完毕】-【丢失连接】几个状态切换中都会调用event_handler()进行处理并打印相关信息

## 基本初始化方法

```c
//设置线程
wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();//进行默认初始化

//设置wifi_config结构体来配置具体的wifi模式
wifi_config_t sta_wifi_config = {
        .sta = {
            .ssid = SSID,
            .password = PASSWORD,
	     	.threshold.authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {//这里可省略
                .capable = true,
                .required = false
            },
        },
    };
wifi_config_t ap_wifi_config = {
        .ap = {
            .ssid = SSID,
            .ssid_len = strlen(EXAMPLE_ESP_WIFI_SSID),
            .channel = WIFI_CHANNEL,
            .password = PASSWORD,
            .max_connection = MAX_STA_CONN,//这里可省略
            .authmode = WIFI_AUTH_WPA_WPA2_PSK
        },
    };

if (strlen(PASSWORD) == 0)//检查密码是否为空
{
	wifi_config.ap.authmode = WIFI_AUTH_OPEN;
}

//检查错误并使能设置
ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_config));
esp_err_t tmp=esp_wifi_set_config(WIFI_IF_AP, &ap_config);

esp_wifi_connect();//连接wifi

/* 中间可加入ESP_LOGI()输出debg消息 */
```

WiFi连接实际上使用的是一套异步的状态机，所有需要调用的外设都被ESP-IDF封装起来了，开发者只需要配置基本逻辑即可。流程如下：

1. 初始化用于存储WiFi配置数据（包括ssid和密码）的NVS

2. 配置WiFi数据并将其写入WiFi外设（或NVS）

3. 开启WiFi

4. 设备自动根据外设寄存器内的配置连接附近WiFi，并根据当前连接情况向主程序发送事件集

5. 开发者编写的状态机负责处理WiFi外设发来的事件，主要分成以下几种情况：

   * WiFi已连接
   * WiFi未连接
   * 找不到指定ssid的WiFi
   * 连接丢失

   一般使用ESP-IDF中的**默认事件循环**来实现状态机

   使用其中的**事件类型**和**事件ID**区分各个不同的具体时间

关于ESP-IDF的事件集可以参考ESP32上移植的FreeRTOS相关教程