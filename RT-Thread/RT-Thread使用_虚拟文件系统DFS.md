# 虚拟文件系统

**文件系统**：一套用于实现数据存储、分级组织、访问和获取等操作的抽象数据类型（Abstract Data Type，ADT），用于下向用户提供底层数据访问的机制

GNU/Linux的虚拟文件系统（VFS）是物理文件系统与服务之间的一个接口层，它对UNIX（GNU/Linux、MS-Windows）的每个文件系统的所有细节进行抽象，使得不同的文件系统在操作系统内核以及系统中运行的其他进程看来都是相同的。VFS并不是一种实际的文件系统。它只存在于内存中，不存在于任何外存空间

**文件系统的基本存储单位和组织单位是文件，使用目录作为容纳多个文件的容器**

RTT提供一套虚拟文件系统DFS，它的实现和VFS类似，但更适合嵌入式设备。虚拟文件系统（Device File System，设备文件系统）的使用风格类似UNIX使用的文件、目录风格

也就是`根目录/目录/文件`的风格，根目录为`/`

具有以下特点：

* 提供统一的POSIX文件和目录操作接口
* 支持多种类型的文件系统，包括但不限于FatFS、RomFS、DevFS等
* 提供普通文件、设备文件、网络文件描述符的管理
* 支持多种类型的存储设备，包括但不限于SD卡、SPI FLASH、Nand FLASH

## DFS层次结构

![DFS 层次架构图](https://www.rt-thread.org/document/site/programming-manual/filesystem/figures/fs-layer.png)

### POSIX接口层

POSIX即可移植操作系统接口（Portable Operating System Interface of UNIX，POSIX），定义了操作系统应该为应用程序提供的接口标准，因此所有类UNIX系统的软件都可以通过这个接口规定的标准API访问文件

RTT正是因此获得了对Unix（GNU/Linux）应用程序的兼容性

类UNIX系统中，普通文件、设备文件、网络文件描述符是同一种文件描述符；而在RTT中，使用DFS来实现这种统一性，可以使用poll/select接口来对这几种描述符进行统一轮询或阻塞地同时探测一组支持非阻塞的I/O设备是否有事件发生，直至某一个设备触发了事件或者超过了指定的等待时间，帮助寻找当前就绪的设备，降低编程的复杂度

### 虚拟文件系统层

用户可以将具体的文件系统注册到DFS中，之后就能使用该文件系统的所有功能

目前支持包括但不限于以下文件系统：

* FatFS：专**为小型嵌入式设备**开发的一个**兼容微软FAT**格式的文件系统，使用ANSI C编写，可移植性较高，在RTT中最常用
* RomFS：简单、紧凑、**只读**的文件系统，不支持动态擦写保存，固定按顺序存放数据，可以**节省RAM空间**
* Jffs2：日志闪存文件系统，主要用于NOR FLASH，可读写、支持数据压缩、基于哈希表、提供崩溃/掉电安全保护、写平衡支持等，多用于存放日志文件
* DevFS：设备文件系统，可以将系统中的设备在/dev文件夹下虚拟成文件，使得设备可以按照文件的操作方式使用read、write等接口进行操作，**用于实现UNIX的”万物皆文件“**
* NFS（Network File System）：网络文件系统技术，在不同机器、不同操作系统之间通过网络共享文件的技术。可以利用该技术在主机上建立基于NFS的根文件系统，挂载到嵌入式设备上，可以很方便地修改根文件系统的内容。用于调试开发
* UFFS（Ultra-low-cost Flash File System）：超低功耗的闪存文件系统。国人开发、专为嵌入式设备使用Nand FLASH的开源文件系统，资源占用少、启动速度快、免费

### 设备抽象层

将物理设备（如SD卡、SPI Flash、Nand Flash等）抽象成符合文件系统能够访问的设备（如块设备）

不同文件系统类型独立于存储设备驱动实现，因此把底层存储设备的驱动接口和文件系统对接起来之后，才可以正确地使用文件系统功能

## 使用文件系统

只要通过ENV工具在menuconfig中选择

```
RT-Thread Components  --->
    Device virtual file system  --->
```

下面的内容就可以配置DFS选项

默认情况下，RTT为了获得较小的内存占用，并不会开启相对路径功能；可在文件系统的配置项中开启相对路径功能

默认情况下，FatFs 的文件命名有如下缺点：

- 文件名（不含后缀）最长不超过8个字符，后缀最长不超过3个字符，文件名和后缀超过限制后将会被截断。
- 文件名不支持大小写（显示为大写）

如果需要支持长文件名，则需要打开支持长文件名选项

此外，RTT或其默认使用的FatFS会默认使用437编码（en_US），如果需要存储中文文件名可以使用936编码（GBK），需要一个额外的大约180KB的字库，这个字库应该存储在FLASH内

RTT支持自定义文件系统内部扇区大小，**需要大于等于实际硬件驱动的扇区大小**。*一般FLASH设备可以设置为4096，常见的TF卡和SD的扇区大小推荐设置为512*

### 初始化## 与使用步骤RTT

1. 初始化DFS组件
2. 初始化具体类型的文件系统
3. 在存储器上创建块设备
4. 格式化块设备
5. 挂载块设备到DFS目录
6. 如有必要可以卸载文件系统

### 挂载管理

使用

```c
dfs_init()
```

初始化DFS组件所需的相关资源并创建数据结构。RTT默认开启自动初始化，一般来说不需要手动调用该函数

使用以下API将具体的文件系统注册到DFS中并进行格式化

```c
int dfs_register(const struct dfs_filesystem_ops *ops);//注册文件系统
int dfs_mkfs(const char * fs_name, const char * device_name);//格式化
```

同样不需要手动调用，两个API会被不同文件系统的初始化函数调用

特别地，在格式化之前需要确保存储设备被抽象为**块设备**，例如使用了SPI FLASH，就应该使用*串行FLASH通用驱动库SFUD*组件来将FLASH抽象为块设备用于挂载，API中的device_name应写入块设备名称

可用的文件系统类型（fs_name）如下所示

| **取值** | **文件系统类型**       |
| -------- | ---------------------- |
| elm      | elm-FAT 文件系统       |
| jffs2    | jffs2 日志闪存文件系统 |
| nfs      | NFS 网络文件系统       |
| ram      | RamFS 文件系统         |
| rom      | RomFS 只读文件系统     |
| uffs     | uffs 文件系统          |

完成上述操作后使用下面的API来将存储设备挂接到一个已存在的路径上，这一步和UNIX中的mount指令一致

```c
int dfs_mount(const char   *device_name,//已经格式化的块设备名称
              const char   *path,//挂载点(挂载路径)
              const char   *filesystemtype,//挂载的文件系统类型
              unsigned long rwflag,//读写标志位
              const void   *data);//特定文件系统的私有数据
```

**如果只有一个存储设备，则可以直接挂载到根目录 `/` 上**

使用

```c
int dfs_unmount(const char *specialfile);
```

卸载挂载到specialfile路径的文件系统

## 使用文件

使用以下C/UNIX风格API操作文件

```c
int open(const char *file, int flags, ...);//打开文件

/* 可用的flags取值如下，决定其打开方式 */
O_RDONLY 	//只读方式打开文件
O_WRONLY 	//只写方式打开文件
O_RDWR 		//以读写方式打开文件
O_CREAT 	//如果要打开的文件不存在，则建立该文件
O_APPEND 	//当读写文件时会从文件尾开始移动，也就是所写入的数据会以附加的方式添加到文件的尾部
O_TRUNC 	//如果文件已经存在，则清空文件中的内容
    
int close(int fd);//关闭文件

//读文件
int read(int fd,//文件描述符
         void *buf,//缓冲区指针
         size_t len);//读取文件的字节数
//该函数会把fd所指的文件的len个字节读取到buf指针所指的内存中。文件的读写位置指针会随读取到的字节移动

//写文件
int write(int fd, const void *buf, size_t len);//使用方法类似上面的读文件
int rename(const char *old, const char *new);//重命名文件
int stat(const char *file, struct stat *buf);//获取文件状态
int unlink(const char *pathname);//删除指定目录下的文件，注意这里的pathname必须写入绝对路径

int fsync(int fildes);//同步内存中所有已修改的文件数据到储存设备
int statfs(const char *path, struct statfs *buf);//查询文件系统相关信息

//监视 I/O 设备是否有事件发生
//该函数可以阻塞地同时探测一组支持非阻塞的I/O设备是否有事件发生，直至某一个设备触发了事件或者超过了指定的等待时间
int select( int nfds,//所有文件描述符的最大值加1
            fd_set *readfds,//需要监视读变化的文件描述符集合
            fd_set *writefds,//需要监视写变化的文件描述符集合
            fd_set *exceptfds,//需要监视出现异常的文件描述符集合
            struct timeval *timeout);//select的超时时间
```

## 目录管理

使用以下API可以对目录进行操作

```c
int mkdir(const char *path, mode_t mode);//创建目录
//参数mode在当前版本未启用，填入默认参数0x777即可

int rmdir(const char *pathname);//删除目录
DIR* opendir(const char* name);//打开目录
int closedir(DIR* d);//关闭目录

struct dirent* readdir(DIR *d);//读取目录
//参数d为目录流指针，每读取一次目录，目录流指针将自动往后递推1个位置

long telldir(DIR *d);//获取目录流的读取位置
//该函数的返回值记录着一个目录流的当前位置，此返回值代表距离目录文件开头的偏移量
void seekdir(DIR *d, off_t offset);//设置下次读取目录的位置
void rewinddir(DIR *d);//重设目录流的读取位置为开头
```

`telldir()` 函数可以和 `seekdir()` 函数配合使用，用于重新设置目录流的读取位置到指定的偏移量

这里将目录视为可以操作的对象，每个目录的位置由目录流决定，通过目录流的移动来读取目录

注意：==一般情况下所有路径都要填写绝对路径==

## FinSH指令

在FinSH中可以使用UNIX-like的指令对文件进行操作