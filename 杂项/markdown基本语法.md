## 标题

使用 # 号可表示 1-6 级标题，一级标题对应一个 # 号，二级标题对应两个 # 号，以此类推。

```
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题
```

例：


# 你好

## 你好

### 你好

#### 你好

##### 你好

###### 你不好


## 字体

Markdown 可以使用以下几种字体：

```
*斜体*
_斜体_
**粗体**
__粗体__
***粗斜体***
___粗斜体___
```

为了方便可以统一记为\*是强调符号，一对为斜体，两对为更加强调的粗体，三对是非常强调的粗斜体

例：
*苍茫的天涯是我的爱*
_月亮之上_
**无他，唯手熟耳**
__1d100=100【大失败】__
***提桶跑路***
___讲个笑话，钓鱼佬今天没空军___

## 高亮强调

用四个等于号=包围需要强调的内容即可实现

```
==独轮车 tskk 独轮车==
```

例：

==独轮车 tskk 独轮车==


## 分割线
用三个或以上*号单独成行表示分割线
```
***
```
例：

***
下面是【数据删除】个星号*写的，猜猜有什么特殊的地方？
********************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************
显然 用很多*写出分割线可以在代码层面增加你文章的气势，具体原因留给读者自行证明


## 上标与下标
用两个^表示上标
用两个~表示下标
```
1919^114514^
 今天~也是好天气~
```
例：
1919^114514^
今天~也是好天气~

## 注释
用
```
<!--注释内容-->
```
表示注释
例：
<!--肖战必糊-->
虽然什么也没有显示
但这里确实有注释，我也并没有在注释里骂人

## 列表

Markdown 支持有序列表和无序列表。

无序列表使用星号(\*)、加号(+)或是减号(-)作为列表标记，这些标记后面要添加一个空格，然后再填写内容：

```
* 第一项
* 第二项
* 第三项

+ 第一项
+ 第二项
+ 第三项


- 第一项
- 第二项
- 第三项
```
例：

* 第一项
+ 第二项
- 第三项


为了记忆简单，可统一记为\*后面接空格意味着一个无序列表项

****

有序列表使用数字并加上 . 号来表示，如：

```
1. 第一项
2. 第二项
3. 第三项
```
例：
1. amdyes!
2. nvidia!fxxkyou!
3. intel还在做cpu？

## 区块

Markdown 区块引用是在段落开头使用 > 符号 ，然后后面紧跟一个**空格**符号：

```
> 区块引用
> 衬衫的价格是9镑15便士
> 下面你将听到
```

另外区块是可以嵌套的，一个 > 符号是最外层，两个 > 符号是第一层嵌套，以此类推：

```
> 最外层
>> 第一层嵌套
>>> 第二层嵌套
```

### 列表中使用区块

如果要在列表项目内放进区块，那么就需要在 > 前添加四个空格的缩进

例：

```
* 第一项
    > 传统markdown要讲码德
    > 在这里劝这位年轻码农耗子尾汁
* 第二项
	> 芜湖
	> > 起飞 <!--中间加不加空格都行-->
	>>> 飞飞飞
```

* 第一项
    > 传统markdown要讲码德
    > 在这里劝这位年轻码农耗子尾汁
* 第二项
	> 芜湖
	> > 起飞<!--中间加不加空格都行-->
	> > are u good 马来西亚
	> >
	> > > 飞飞飞

## 代码

如果是段落上的一个函数或片段的代码可以用反引号把它包起来（`），例如：

```
`printf()` 函数
```

### 代码区块

代码区块使用 **4 个空格**或者一个**制表符（Tab 键）**。

也可以用 ```包裹一段代码，并指定一种语言（也可以不指定）：

在大多数Markdown编辑器中，\`\`\`旁边可以加语言名字添加对应的语法高亮

```
```javascript
$(document).ready(function () {
    alert('RUNOOB');
});
​```
```

## 链接

链接使用方法如下：

```
[链接名称](链接地址)

或者

<链接地址>
```

例如：

```
 哦我的老伙计，瞧瞧这条链接
  [感谢菜鸟教程提供部分资料（其实是大部分）](https://www.runoob.com)
 或<https://wosuibianzhaogewangzhan.com>
```
[感谢菜鸟教程提供部分资料（其实是大部分）](https://www.runoob.com)

或<https://wosuibianzhaogewangzhan.com>

### 高级链接

可以通过变量来设置一个链接，变量赋值在文档末尾进行：

```
用 1 作为网址变量 [pxxnhub][1]
用 rua 作为网址变量 [Rua][rua]
然后在文档的结尾为变量赋值（网址）

  [1]: http://www.pornhub.com/
  [rua]: https://space.bilibili.com/15810
```

[pxxnhub][1]
[Rua][rua]

[1]: http://www.pornhub.com/
[rua]: https://space.bilibili.com/15810
## 图片

Markdown 图片语法格式如下：

```
![介写了个嘛玩意](我也不知道该放什么，瞎写吧)
```

- 开头一个感叹号 !
- 接着一个方括号，里面放上图片的替代文字
- 接着一个普通括号，里面放上图片的网址，最后还可以用引号包住并加上选择性的 'title' 属性的文字。

//抱歉没有例子，奇怪的图片发出来的话，人生就要结束了（悲）

Markdown 还没有办法指定图片的高度与宽度，如果需要的话，可以使用普通的 \<img\> 标签。

```
<img src="原文这里是runoob的一张图" width="50%">
```

## 表格

Markdown 制作表格使用 | 来分隔不同的单元格，使用 - 来分隔表头和其他行。

语法格式如下：

```
|  表头   | 表头  |
|  ----  | ----  |
| 单元格  | 单元格 |
| 单元格  | 单元格 |
```

### 对齐方式

**我们可以设置表格的对齐方式：**

* -: 设置内容和标题栏居右对齐。
* :- 设置内容和标题栏居左对齐。
* :-: 设置内容和标题栏居中对齐。
例：

```
| 左对齐 | 右对齐 | 居中对齐 |
| :-----| ----: | :----: |
| 单元格 | 单元格 | 单元格 |
| 单元格 | 单元格 | 单元格 |
```

| 左对齐 | 右对齐 | 居中对齐 |
| :-----| ----: | :----: |
| 单元格 | 单元格 | 单元格 |
| 单元格 | 单元格 | 单元格 |


## HTML 元素

不在 Markdown 涵盖范围之内的标签，都可以直接在文档里面用 HTML 撰写。

目前支持的 HTML 元素有：`<kbd> <b> <i> <em> <sup> <sub> <br>`等 ，如：

```
使用 <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Del</kbd> 重启电脑
```
使用 <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Del</kbd> 重启电脑

## 转义

Markdown 使用了很多特殊符号来表示特定的意义，如果需要显示特定的符号则需要使用转义字符，Markdown 使用反斜杠转义特殊字符：

```
**文本加粗** 
\*\* 正常显示星号 \*\*
```

Markdown 支持以下这些符号前面加上反斜杠来帮助插入普通的符号：

```
\   反斜线
`   反引号
*   星号
_   下划线
{}  花括号
[]  方括号
()  小括号
#   井字号
+   加号
-   减号
.   英文句点
!   感叹号
```

## 公式

当你需要在编辑器中插入数学公式时，可以使用两个美元符 $$ 包裹 TeX 或 LaTeX 格式的数学公式来实现。提交后，问答和文章页会根据需要加载 Mathjax 对数学公式进行渲染。

不过这个东西和渲染器有关，对于不同编辑器可能会不支持某些latex特性


如：

```
$$
思考题：\lim_{x\rarr 0}\frac{tanx}{x+sinx} =?
$$

$$
\frac{dx}{dt}=v
\mathbf{V}_1 \times \mathbf{V}_2
$$
```

$$
思考题：\lim_{x\rarr 0}\frac{tanx}{x+sinx} =?
$$

$$
\frac{dx}{dt}=v
\mathbf{V}_1 \times \mathbf{V}_2
$$

## 非常感谢菜鸟教程runoob.com提供了好多代码，本人也是在这学的markdown
 链接如下：

[菜鸟教程](https://www.runoob.com)
 十分适合新手学习各种语言和开发技巧，虽然讲解思路比较跳跃，但胜在详细