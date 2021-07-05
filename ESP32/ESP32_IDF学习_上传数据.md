作业答辩结束了（让老师喷了一轮），但是突然发现学校的大创项目需要用到ESP32（甚至还可能用到乐鑫新出的ESP32-C3），看看自己写了那么一堆博文，决定一不做二不休，接着靠ESP-IDF一条路走到黑！

接着要看的就是ESP32的核心部分——联网传数据。

# 配网

联网传数据首先需要实现联网！

目前有以下几种适合ESP32的配网方法

## 写入固件

这个方法是最容易实现的。

按照之前WiFi部分的笔记，把相关代码写好，在ESP-IDF的menuconfig里配置完ssid和密码就能让设备联网了

但是很明显，生产产品的时候不能这么做

这种方式只适合调试和原型验证（还有交作业）

## SmartConfig

在实际应用中，往往会遇到很多不同的WiFi STA，通过将ssid和密码固定写入NVS或外设寄存器再连接的方式很明显不灵活

所以为了让嵌入式设备更简单地配网，SmartConfig应运而生

**SmartConfig**又名快连，能够实现在当前设备在没有和其他设备建立任何实际性通信链接的状态下，一键配置该设备接入WIFI，这个技术可以让手机通过配网APP向嵌入式设备发送当前连接的WiFi的ssid和密码，进而让嵌入式设备连接网络。

SmartConfig采用的是UDP广播模式（接收IP地址是255.255.255.255）。实现很简单：设备先scan环境下的所有AP，得到AP的相关信息，最基本的实现就是取得工作的channel；然后配置WiFi设备工作在刚才scan到的channel上去接收UDP包——如果没有接收到，继续配置工作在另外的channel 上，如此循环，直到收到UDP包为止。这样SmartConfig就完成了

这个配网方法的致命缺点就是成功率低，受当前场合的信号干扰影响大，而且有些路由器、手机或嵌入式设备不支持；优点则是可以一键配网，只要在手机上搭载相关的APP就能完成配置。

### 示例代码

```c
#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_wifi.h"
#include "esp_wpa2.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_smartconfig.h"

//WiFi事件集合
static EventGroupHandle_t s_wifi_event_group;

static const int CONNECTED_BIT = BIT0; //指示连接AP的信号量（标志位）
static const int ESPTOUCH_DONE_BIT = BIT1; //指示完成SmartConfig的信号量（标志位）
static const char *TAG = "SmartConfig";

static void smartconfig_task(void * parm);
    
static void event_handler(void* arg, esp_event_base_t event_base, 
                                int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START)
    {
        //WiFi热点建立后创建smartconfig任务
        xTaskCreate(smartconfig_task, "smartconfig_task", 4096, NULL, 3, NULL);
    }
    else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) 
    {
        //WiFi断点续连
        esp_wifi_connect();
        xEventGroupClearBits(s_wifi_event_group, CONNECTED_BIT);
    } 
    else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) 
    {
        //WiFi自动分配IP
        xEventGroupSetBits(s_wifi_event_group, CONNECTED_BIT);
    } 
    else if (event_base == SC_EVENT && event_id == SC_EVENT_SCAN_DONE) 
    {
        //完成SmartConfig扫描
        ESP_LOGI(TAG, "Scan done");
    } 
    else if (event_base == SC_EVENT && event_id == SC_EVENT_FOUND_CHANNEL) 
    {
        //发现SmartConfig通道
        ESP_LOGI(TAG, "Found channel");
    } 
    else if (event_base == SC_EVENT && event_id == SC_EVENT_GOT_SSID_PSWD) 
    {
        //通过SmartConfig获取到了SSID和密码
        ESP_LOGI(TAG, "Got SSID and password");
		
        //暂时保存所得数据
        smartconfig_event_got_ssid_pswd_t *evt = (smartconfig_event_got_ssid_pswd_t *)event_data;
        
        //开始配置WiFi
        wifi_config_t wifi_config;
        uint8_t ssid[33] = { 0 };
        uint8_t password[65] = { 0 };
        bzero(&wifi_config, sizeof(wifi_config_t));
        //按照传来数据设置SSID和密码
        memcpy(wifi_config.sta.ssid, evt->ssid, sizeof(wifi_config.sta.ssid));
        memcpy(wifi_config.sta.password, evt->password, sizeof(wifi_config.sta.password));
        wifi_config.sta.bssid_set = evt->bssid_set;
        if (wifi_config.sta.bssid_set == true)
        {
            memcpy(wifi_config.sta.bssid, evt->bssid, sizeof(wifi_config.sta.bssid));
        }
        memcpy(ssid, evt->ssid, sizeof(evt->ssid));
        memcpy(password, evt->password, sizeof(evt->password));
        ESP_LOGI(TAG, "SSID:%s", ssid);
        ESP_LOGI(TAG, "PASSWORD:%s", password);

        ESP_ERROR_CHECK(esp_wifi_disconnect()); //断开对默认WiFi的连接（实际上并没有连接，只是连了个虚拟WiFi）
        ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config)); //按照设置配置新WiFi数据
        ESP_ERROR_CHECK(esp_wifi_connect()); //连接WiFi
    }
    else if (event_base == SC_EVENT && event_id == SC_EVENT_SEND_ACK_DONE)
    {
        //获取SmartConfig完成的消息后发送完成SmartConfig的信号量（标志位）
        xEventGroupSetBits(s_wifi_event_group, ESPTOUCH_DONE_BIT);
    }
}

static void smartconfig_task(void * parm)
{
    EventBits_t uxBits;
    ESP_ERROR_CHECK(esp_smartconfig_set_type(SC_TYPE_ESPTOUCH)); //设置SmartConfig类型
    smartconfig_start_config_t cfg = SMARTCONFIG_START_CONFIG_DEFAULT(); //按照默认配置初始化
    ESP_ERROR_CHECK(esp_smartconfig_start(&cfg)); //启动SmartConfig
    
    while (1)
    {
        //等待事件集合传来CONNECTED_BIT或ESPTOUCH_DONE_BIT的标志
        uxBits = xEventGroupWaitBits(s_wifi_event_group,
                                     CONNECTED_BIT | ESPTOUCH_DONE_BIT, true, false, portMAX_DELAY);
        //如果收到CONNECTED_BIT标志
        if(uxBits & CONNECTED_BIT) 
        {
            //已连接AP
            ESP_LOGI(TAG, "WiFi Connected to ap");
        }
        //如果收到ESPTOUCH_DONE_BIT标志
        if(uxBits & ESPTOUCH_DONE_BIT) 
        {
            //完成SmartConfig
            ESP_LOGI(TAG, "smartconfig over");
            esp_smartconfig_stop();
            vTaskDelete(NULL);
        }
    }
}

void app_main(void)
{
    ESP_ERROR_CHECK(nvs_flash_init()); //初始化NVS
    ESP_ERROR_CHECK(esp_netif_init()); //初始化网络接口
    
    s_wifi_event_group = xEventGroupCreate(); 
    ESP_ERROR_CHECK(esp_event_loop_create_default()); //初始化事件集与默认事件循环
    
    esp_netif_t *sta_netif = esp_netif_create_default_wifi_sta(); //创建默认的STA模式WiFi
    assert(sta_netif);
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT(); //按照默认参数初始化
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    //注册WiFi连接、IP获取、SmartConfig连接的回调函数
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(SC_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL));

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA)); //设置为STA模式
    ESP_ERROR_CHECK(esp_wifi_start()); //启动WiFi，等待SmartConfig
}
```

总体思路就是使用事件集合、信号量传递数据并利用回调函数中的状态机处理每一种WiFi和SmartConfig的情况

其中涉及的SmartConfig专用API有

```c
esp_smartconfig_set_type(SC_TYPE_ESPTOUCH); //设置SmartConfig类型，这里使用的是ESPTOUCH，还可以使用如下类型：
/*
SC_TYPE_AIRKISS
SC_TYPE_ESPTOUCH_AIRKISS
*/

esp_smartconfig_start(&cfg); //按照设置开启SmartConfig
esp_smartconfig_stop(); //停止SmartConfig工作
```

使用前应调用

```c
#include "esp_smartconfig.h"
```

注意对于回传的SmartConfig数据应使用`smartconfig_event_got_ssid_pswd_t`指针进行保存

# lwIP协议栈

联网以后，自然需要一套嵌入式设备能使用的TCP/IP协议栈来让设备连接服务器或作为服务器提供服务

ESP32性能有限，使用一套称为Light Weight IP的小型IP协议栈，这就是**lwIP**

ESP32的WiFi实现部分没有开源，所以在这里仅使用官方例程说明ESP32的lwIP库

## ESP32的lwIP库

### 常用API







### 示例程序









# HTTP

在HTTP部分已经简单介绍过如何使用ESP32进行HTTP通讯，在这里深入学习一下ESP-IDF中实现的HTTP库和相关API







# WebSocket







# MDNS









# OPENSSL



















# MQTT

MQTT是典型的物联网数据传输协议

因为相关内容比较多所以单成篇

详细内容可查看MQTT相关教程和博文