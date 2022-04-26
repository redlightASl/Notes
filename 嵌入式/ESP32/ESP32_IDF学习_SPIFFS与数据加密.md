# VFS虚拟文件系统

虚拟文件系统 (VFS) 组件可为一些驱动提供一个统一接口。有了该接口，用户可像操作普通文件一样操作虚拟文件。这类驱动程序可以是 FAT、SPIFFS 等真实文件系统，也可以是有文件类接口的设备驱动程序——官方文档

说人话就是**ESP32可以支持运行嵌入式文件系统**

目前ESP-IDF实现的功能如下：

* 按名读取/写入文件
* 兼容POSIX和C库函数文件操作
* 不会对路径中的点`.`或`..`进行特殊处理（不会将其视为对当前目录或上一级目录的引用）

已注册的VFS驱动程序均有一个路径前缀与之关联，此路径前缀即为分区的挂载点。如果挂载点中嵌套了其他挂载点，则在打开文件时使用**具有最长匹配路径前缀的挂载点**。挂载点名称必须以路径分隔符`/`开头，且分隔符后至少包含一个字符

**执行打开文件操作时，FS驱动程序仅得到文件的相对路径**

## 标准IO流

如果在menuconfig中没有将`UART for console output`设置为`None`，则`stdin`、`stdout`和`stderr`将**默认从UART读取或写入**。**UART0或UART1都可以用作标准IO**。因此可以直接调用stdio.h中的相关库函数。*默认情况下，UART0使用115200波特率，TX管脚为 GPIO1，RX管脚为GPIO3；VFS使用简单的函数对UART进行读写操作*，也可以在menuconfig中更改参数。

所有IO数据放进UART的FIFO前，写操作将处于忙等待busy-wait（阻塞）状态，读操作处于非阻塞，仅返回FIFO中已有数据。由于读操作为非阻塞，高层级的C库函数调用（如 fscanf("%d\n", &var)等）可能获取不到所需结果。如果应用程序使用UART驱动，则可以调用 `esp_vfs_dev_uart_use_driver`函数来让VFS使用驱动中断、读写阻塞功能等。也可以调用`esp_vfs_dev_uart_use_nonblocking`来使用非阻塞函数

此外，VFS还为输入和输出提供可选的换行符转换功能，可以通过menuconfig来设置输出结尾的换行符

### 标准流IO与移植的FreeRTOS

**stdin、stdout和stderr的FILE指针（对象句柄）在所有FreeRTOS任务之间共享**，指向这些对象的指针分别存储在每个任务的`struct _reent`中

为了处理各个任务之间的文件指针临界区，预处理器把如下代码：

```
fprintf(stderr, "42\n");
```

解释为：

```
fprintf(__getreent()->_stderr, "42\n");
```

__getreent函数返回一个指向struct _reent的指针

**每个任务的TCB都拥有一个struct _reent结构体，用于在本任务内处理文件而不影响其他任务**

# FATFS文件系统

ESP-IDF使用FatFs库来实现FAT文件系统

在文件中调用`#include "esp_vfs_fat.h"`和`#include "esp_vfs.h"`后可以在FLASH中通过C标准库和POSIX的API经过VFS使用FatFs库的大多数功能

经由这一功能可以实现SD卡的读取

## 使用步骤

1. 调用esp_vfs_fat_register()指定挂载文件系统的**路径前缀**、**FatFs驱动编号**和一个**用于接收指向FATFS结构指针的变量**
2. 调用ff_diskio_register()为上述步骤中的驱动编号**注册磁盘I/O驱动**
3. 调用 FatFs 函数f_mount，或f_fdisk，f_mkfs，并使用**与传递到esp_vfs_fat_register()相同的驱动编号挂载文件系统**
4. 调用 **C 标准库和 POSIX API** 对路径中带有步骤 1 中所述前缀的文件执行打开、读取、写入、擦除、复制等操作
5. **关闭**所有打开的**文件**
6. 调用f_mount并使用NULL FATFS*参数为与上述编号相同的驱动**卸载文件系统**
7. 调用FatFs函数 ff_diskio_register()并使用NULL ff_diskio_impl_t*参数和相同的驱动编号来**释放注册的磁盘I/O驱动**
8. 调用esp_vfs_fat_unregister_path()并使用文件系统挂载的路径**将 FatFs 从 NVS 中移除**，并**释放步骤 1 中分配的 FatFs 结构**

除了需要提前注册、挂载文件系统外，其他操作和正常的FATFS使用没有区别

## 磨损均衡

ESP32使用的FLASH具备扇区结构，每个扇区仅允许有限次数的擦除/修改操作，ESP-IDF提供磨损均衡组件用于平衡各个扇区之间的损耗。提供两种模式：1. 性能模式（先将数据保存在RAM中，擦除扇区，然后将数据存储回FLASH）；2. 安全模式（数据先保存在FLASH中空余扇区，擦除扇区后，数据即存储回去）

**设备默认使用性能模式且将扇区大小定为512字节**。磨损均衡组件**不会**将数据缓存在RAM中。写入和擦除函数直接修改FLASH，函数返回后，FLASH即完成修改。

常用API如下：

- `wl_mount(const esp_partition_t *partition, wl_handle_t *out_handle)`

  为指定分区挂载并初始化磨损均衡模块，通过out_handle传出句柄

- `wl_unmount(wl_handle_t handle)`

  卸载分区并释放磨损均衡模块

- `wl_erase_range(wl_handle_t handle, size_t start_addr, size_t size)`

  擦除FLASH中从start_addr开始大小为size的地址范围

- `wl_write(wl_handle_t handle, size_t dest_addr, const void *src, size_t size)`

  将数据用指针src引用后写入分区从dest_addr开始大小为size的区域

- `wl_read(wl_handle_t handle, size_t src_addr, void *dest, size_t size)`

  从分区读取从src_addr开始大小为size的数据

- `wl_size(wl_handle_t handle)`

  返回可用内存的大小（以字节为单位）

- `wl_sector_size(wl_handle_t handle)`

  返回一个扇区的大小

上面的wl_handle_t为WL句柄，可通过wl_mount的output参数传出

结合使用磨损均衡与FATFS示例如下：

```c
static wl_handle_t s_wl_handle = WL_INVALID_HANDLE;
const char *base_path = "/spiflash";

void app_main(void)
{
    //初始化VFS-FATFS
    const esp_vfs_fat_mount_config_t mount_config = {
            .max_files = 4,
            .format_if_mount_failed = true,
            .allocation_unit_size = CONFIG_WL_SECTOR_SIZE
    };
    //挂载FATFS
    esp_err_t err = esp_vfs_fat_spiflash_mount(base_path, "storage", &mount_config, &s_wl_handle);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to mount FATFS (%s)", esp_err_to_name(err));
        return;
    }
    
	//打开文件并写入
    FILE *f = fopen("/spiflash/hello.txt", "wb");
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for writing");
        return;
    }
    fprintf(f, "written using ESP-IDF %s\n", esp_get_idf_version());
    fclose(f);
    ESP_LOGI(TAG, "File written");

    //打开文件并读取
    ESP_LOGI(TAG, "Reading file");
    f = fopen("/spiflash/hello.txt", "rb");
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for reading");
        return;
    }
    char line[128];
    fgets(line, sizeof(line), f);
    fclose(f);
    // strip newline
    char *pos = strchr(line, '\n');
    if (pos)
    {
        *pos = '\0';
    }
    ESP_LOGI(TAG, "Read from file: '%s'", line);

    //卸载FATFA
    ESP_LOGI(TAG, "Unmounting FAT filesystem");
    ESP_ERROR_CHECK( esp_vfs_fat_spiflash_unmount(base_path, s_wl_handle));
    ESP_LOGI(TAG, "Done");
}
```

使用外部FLASH挂载FATFS示例如下：

```c
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "esp_flash.h"
#include "esp_flash_spi_init.h"//外部FLASH
#include "esp_partition.h"//加载额外分区表
#include "esp_vfs.h"
#include "esp_vfs_fat.h"//VFS-FATFS
#include "esp_system.h"

static wl_handle_t s_wl_handle = WL_INVALID_HANDLE;
const char *base_path = "/extflash";

static esp_flash_t* init_ext_flash(void);
static const esp_partition_t* add_partition(esp_flash_t* ext_flash, const char* partition_label);
static void list_data_partitions(void);
static bool mount_fatfs(const char* partition_label);
static void get_fatfs_usage(size_t* out_total_bytes, size_t* out_free_bytes);

void app_main(void)
{
    esp_flash_t* flash = init_ext_flash();//初始化SPI总线及外部FLASH
    if (flash == NULL)
    {
        return;
    }

    //将外部FLASH加入分区表
    const char *partition_label = "storage";
    add_partition(flash, partition_label);

    //列出当前分区
    list_data_partitions();
    //在分区内挂载FATFS
    if (!mount_fatfs(partition_label))
    {
        return;
    }

    //显示FATFS大小信息
    size_t bytes_total, bytes_free;
    get_fatfs_usage(&bytes_total, &bytes_free);
    ESP_LOGI(TAG, "FAT FS: %d kB total, %d kB free", bytes_total / 1024, bytes_free / 1024);

    //创建文件
    ESP_LOGI(TAG, "Opening file");
    FILE *f = fopen("/extflash/hello.txt", "wb");
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for writing");
        return;
    }
    fprintf(f, "Written using ESP-IDF %s\n", esp_get_idf_version());
    fclose(f);
    ESP_LOGI(TAG, "File written");

    //读取文件
    ESP_LOGI(TAG, "Reading file");
    f = fopen("/extflash/hello.txt", "rb");
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for reading");
        return;
    }
    char line[128];
    fgets(line, sizeof(line), f);
    fclose(f);
    char *pos = strchr(line, '\n');
    if (pos)
    {
        *pos = '\0';
    }
    ESP_LOGI(TAG, "Read from file: '%s'", line);
}

static esp_flash_t* init_ext_flash(void)
{
    //初始化SPI总线
    const spi_bus_config_t bus_config = {
        .mosi_io_num = VSPI_IOMUX_PIN_NUM_MOSI,
        .miso_io_num = VSPI_IOMUX_PIN_NUM_MISO,
        .sclk_io_num = VSPI_IOMUX_PIN_NUM_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
    };
	//初始化SPI FLASH设备
    const esp_flash_spi_device_config_t device_config = {
        .host_id = VSPI_HOST,
        .cs_id = 0,
        .cs_io_num = VSPI_IOMUX_PIN_NUM_CS,
        .io_mode = SPI_FLASH_DIO,
        .speed = ESP_FLASH_40MHZ
    };
    ESP_LOGI(TAG, "Initializing external SPI Flash");
    ESP_LOGI(TAG, "Pin assignments:");
    ESP_LOGI(TAG, "MOSI: %2d   MISO: %2d   SCLK: %2d   CS: %2d",
        bus_config.mosi_io_num, bus_config.miso_io_num,
        bus_config.sclk_io_num, device_config.cs_io_num
    );
    //应用设置
    ESP_ERROR_CHECK(spi_bus_initialize(VSPI_HOST, &bus_config, 1));
    //将设备挂载到SPI总线
    esp_flash_t* ext_flash;
    ESP_ERROR_CHECK(spi_bus_add_flash_device(&ext_flash, &device_config));
    //初始化外部FLASH设备
    esp_err_t err = esp_flash_init(ext_flash);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to initialize external Flash: %s (0x%x)", esp_err_to_name(err), err);
        return NULL;
    }
    //输出ID和空间大小进行检测
    uint32_t id;
    ESP_ERROR_CHECK(esp_flash_read_id(ext_flash, &id));
    ESP_LOGI(TAG, "Initialized external Flash, size=%d KB, ID=0x%x", ext_flash->size / 1024, id)
    return ext_flash;
}

static const esp_partition_t* add_partition(esp_flash_t* ext_flash, const char* partition_label)
{
    ESP_LOGI(TAG, "Adding external Flash as a partition, label=\"%s\", size=%d KB", partition_label, ext_flash->size / 1024);
    const esp_partition_t* fat_partition;
    //注册外部分区表
    ESP_ERROR_CHECK(esp_partition_register_external(ext_flash, 0, ext_flash->size, partition_label, ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_FAT, &fat_partition));
    return fat_partition;
}

static void list_data_partitions(void)
{
    //获取当前删去句柄
    ESP_LOGI(TAG, "Listing data partitions:");
    esp_partition_iterator_t it = esp_partition_find(ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_ANY, NULL);
	//以链表形式遍历扇区
    for (; it != NULL; it = esp_partition_next(it))
    {
        const esp_partition_t *part = esp_partition_get(it);
        ESP_LOGI(TAG, "- partition '%s', subtype %d, offset 0x%x, size %d kB",
        part->label, part->subtype, part->address, part->size / 1024);
    }
	//释放当前分区迭代器
    esp_partition_iterator_release(it);
}

static bool mount_fatfs(const char* partition_label)
{
    //挂载FAT文件系统到外部FLASH
    const esp_vfs_fat_mount_config_t mount_config = {
            .max_files = 4,
            .format_if_mount_failed = true,
            .allocation_unit_size = CONFIG_WL_SECTOR_SIZE
    };
    esp_err_t err = esp_vfs_fat_spiflash_mount(base_path, partition_label, &mount_config, &s_wl_handle);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to mount FATFS (%s)", esp_err_to_name(err));
        return false;
    }
    return true;
}

static void get_fatfs_usage(size_t* out_total_bytes, size_t* out_free_bytes)
{
    FATFS *fs;//文件系统指针
    size_t free_clusters;
    int res = f_getfree("0:", &free_clusters, &fs);
    assert(res == FR_OK);
    size_t total_sectors = (fs->n_fatent - 2) * fs->csize;
    size_t free_sectors = free_clusters * fs->csize;

    //假设扇区总大小<4GB，对SPI FLASH应为真
    if (out_total_bytes != NULL)
    {
        *out_total_bytes = total_sectors * fs->ssize;
    }
    if (out_free_bytes != NULL)
    {
        *out_free_bytes = free_sectors * fs->ssize;
    }
}
```

# SPIFFS文件系统

SPIFFS 是一个用于 SPI NOR flash 设备的嵌入式文件系统，支持磨损均衡、文件系统一致性检查等功能——官方文档。

目前位置SPIFFS还是一个不完全的文件系统：不支持目录，只能生成扁平结构；不是实时栈，每次写操作耗时不等；不支持检测或处理已损坏的块等

但是这玩意确实很好用

使用spiffsgen.py工具就可以配置SPIFFS，shell中使用格式如下

```shell
python spiffsgen.py <image_size> <base_dir> <output_file>
```

其中image_size为分区大小，**base_dir为SPIFFS映像所在目录，output_file为SPIFFS映像输出文件**

也可以使用CMake工具进行配置：

```cmake
spiffs_create_partition_image(<partition> <base_dir> [FLASH_IN_PROJECT] [DEPENDS dep dep dep...])

//使用例
spiffs_create_partition_image(my_spiffs_partition my_folder FLASH_IN_PROJECT)
```

CMake配置自动传递给spiffsgen.py工具生成映像。单独调用 `spiffsgen.py` 时需要用到 *image_size* 参数，但在CMake中调用`spiffs_create_partition_image`时仅需要 *partition* 参数，**映像大小将直接从当前工程的分区表中获取**。

注意：在CMake中使用`spiffs_create_partition_image`，需从组件CMakeLists.txt文件调用

下面是一个标准的SPIFFS分区表示例

```
# Name,   Type, SubType, Offset,  Size, Flags
# Note: if you have increased the bootloader size, make sure to update the offsets to avoid overlap
nvs,      data, nvs,     0x9000,  0x6000,
phy_init, data, phy,     0xf000,  0x1000,
factory,  app,  factory, 0x10000, 1M,
storage,  data, spiffs,  ,        0xF0000, 
```

**需要使用SubType=spiffs标识出某一分区是SPIFFS存储分区**

## SPIFFS配置与API参考

在文件中调用`#include "esp_spiffs.h"`就可以使用相关API

使用以下API初始化SPIFFS到虚拟文件系统

```c
esp_err_t esp_vfs_spiffs_register(const esp_vfs_spiffs_conf_t *conf)
```

esp_vfs_spiffs_conf_t是SPIFFS文件系统初始化结构体，应如下配置：

```c
esp_vfs_spiffs_conf_t conf = {
	.base_path = "/spiffs",//根目录
	.partition_label = NULL,//分区表的标签
	.max_files = 5,//该目录下能存储的最大文件数目
	.format_if_mount_failed = true//如果挂载失败则会格式化文件系统
};
```

更多API如下所示：

```c
esp_err_t esp_vfs_spiffs_unregister(const char *partition_label);//取消VFS上的SPIFFS初始化
bool esp_spiffs_mounted(const char *partition_label);//检查文件系统是否挂载
esp_err_t esp_spiffs_format(const char *partition_label);//格式化当前分区的文件系统
esp_err_t esp_spiffs_info(const char *partition_label, size_t *total_bytes, size_t *used_bytes);//获取某分区文件系统的参数    
```

## 用C库函数进行SPIFFS文件读写

可以使用POSIX和C库函数在SPIFFS写入和读取数据

下面是官方给出的使用例

```c
void app_main(void)
{
    //初始化SPIFFS
    esp_vfs_spiffs_conf_t conf = {
      .base_path = "/spiffs",
      .partition_label = NULL,
      .max_files = 5,
      .format_if_mount_failed = true
    };
    esp_err_t ret = esp_vfs_spiffs_register(&conf);
    
    //检测SPIFFS初始化是否正常
    if (ret != ESP_OK)
    {
        if (ret == ESP_FAIL)
        {
            ESP_LOGE(TAG, "Failed to mount or format filesystem");
        }
        else if (ret == ESP_ERR_NOT_FOUND)
        {
            ESP_LOGE(TAG, "Failed to find SPIFFS partition");
        }
        else
        {
            ESP_LOGE(TAG, "Failed to initialize SPIFFS (%s)", esp_err_to_name(ret));
        }
        return;
    }
    size_t total = 0, used = 0;
    ret = esp_spiffs_info(conf.partition_label, &total, &used);
    if (ret != ESP_OK)
        ESP_LOGE(TAG, "Failed to get SPIFFS partition information (%s)", esp_err_to_name(ret));
    else
        ESP_LOGI(TAG, "Partition size: total: %d, used: %d", total, used);

    FILE* f = fopen("/spiffs/hello.txt", "w");//打开文件
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for writing");
        return;
    }
    fprintf(f, "Hello World!\n");//写入文件
    fclose(f);//关闭文件
    ESP_LOGI(TAG, "File written");

    struct stat st;
    if (stat("/spiffs/foo.txt", &st) == 0)//检测文件是否存在
    {
        unlink("/spiffs/foo.txt");
    }

    if (rename("/spiffs/hello.txt", "/spiffs/foo.txt") != 0)//重命名
    {
        ESP_LOGE(TAG, "Rename failed");
        return;
    }

    f = fopen("/spiffs/foo.txt", "r");//打开文件
    if (f == NULL)
    {
        ESP_LOGE(TAG, "Failed to open file for reading");
        return;
    }
    char line[64];
    fgets(line, sizeof(line), f);//读取文件
    fclose(f);//关闭文件
    char* pos = strchr(line, '\n');
    if (pos)
    {
        *pos = '\0';
    }
    ESP_LOGI(TAG, "Read from file: '%s'", line);

    esp_vfs_spiffs_unregister(conf.partition_label);//解除SIFFS挂载
    ESP_LOGI(TAG, "SPIFFS unmounted");
}
```

# FLASH加密

FLASH加密功能用于加密与ESP32搭载使用的SPI Flash中的内容。启用FLASH加密功能后，物理读取SPI FLASH便无法恢复大部分FLASH内容。通过明文数据烧录ESP32可应用加密功能，**若已启用加密功能，引导加载程序会在首次启动时对数据进行加密**。

FLASH加密功能与密钥同样稳固，但并非所有数据都是加密存储且无法防止攻击者获取FLASH的高层次布局信息

**为了防止攻击者直接恶意修改固件，推荐搭配使用FLASH加密与安全启动**，但启用安全启动时，OTA

启用FLASH加密后，系统将默认加密下列类型的FLASH数据：

- BootLoader
- 分区表
- 所有app类型的分区

其他类型的FLASH数据将视情况进行加密：

- 如果已启用安全启动，则会加密安全启动引导加载程序摘要
- 分区表中标有加密标记的分区

注意：==启用 Flash 加密将限制后续 ESP32 更新==

FLASH加密分为两种模式：开发模式和生产模式

## 使用FLASH加密

一般地，**只要在menuconfig中设置使用加密并使用加密方式烧录即可使用FLASH加密**

1. 开发模式：可使用 ESP32 内部生成的密钥或外部主机生成的密钥在开发中运行FLASH加密

2. 生产模式：使用ESP32生成的FLASH加密密钥

在程序中使用`#include "esp_flash_encrypt.h"`、`#include "esp_efuse_table.h"`、`#include "esp_efuse.h"`、`#include "soc/efuse_reg.h"`后可以使用相关API

分区表如下：

```c
# Name,   Type, SubType, Offset,  Size, Flags
nvs,        data, nvs,      0x9000,  0x6000,
# Extra partition to demonstrate reading/writing of encrypted flash
storage,    data, 0xff,     0xf000,  0x1000, encrypted
factory,    app,  factory,  0x10000, 1M,
```

如果所有分区都需以加密格式更新，则可使用以下命令：

```
idf.py encrypted-flash monitor
```

只要 `FLASH_CRYPT_CNT` eFuse 设置为奇数位的值，所有通过MMU的FLASH缓存访问的FLASH内容都将被透明解密：MMU FLASH缓存将无条件解密所有数据

3. 释放模式下，UART引导加载程序无法执行FLASH加密操作，**只能使用OTA**下载已经加密过的映像

可通过调用函数esp_flash_encryption_enabled()来确认当前是否已启用FLASH加密

可通过调用函数esp_get_flash_encryption_mode()来识别使用的FLASH加密模式

使用分区读取函数esp_partition_read()来读取加密分区的数据

下面是使用FLASH加密的示例

```c
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "soc/efuse_reg.h"
#include "esp_efuse.h"
#include "esp_system.h"
#include "esp_spi_flash.h"
#include "esp_partition.h"
#include "esp_flash_encrypt.h"
#include "esp_efuse_table.h"

#if CONFIG_IDF_TARGET_ESP32
#define TARGET_CRYPT_CNT_EFUSE  ESP_EFUSE_FLASH_CRYPT_CNT
#define TARGET_CRYPT_CNT_WIDTH  7
#elif CONFIG_IDF_TARGET_ESP32S2
#define TARGET_CRYPT_CNT_EFUSE ESP_EFUSE_SPI_BOOT_CRYPT_CNT
#define TARGET_CRYPT_CNT_WIDTH  3
#endif

static void print_flash_encryption_status(void);//输出FLASH加密状态
    
void app_main(void)
{
    print_flash_encryption_status();//像函数中使用API才能访问加密分区
}

static void print_flash_encryption_status(void)
{
    uint32_t flash_crypt_cnt = 0;
    esp_efuse_read_field_blob(TARGET_CRYPT_CNT_EFUSE, &flash_crypt_cnt, TARGET_CRYPT_CNT_WIDTH);
    printf("FLASH_CRYPT_CNT eFuse value is %d\n", flash_crypt_cnt);

    esp_flash_enc_mode_t mode = esp_get_flash_encryption_mode();
    if (mode == ESP_FLASH_ENC_MODE_DISABLED)
    {
        printf("Flash encryption feature is disabled\n");
    }
    else
    {
        printf("Flash encryption feature is enabled in %s mode\n",
            mode == ESP_FLASH_ENC_MODE_DEVELOPMENT ? "DEVELOPMENT" : "RELEASE");
    }
}
```

sdkconfig中的相关条目如下：

```c
CONFIG_SECURE_FLASH_ENC_ENABLED=y
CONFIG_SECURE_FLASH_ENCRYPTION_MODE_DEVELOPMENT=y
CONFIG_SECURE_BOOT_ALLOW_ROM_BASIC=y
CONFIG_SECURE_BOOT_ALLOW_JTAG=y
CONFIG_SECURE_FLASH_UART_BOOTLOADER_ALLOW_ENC=y
CONFIG_SECURE_FLASH_UART_BOOTLOADER_ALLOW_DEC=y
CONFIG_SECURE_FLASH_UART_BOOTLOADER_ALLOW_CACHE=y
CONFIG_SECURE_FLASH_REQUIRE_ALREADY_ENABLED=y
```