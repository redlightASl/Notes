# TCP协议栈

ESP使用lwIP作为嵌入式的TCP/IP协议栈支持

相关内容可以参考lwIP库函数，在ESP-NETIF库中得到支持

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

# HTTP客户端

