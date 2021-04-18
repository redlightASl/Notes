本篇内容根据《C程序设计新思维》编写，作者水平有限，难免存在疏漏和错误，有问题请指出

# C与POSIX的历史

**C、UNIX、POSIX的存在是紧密相连的**

C和UNIX都是在20世纪70年代由贝尔实验室的设计，而贝尔有一项与美国政府达成的协议：贝尔将不会把自身的研究扩张到软件领域，所以UNIX被免费发放给学者进行研究、重建；UNIX商标则被在数家公司之间专卖。在这个过程中，一些黑客们改进了UNIX，并增加了很多变体，于是在**1988年IEEE建立了POSIX标准**，提供了一个类UNIX操作系统的公共基础

### POSIX

规定了shell script如何工作、常用的命令行工具如何工作、能够提供哪些C库等等

除了微软的Windows系列操作系统，**几乎所有操作系统都建立在POSIX兼容的基础上**

特别地，加州大学伯克利分校的一些黑客们对UNIX进行了几乎翻天覆地的改进（重写UNIX的基础代码），产生了伯克利软件发行版（Berkeley Software istribution）BSD——苹果的MacOS正建立在这一发行版上

### GNU

GNU工程即GNU's Not UNIX工程，由笔者很敬佩的理查德斯托曼主持开工，大多数的Linux发行版都使用了GNU工具（这就是为什么Linux的全称是GNU/Linux），GNU工程下所有软件都是“自由软件”（想了解自由软件或“Free Software”的详情，推荐阅读理查德斯托曼传记《若为自由故》），这就意味着GPL！

GNU工程下属的GNU C Compiler就是为大家所熟知的C编译器gcc

## K&R C

由Dennis Ritchie和Ken Thompson以及其他的开发者共同发明的**最原始的C标准**

## ANSI C89

更被人所熟知的名字是简称“**ANSI C**”，这个版本是C的第一个成熟、统一的版本

在ANSI C成为主流这段时间内，分离出了C++

当下的POSIX规定了必须通过提供C99命令来提供C编译器

## ANSI C99

吸收了**单行注释、for(int i=0;i<N;i++)格式**等源自C++特性的ISO标准化版本

## C11

在2011年新定义的版本，做出了泛型函数、安全性提升等**“离经叛道”的改变**

GCC以光速支持了这个标准

# C开发环境搭建

C开发环境=包管理器+C库+C编译器+调试器+代码编辑器+C编译器辅助工具+打包工具+shell脚本控制工具+版本控制工具+C接口

看上去很复杂，实际上也很复杂=)

为什么不用IDE呢？当你用C开发某些小众嵌入式设备程序时就明白了（包括但不仅限于目前的MIPS、xtensa、RISC-V、你自己花三年用verilog写出来的CPU（还莫名其妙移植了一个C编译器）），IDE？TMD！

## 包管理器与编译环境

### 包管理器

每个系统都具有不同的软件包组织方式，所以你的软件很可能被安装在某个犄角旮旯，这就需要包管理器来帮助安装软件；虽然说很奇怪，但windows下也有包管理器

安装完包管理器后，就能用它安装gcc或clang这种编译器、GDB调试器、Valgrind内存使用错误检测器、Gprof（一个运行效率评测软件）、make工具、（如果你很nb还可以安装cmake工具）、Pkg-config（查找库的工具）、Doxygen（用于生成程序文档的工具）、你喜欢的文本编辑器（包括但不仅限于Emacs、Vim、VSCode、Sublime、记事本），除此之外，还能安装一些跨平台的IDE（虽然不太推荐，但eclipse就是最大众的选择，XCode需要有钱人才能买得起（指苹果电脑），Code::blocks在win下工作有点拉跨），还有必要的git工具、autoconf、automake、libtool，以及最重要的增加程序猿B格的Z shell、oh-my-zsh

包管理器还能管理C库，用一些新C库（libcURL、libGLib、libGSL、libSQLite3、libXML2），你可以实现很炫酷的现代C语言开发以及防止重新造轮子

对于一个包管理器，常会提供供用户使用的包和供开发者使用的包，在安装时应该选择带有-dev或-devel的包

### 包管理器的安装

在Linux下，包管理器分为两大阵营：

* Debian系的apt
* Red hat系的yum

目前而言，两边其实都很好用、易上手，不过根据程序猿的性格不同，选择yum的程序猿多少沾点（我使用apt，无恶意），另外还有一个叫的Arch的发行版，因为我一直没有能把它安装上，所以不知道那个`pacman -S`是什么东西

在Windows下，微软很nt（逆天，指微软很厉害）地提供了很方便的软件安装方式：让你的C盘变红。不过Windows下还是勉为其难地提供了一个POSIX兼容的东西——Cygwin是许多自由软件的集合，最初由Cygnus Solutions开发，用于各种版本的Microsoft  Windows上，运行UNIX类系统。Cygwin的主要目的是通过重新编译，将POSIX系统（例如Linux、BSD，以及其他Unix系统）上的软件移植到Windows上，可以在Cygwin网站上下载包管理工具，配合一个终端（Terminal）即可实现在Win下进行Linux开发（虽然很蛋疼）。安装方法参考百度（笑）

微软最近还开发了一个叫WSL（Windows Subsystem of Linux，最新版本是跑在windows自带虚拟机Hyper-V上的WSL2）的东西，这个东西可以让你在windows下进行不完全的linux使用（用的发行版是ubuntu），笔者目前使用的就是这个软件，安装很方便——开启Hyper-V和虚拟化、打开Microsoft应用商店搜索WSL点击下载安装即可，不过所有东西就被塞进了C盘。

### 搭建C编译器

在POSIX环境下，一切都很方便，apt install能解决一切问题，想安装什么就`sudo apt install xxx`

非POSIX环境下，可以使用MinGW来实现标准C编译器和一些基础工具，或者使用很好用的WSL

### 链接函数库

安装编译器后，链接工具会被自动安装好











