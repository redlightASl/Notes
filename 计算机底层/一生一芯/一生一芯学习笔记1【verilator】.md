# Verilator入门

今年2月底报名了22年第四期[一生一芯](https://docs.ysyx.org)，借着这个机会学学前端设计相关内容

个人目标暂且定为：

* 设计一个五级流水，可挂载协处理器的RV32IMF指令集处理器
* 在两到三期内完成一生一芯规定的基础流片指标
* 挂载一个可用于图像处理的加速器
* 使用AMBA总线在片上集成一套用于水下机器人控制的外设（包括GPIO、UART、PWM、DCMI、DMA、MAC）
* 将自制的RTOS开发完毕并部署在SoC上
* 将芯片部署在一台ROV中并实现完整的机器人控制、水下图像识别任务

希望能在本科期间把这一套东西做完......

22年第四期一生一芯要求在开始之前需要自己搭建基于verilator+gtkwave的验证环境（预学习阶段），这里简单记录一下这部分的要点内容（**教程不允许将自己代码发布到公开网站，这里遵守要求仅记录知识点和bug解决思路**）

这系列博文与其说是笔记，不如说是对这段学习经历的总结？

## 如何科学的提问

要求阅读[提问的智慧](https://github.com/ryanhanwu/How-To-Ask-Questions-The-Smart-Way/blob/master/README-zh_CN.md)和[别像弱智一样提问](https://github.com/tangx/Stop-Ask-Questions-The-Stupid-Ways/blob/master/README.md)并写800字读后感

> 我的评价是：**切中要害**

里面的STFW，RTFM，RTFSC即`Search The Fucking Web`、`Read The Fucking Manual`、`Read The Fucking Source Code`，基本上就是程序员/芯片工程师/硬件工程师解决问题的三个基本方法。

### 硬件工程师

选型：STFW从官网选型工具找到合适的芯片，RTFM从器件特性获得选型参考

设计：通过STFW获得官方的教程支持，然后就是猛抄手册的参考电路

调试：RTFM，RTFM还是RTFM，板级设计最需要参考的就是各种各样的用户手册

不过相对程序员或者芯片工程师来说，硬件工程师的工作更依赖有经验的老师傅指导，因为很多时候网络上的东西会过时、不准，手册根本没法提供有用信息，甚至参考书都会对同一电路给出截然不同的分析结果，而一个调试过更多板子的老师傅往往能通过实际解决方案给新手更好的经验。而且作为硬件工程师，使用各种仪器往往比查找资料更重要

### 芯片工程师/程序员

学习：STFW和RTFSC是最主要的学习方式，正如那句古语`Talk is cheap,show me your code`（虽然这是调bug时候用的），对于和代码相关的东西最好的学习手段就是去读它！

框架设计：软件工程的思维很重要，不过对于芯片工程师来说硬件逻辑思维更重要，这需要一点点积累，不过通过RTFM和STFW往往能让新手快速成长（尤其是阅读理解水平......）

调试：这下需要三个F共用了，软件调试虽然没有硬件调试那样的危险性，但是往往更加折磨——你需要反复地在bug和资料之间跳转，中途还需要思考自己的程序逻辑。在软件调试中，一个老手往往远不如一个科学上网工具（仅供google、github、StackOverflow使用），因为很多bug老手都不一定见过，这不像遵循半导体物理逻辑的模拟电路，虽然数字逻辑很明显，但bug的更新迭代速度会大于一个人的知识积累速度（笑）

> 话说上面的内容都快800字了，不如直接把这篇博文交上去罢！

## Linux安装与使用（PA0）

这里就是基本的Linux使用内容，如果之前看过一些Linux教程会很快上手

感觉里面最好的地方是有全套的git使用指导。如果有机会我一定会把这部分内容推荐给实验室的学弟学妹。教程里面把获取模板和git教程放到了一起，亲手做一遍全流程的感觉和看网上教程的感觉真的完全不一样，这部分内容也让我巩固了很多git方面的知识

需要批评的是：个人感觉里面对于vim吹太过了。。。

当然也有可能是本人水平有限抑或是还没能体会到vim的高效开发方式（但是作为一个使用vim也有两年多的人我并不感觉是这样）

> 程序设计课上你学会了使用Visual Studio, 然后你可能会认为, 程序员就是这样写代码的了. 其实并不是,  程序员会追求那些提高效率的方法. 不是GUI不好, 而是你只是用记事本的操作方式来写代码. 所以你需要改变,  去尝试一些可以帮助你提高开发效率的工具.
>
> 在GNU/Linux中, 与记事本的操作方式相比, 学会`vim`的基本操作就已经可以大大提高开发效率. 还有各种插件来增强`vim`的功能, 比如可以在代码中变量跳转的`ctags`等等. 你可以花点时间去配置一下`vim`, 具体配置方式请STFW. 总之, "编辑器之神"可不是浪得虚名的.

在Linux中也是存在不少更符合直觉（易于入门）的代码编辑器可供使用，比如`vscode`、`sublime`，甚至系统自带的笔记本工具因为有代码高亮功能也常常被实验室的学长拿来写python（完事以后吐槽还是pycharm好用）

虽然本人也是一个vim信仰用户（并不喜欢emacs那套操作），但在没有命令行的情况下还是更习惯于使用vscode

> 有个猜想不一定对，写这段的学长是FSF Supporter比较排斥那几个non-free的编辑器？
>
> 不管怎样，感觉给初学者灌输vim很nb的思想会导致知乎问题增多（大悲）

教程中间还介绍到一些gcc(gdb)、tmux工具，感觉太棒了

最后贴一下自己的vim配置罢，如果有需要的可以参考参考（这段应该不算教程代码）

```shell
call plug#begin('~/.vim/plugged')
"plug installation
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'w0rp/ale'
Plug 'neoclide/coc.nvim',{'branch':'release'}
Plug 'preservim/nerdtree'
Plug 'kien/ctrlp.vim'
Plug 'junegunn/fzf',{'dir':'~/.fzf','do':'./install --all'}
Plug 'junegunn/fzf.vim'
Plug 'Yggdroot/LeaderF',{'do':'./install.sh'}
Plug 'jiangmiao/auto-pairs'
Plug 'preservim/nerdcommenter'
call plug#end()

"plug settings

let g:coc_disable_startup_warning = 1

"ale settings
let g:ale_set_highlights=0

let g:ale_sign_error='❌'
let g:ale_sign_warning='⚠'
let g:ale_statusline_format=['❌ %','⚠ %d','√ OK']
let g:ale_echo_msg_error_str='E'
let g:ale_echo_msg_warning_srt='W'
let g:ale_echo_msg_format='[%linter%] %s [% severity %]'
let g:ale_lint_on_enter=0

let g:NERDTreeIndicatorMapCustom={
	\"Modified":"",
	\"Clean":"√",
	\"Dirty":"❌",
	\"Unknown":"?"
\}

"vim-airline settings
"set laststatus=2 "show status forever
"let g:airline_poweline_fonts=1
"let g:airline#extensions#tabline#enabled=1 "show window-tab and buffer

"nerdtree settings
autocmd bufenter * if(winnr("$")==1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
let g:NERDTreeDirArrowExpandable='→'
let g:NERDTreeDirArrowCollapsible='▼'
let NERDTreeAutoCenter=1
let NERDTreeShowLineNumbers=1
let NERDTreeShowHidden=1
let NERDTreeWinSize=40
let g:nerdtree_tabs_open_on_console_startup=1
let NERDTreeIgnore=['\.pyc','\~$','.swp']

"vim settings
colorscheme slate
syntax enable
syntax on
filetype on
filetype plugin on
filetype indent on

"encoding settings
set encoding=utf-8

"parameter settings
set sts=4
set shiftwidth=4
set backspace=2
set tabstop=4

"basic states settings
set autoindent
set autochdir
set smartindent
set cindent
set paste
set showmode
set ruler
set wrap
set foldenable
set foldmethod=syntax
set foldcolumn=0

"show line_number
"set nu
set number

"set relativenumber

"mouse setting
set mouse=a
set selection=exclusive
set selectmode=mouse,key

"highlight line
"set cursorline
"set cul

"highlight column
"set cursorcolumn
"set cuc

"show brackets
set showmatch
set matchtime=2

set hlsearch
set noerrorbells
set novisualbell
set t_vb=

set magic
```

## 搭建verilator仿真环境

通篇都在为读者灌输**RTFM**！

不看手册根本做不了这些东西（看了以后也不一定做的来，因为需要反复实验去理解）

这就是我作为iverilog初心者的唯一想法

之前没接触过c++写testbench（大伙都是v/sv，也没碰过soc验证，不会有人写c++罢（激寒）），于是在按老思路写tb的时候就四处碰壁。悲从中来想到RTFM，然后视野一下子打开力！

这段内容包括编译源码、使用双控开关测试程序、通过打印波形了解gtkwave（本人用的是vscode的*wavetrace*插件，在信号数量少的时候很好用）和接入nvboard来练习使用自己搭建的测试环境，中途还掺杂了不少Makefile私货，笔者从中学到了很多，最大的感触就是~~CMake果然好难（错乱）~~

值得一提的是笔者在编译verilator的时候首先用的是cygwin（只是因为懒得开linux），后来发现需要更改官方提供的shell script才能正常使用，于是就放弃了，希望以后能有其他更强的同学尝试为windows做一下移植罢，我还是比较胆小怕改坏东西影响后面进度的（

不过本人感觉比较不方便的就是整体要求sim内的git追踪代码保持完整——这样真的不会导致垃圾提交过多吗？虽然本人一直喜欢垃圾提交（从本Note的git log中就可以看出来，我平常写代码都是写多少提交多少，而且一般不去清理branch），但是感觉对于新手来说回溯版本要从一大堆垃圾代码中找到有用的版本太难受了（悲）——即使之前有提示可以手动控制提交和查看特定的git log。考虑到一生一芯要求原创作品的特殊性，这样严格的追踪倒容易理解，只是感觉会让萌新很狂躁（是的就是我）

> 笔者起初在官方Makefile上面大概特改的时候注释掉了代码追踪部分，等到双控开关全部测试ok以后再恢复的代码，结果发现就这一个commit很可能引起评审人员误会，于是决定之后就不再修改sim部分的代码追踪力
>
> 希望以后的git log不会出现一大坨（悲）

### verilator简介

以下内容均来自[官方文档](https://verilator.org/guide/latest/index.html)

Verilator是一个高性能的Verilog HDL模拟器（另外包含了lint系统），允许用户通过C++/SystemC对rtl进行验证，对应文件通过实例化用户顶层模块的“Verilate化”模型来让C程序能够调用rtl“程序”。工具会自动生成一系列C++/SystemC文件，这些文件由C++编译器（gcc/clang/MSVC++）进行编译，并通过最终生成的可执行文件执行设计模拟。

上面这一系列流程都可以用verilator自带的参数来解决

> Verilator does not simply convert Verilog HDL to C++ or SystemC. Rather, Verilator compiles your code into a much faster optimized and optionally thread-partitioned model, which is in turn wrapped inside a C++/SystemC module. The results are a compiled Verilog model that executes even on a single-thread over 10x faster than standalone SystemC, and on a single thread is about 100 times faster than interpreted Verilog simulators such as [Icarus Verilog](http://iverilog.icarus.com). Another 2-10x speedup might be gained from multithreading (yielding 200-1000x total over interpreted simulators).
>
> Verilator has typically similar or better performance versus the closed-source Verilog simulators (Carbon Design Systems Carbonator, Modelsim, Cadence Incisive/NC-Verilog, Synopsys VCS, VTOC, and Pragmatic CVer/CVC). But, Verilator is open-sourced, so you can spend on computes rather than licenses. Thus Verilator gives you the best cycles/dollar.
>
> Verilator不会简单地将Verilog HDL转换为C++或SystemC。Verilator可以将代码编译为速度优化的与可选的线程分区模型，这些模型封装在C++/SystemC/Python模块中。经过编译的Verilog模型，即使在单线程上执行的速度也比独立SystemC快10倍以上，并且在单线程上的执行速度比诸如Icarus Verilog之类的解释Verilog模拟器快100倍。多线程可能还会使速度提高2-10倍（在解释型模拟器上总共可以提高200-1000倍）
>
> Verilator与同型号闭源Verilog模拟器具有相似甚至更好的性能表现（比如M家、S家、C家和大多数商业EDA工具）。但Verilator是开源的，所以用户可以直接在电脑上安装而不用考虑许可证。因此Verilator可以为用户提供最佳性价比选项

### Verilator安装

通过github可以获取到源码

linux下面只要使用官网给出的指令安装好依赖工具即可；而在cygwin下需要先看好要使用哪些工具再提前安好

在linux下可以通过autoconfig-make工具链完成安装

```shell
cd <verilator-dir>
autoconf
./configure
make #或make -j使用多核编译
make install
```

需要注意：如果硬在windows下安装工具，需要准备一个cygwin环境——因为automake需要这个环境，而Verilator并不支持CMake

在cygwin安装后就可以直接通过windows下的make工具调用mingw-gcc进行构建

群内还有老哥提供了WSL内安装的方式，总体流程和linux类似，笔者配完后用vscode的wsl远程功能跑了一下，verilator是能够正常运行的；不过没有测试后面的nvboard等能否正常运行

安装成功是否可以用以下指令测试

```shell
verilator --version
```

官方提供了一个example

```verilog
module our;
initial begin 
    $display("Hello World"); 
    $finish; 
end
endmodule
```

```c++
#include "Vour.h"
#include "verilated.h"
int main(int argc, char** argv, char** env) 
{
	VerilatedContext* contextp = new VerilatedContext;
	contextp->commandArgs(argc, argv);
	Vour* top = new Vour{contextp};
      
    while (!contextp->gotFinish()) 
    { 
        top->eval(); 
    }
	delete top;
	delete contextp;
    return 0;
}
```

它可以在命令行上输出一个helloworld字符串

其中`top->eval(); `语句是为了在每个时钟周期获取对应的输出数据

`contextp`是一个专门用来设置仿真环境的指针

在使用c++编写testbench的时候，需要包含

```c++
// Include common routines
#include <verilated.h>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"
```

这两个头文件，其中Vtop.h是从verilog顶层封装文件中编译得到的，原文件名如果是a.v，那么得到的头文件应为Va.h；verilated.h文件则是verilator的头文件，包含了编写testbench所需的类封装

需要用到以下参数：

* -Wall：启用所有警告信息（Warning All）
* --cc：生成c++输出文件
* --exe：在目标程序有c/c++/systemc顶层封装（testbench）的时候输出一个可执行程序而不是c库文件。启用这个参数后verilator会生成一个Makefile
* --build：verilator会自动调用输出的Makefile完成编译

### 使用Make/CMake调用Verilator

Verilator支持make/cmake工具，make工具只需要按照shell script那样写脚本即可，CMake比较特殊：

```cmake
project(cmake_example)
find_package(verilator HINTS $ENV{VERILATOR_ROOT})
add_executable(Vour sim_main.cpp)
verilate(Vour SOURCES our.v)
```

上面是官网给出的示例，这里将verilator作为一个依赖包调入，并通过`verilate()`函数执行

函数内可以后缀各种参数，详情可以查看[官方文档对应页面](https://verilator.org/guide/latest/verilating.html#c-and-systemc-generation)

> 笔者在Makefile里面写了四个Target：
>
> * run：编译并输出
> * sim：用于输出gtkwave仿真文件
> * sim_nvboard：用于在nvboard上仿真
> * clean：用于清除之前的编译结果

### 使用Verilator生成仿真文件

使用`--trace`参数来让verilator输出仿真文件

需要注意：Verilator将rtl编译为C++对象，其端口编译为对象的属性，通过`->`运算符来调用

这段内容摘自官网的FAQ

> 不知为何这么重要的东西没有被写到正文里=-=
>
> 是我没看仔细吗（恼）

在c++的testbench里调用

```c++
#include "verilated_vcd_c.h"

VerilatedVcdC* tfp = new VerilatedVcdC; //初始化VCD对象指针
Verilated::traceEverOn(true); //打开追踪功能
tfp->open("testbench.vcd"); //设置输出的文件
```

然后就能使用

```c++
tfp->dump(contextp->time());
```

来记录当前的信号值到VCD文件中了

如果需要推进时间，可以使用

```c++
contextp->timeInc(1);
```

其中contextp是`VerilatedContext`指针，用于配置仿真文件的上下文

> 需要强调一下：Verilator的思路是把rtl文件当作一个可以执行的“函数”，通过把他抽象为对象来执行各种操作
>
> 在C++ testbench中的仿真并不是v/sv那样的并行化思路，而是串行的，所以每个时钟周期都需要调用timeInc()来推进时间轴

官方例程中使用了智能指针来管理内存，如下所示：

```c++
#include <memory>

const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext}; //智能指针，可以自动管理内存
const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};
```

例程中使用的参数为`-Wall -cc --exe -Os -x-assign 0 --assert --coverage --trace`

### Verilator优化

Verilator支持下面这些参数来对rtl进行优化编译

* O3：最优化编译结果，会导致编译rtl的时间变长
* --x-assign fast：优化rtl执行效率，可能会增加某些bug出现的风险
* --x-initial fast：优化rtl执行效率，可能会增加某些bug出现的风险
* --noassert：不启用断言功能

详细解释可以参考官方文档

使用`--coverage`可以让Verilator支持SystemVerilog中的*代码覆盖率分析*功能

如果不指定Ox参数，Verilator会默认使用Os，这只会让代码得到最基础的优化

### 其他常用Verilator参数

* --lint-only：使用verilator作为代码检查工具；如果使用该参数，verilator不会生成任何输出文件
* --sc：生成SystemC输出文件
* --xml-only：只生成xml文件，可以通过`--xml-output <filename>`参数指定生成的xml文件名。xml文件可用于提供给下级工具，从而跨工具链
* --assert：启用所有断言功能
