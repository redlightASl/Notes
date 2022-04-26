# RTC设备

RTC就是实时时钟，而IoT设备的标配就是实时时钟——虽然可以从网络上得到精准的时间戳进行同步，但是在SSL加密传输等情况下必须使用本地的RTC来实现计时。RTT也配备了RTC设备驱动

## 操作RTC设备

### 访问接口

1. set_date()

   设置日期

   ```c
   rt_err_t set_date(rt_uint32_t year,//年
                     rt_uint32_t month,//月
                     rt_uint32_t day)//日
   ```

   示例：

   ```c
   set_date(2021,5,1);//设置当前时间为2021年5月1日
   ```

2. set_time()

   设置时间

   ```c
   rt_err_t set_time(rt_uint32_t hour,//小时
                     rt_uint32_t minute,//分钟
                     rt_uint32_t second)//秒
   ```

   示例：

   ```c
   set_time(12, 12, 0);//设置为12时12分0秒
   ```

3. time()

   ```c
   time_t time(time_t *t)//t为时间数据指针，一般没有用
   ```

   获取当前时间，一般情况下没有时间数据指针，参数应设置为RT_NULL

   ```c
   time_t now; //保存获取的当前时间值
   now = time(RT_NULL);//获取时间
   ```

### 附加功能

RTT中提供了对没有RTC硬件的嵌入式设备的RTC支持

* 软件模拟RTC

  在menuconfig中可以配置使用软件模拟RTC，适用于对时间精度要求不高且没有硬件RTC的项目

* NTP时间同步

  **如果RTT设备已接入互联网，可启用NTP时间自动同步功能**，定期同步本地时间！

  在menuconfig中可以启用该功能并设置同步周期，单位是秒