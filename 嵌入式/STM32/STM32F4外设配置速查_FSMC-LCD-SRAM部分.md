# TFTLCD

TDTLCD即薄膜晶体管液晶显示器，在液晶显示屏每个像素上都设置有一个薄膜晶体管（TFT），图像质量高

一般TFTLCD模块位3.3V供电，不支持5V电压MCU，如果使用5V MCU需在信号线串接120R电阻使用

LCD使用16位80并口驱动，与OLED并口驱动类似

电容触摸模块使用SPI串口驱动

采用厂商提供配置文件或参考数据手册即可完成LCD和触摸屏的驱动配置

## LCD驱动流程

1. 硬复位
2. 发送初始化序列（按照厂家提供设置）
3. 设置坐标
4. 写点或读点
5. 写点步骤：
   1. 写GRAM指令
   2. 写入颜色数据
   3. LCD显示点
6. 读点步骤
   1. 读GRAM指令
   2. 读出颜色数据
   3. 输出数据给单片机处理

## RGB565格式

LCD模块对外采用16位80并口，颜色深度为16为，格式为RGB565

对应关系如下：5位R、6位G、5位B——RGB565

| 数据线   | D15  | D14  | D13  | D12  | D11  | D10  | D9   | D8   | D7   | D6   | D5   | D4   | D3   | D2   | D1   | D0   |
| -------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| LCD GRAM | R[4] | R[3] | R[2] | R[1] | R[0] | G[5] | G[4] | G[3] | G[2] | G[1] | G[0] | B[4] | B[3] | B[2] | B[1] | B[0] |

## 重点代码

font.h

```c
//这里省略
//可利用字符点阵画图软件或已有字库导出对应字符的点阵集
//应#include到lcd.c文件中
```

lcd.h

```c
#ifndef __LCD_H
#define __LCD_H		
#include "sys.h"	 
#include "stdlib.h"

/*-----------------LCD重要参数集定义----------------*/
typedef struct
{										    
	u16 width;			//LCD 宽度
	u16 height;			//LCD 高度
	u16 id;				//LCD ID
	u8  dir;			//横屏还是竖屏控制：0，竖屏；1，横屏	
	u16	wramcmd;		//开始写gram指令
	u16  setxcmd;		//设置x坐标指令
	u16  setycmd;		//设置y坐标指令 
}_lcd_dev; 	  

//LCD参数
extern _lcd_dev lcddev;//管理LCD重要参数
extern u16  POINT_COLOR;//画笔颜色，默认红色    
extern u16  BACK_COLOR;//背景颜色.默认为白色
/*-----------------LCD重要参数集定义----------------*/
/*-----------------LCD端口定义----------------*/
#define	LCD_LED PBout(15)  		//LCD背光 PB15
/*-----------------LCD端口定义----------------*/
/*-----------------LCD地址定义----------------*/
//LCD地址结构体
typedef struct
{
	vu16 LCD_REG;
	vu16 LCD_RAM;
} LCD_TypeDef;
//使用NOR/SRAM的 Bank1.sector4,地址位HADDR[27,26]=11 A6作为数据命令区分线 
//注意设置时STM32内部会右移一位对其! 111 1110=0X7E			    
#define LCD_BASE        ((u32)(0x6C000000|0x0000007E))
//Bank1Sector4基地址为0x6C000000，A10的偏移地址为0x000007EF
#define LCD             ((LCD_TypeDef *) LCD_BASE)
//将上述地址强制转换为LCD地址结构体指针，即得到LCD->LCD_REG的地址，实现对RS的控制
/*-----------------LCD地址定义----------------*/

//扫描方向定义
#define L2R_U2D  0 //从左到右,从上到下
#define L2R_D2U  1 //从左到右,从下到上
#define R2L_U2D  2 //从右到左,从上到下
#define R2L_D2U  3 //从右到左,从下到上
#define U2D_L2R  4 //从上到下,从左到右
#define U2D_R2L  5 //从上到下,从右到左
#define D2U_L2R  6 //从下到上,从左到右
#define D2U_R2L  7 //从下到上,从右到左
#define DFT_SCAN_DIR L2R_U2D//默认的扫描方向

//画笔颜色
#define WHITE         	 0xFFFF
#define BLACK         	 0x0000	  
#define BLUE         	 0x001F  
#define BRED             0XF81F
#define GRED 			 0XFFE0
#define GBLUE			 0X07FF
#define RED           	 0xF800
#define MAGENTA       	 0xF81F
#define GREEN         	 0x07E0
#define CYAN          	 0x7FFF
#define YELLOW        	 0xFFE0
#define BROWN 			 0XBC40 //棕色
#define BRRED 			 0XFC07 //棕红色
#define GRAY  			 0X8430 //灰色
//GUI颜色
#define DARKBLUE      	 0X01CF	//深蓝色
#define LIGHTBLUE      	 0X7D7C	//浅蓝色  
#define GRAYBLUE       	 0X5458 //灰蓝色
//以上三色为PANEL的颜色 
#define LIGHTGREEN     	 0X841F //浅绿色
//#define LIGHTGRAY        0XEF5B //浅灰色(PANNEL)
#define LGRAY 			 0XC618 //浅灰色(PANNEL),窗体背景色
#define LGRAYBLUE        0XA651 //浅灰蓝色(中间层颜色)
#define LBBLUE           0X2B12 //浅棕蓝色(选择条目的反色)
	    															  
void LCD_Init(void);													   	//初始化LCD
void LCD_DisplayOn(void);													//开显示
void LCD_DisplayOff(void);													//关显示
void LCD_Clear(u16 Color);	 												//清屏
void LCD_SetCursor(u16 Xpos, u16 Ypos);										//设置光标
void LCD_DrawPoint(u16 x,u16 y);											//画点
void LCD_Fast_DrawPoint(u16 x,u16 y,u16 color);								//快速画点
u16  LCD_ReadPoint(u16 x,u16 y); 											//读点 
void LCD_Draw_Circle(u16 x0,u16 y0,u8 r);						 			//画圆
void LCD_DrawLine(u16 x1, u16 y1, u16 x2, u16 y2);							//画线
void LCD_DrawRectangle(u16 x1, u16 y1, u16 x2, u16 y2);		   				//画矩形
void LCD_Fill(u16 sx,u16 sy,u16 ex,u16 ey,u16 color);		   				//填充单色
void LCD_Color_Fill(u16 sx,u16 sy,u16 ex,u16 ey,u16 *color);				//填充指定颜色
void LCD_ShowChar(u16 x,u16 y,u8 num,u8 size,u8 mode);						//显示一个字符
void LCD_ShowNum(u16 x,u16 y,u32 num,u8 len,u8 size);  						//显示一个数字
void LCD_ShowxNum(u16 x,u16 y,u32 num,u8 len,u8 size,u8 mode);				//显示 数字
void LCD_ShowString(u16 x,u16 y,u16 width,u16 height,u8 size,u8 *p);		//显示一个字符串,可用12/16字体

void LCD_WriteReg(u16 LCD_Reg, u16 LCD_RegValue);
u16 LCD_ReadReg(u16 LCD_Reg);
void LCD_WriteRAM_Prepare(void);
void LCD_WriteRAM(u16 RGB_Code);

void LCD_SSD_BackLightSet(u8 pwm);							//SSD1963 背光控制
void LCD_Scan_Dir(u8 dir);									//设置屏扫描方向
void LCD_Display_Dir(u8 dir);								//设置屏幕显示方向
void LCD_Set_Window(u16 sx,u16 sy,u16 width,u16 height);	//设置窗口					   						   																			 
//LCD分辨率设置参数
#define SSD_HOR_RESOLUTION		800		//LCD水平分辨率
#define SSD_VER_RESOLUTION		480		//LCD垂直分辨率
//LCD驱动设置参数
#define SSD_HOR_PULSE_WIDTH		1		//水平脉宽
#define SSD_HOR_BACK_PORCH		46		//水平前廊
#define SSD_HOR_FRONT_PORCH		210		//水平后廊
#define SSD_VER_PULSE_WIDTH		1		//垂直脉宽
#define SSD_VER_BACK_PORCH		23		//垂直前廊
#define SSD_VER_FRONT_PORCH		22		//垂直前廊
//如下几个参数，自动计算
#define SSD_HT	(SSD_HOR_RESOLUTION+SSD_HOR_BACK_PORCH+SSD_HOR_FRONT_PORCH)
#define SSD_HPS	(SSD_HOR_BACK_PORCH)
#define SSD_VT 	(SSD_VER_RESOLUTION+SSD_VER_BACK_PORCH+SSD_VER_FRONT_PORCH)
#define SSD_VPS (SSD_VER_BACK_PORCH)

#endif
```

lcd.c

这里仅写了显示函数（读写数据函数），LCD控制函数参考正点原子示例文档

```c
u16 POINT_COLOR=0x0000;//画笔颜色
u16 BACK_COLOR=0xFFFF;//背景色 
//默认为竖屏
_lcd_dev lcddev;

//写寄存器函数
//regval:寄存器值
void LCD_WR_REG(vu16 regval)
{   
	regval=regval;//使用-O2优化的时候,必须插入的延时
	LCD->LCD_REG=regval;//写入要写的寄存器序号	 
}
//写LCD数据
//data:要写入的值
void LCD_WR_DATA(vu16 data)
{	 
	data=data;//使用-O2优化的时候,必须插入的延时
	LCD->LCD_RAM=data;		 
}
//读LCD数据
//返回值:读到的值
u16 LCD_RD_DATA(void)
{
	vu16 ram;//防止被优化
	ram=LCD->LCD_RAM;	
	return ram;	 
}					   
//写寄存器
//LCD_Reg:寄存器地址
//LCD_RegValue:要写入的数据
void LCD_WriteReg(u16 LCD_Reg,u16 LCD_RegValue)
{	
	LCD->LCD_REG=LCD_Reg;//写入要写的寄存器序号	 
	LCD->LCD_RAM=LCD_RegValue;//写入数据	    		 
}	   
//读寄存器
//LCD_Reg:寄存器地址
//返回值:读到的数据
u16 LCD_ReadReg(u16 LCD_Reg)
{										   
	LCD_WR_REG(LCD_Reg);//写入要读的寄存器序号
	delay_us(5);		  
	return LCD_RD_DATA();//返回读到的值
}   
//开始写GRAM
void LCD_WriteRAM_Prepare(void)
{
 	LCD->LCD_REG=lcddev.wramcmd;	  
}
//LCD写GRAM
//RGB_Code:颜色值
void LCD_WriteRAM(u16 RGB_Code)
{							    
	LCD->LCD_RAM = RGB_Code;//写十六位GRAM
}
//从ILI93xx读出的数据为GBR格式，而我们写入的时候为RGB格式。
//通过该函数转换
//c:GBR格式的颜色值
//返回值：RGB格式的颜色值
u16 LCD_BGR2RGB(u16 c)
{
	u16  r,g,b,rgb;   
	b=(c>>0)&0x1f;
	g=(c>>5)&0x3f;
	r=(c>>11)&0x1f;	 
	rgb=(b<<11)+(g<<5)+(r<<0);		 
	return(rgb);
}
//当mdk -O1时间优化时需要设置
//延时i
void opt_delay(u8 i)
{
	while(i--);
}
//读取个某点的颜色值
//x,y:坐标
//返回值:此点的颜色
u16 LCD_ReadPoint(u16 x,u16 y)
{
 	u16 r=0,g=0,b=0;
	if(x>=lcddev.width||y>=lcddev.height)return 0;//超过了范围,直接返回		   
	LCD_SetCursor(x,y);	    
	if(lcddev.id==0X9341||lcddev.id==0X6804||lcddev.id==0X5310||lcddev.id==0X1963)LCD_WR_REG(0X2E);//9341/6804/3510/1963 发送读GRAM指令
	else if(lcddev.id==0X5510)LCD_WR_REG(0X2E00);	//5510 发送读GRAM指令
	else LCD_WR_REG(0X22);      		 			//其他IC发送读GRAM指令
	if(lcddev.id==0X9320)opt_delay(2);				//FOR 9320,延时2us	    
 	r=LCD_RD_DATA();								//dummy Read	   
	if(lcddev.id==0X1963)return r;					//1963直接读就可以 
	opt_delay(2);	  
 	r=LCD_RD_DATA();  		  						//实际坐标颜色
 	if(lcddev.id==0X9341||lcddev.id==0X5310||lcddev.id==0X5510)//9341/NT35310/NT35510要分2次读出
 	{
		opt_delay(2);	  
		b=LCD_RD_DATA(); 
		g=r&0XFF;//对于9341/5310/5510,第一次读取的是RG的值,R在前,G在后,各占8位
		g<<=8;
	} 
	if(lcddev.id==0X9325||lcddev.id==0X4535||lcddev.id==0X4531||lcddev.id==0XB505||lcddev.id==0XC505)
        return r;//这几种IC直接返回颜色值
	else if(lcddev.id==0X9341||lcddev.id==0X5310||lcddev.id==0X5510)
        return (((r>>11)<<11)|((g>>10)<<5)|(b>>11));//ILI9341/NT35310/NT35510需要公式转换一下
	else 
        return LCD_BGR2RGB(r);						//其他IC
}

//LCD开启显示
void LCD_DisplayOn(void)
{					   
	if(lcddev.id==0X9341||lcddev.id==0X6804||lcddev.id==0X5310||lcddev.id==0X1963)
        LCD_WR_REG(0X29);//开启显示
	else if(lcddev.id==0X5510)
        LCD_WR_REG(0X2900);//开启显示
	else
        LCD_WriteReg(0X07,0x0173);//开启显示
}
//LCD关闭显示
void LCD_DisplayOff(void)
{	   
	if(lcddev.id==0X9341||lcddev.id==0X6804||lcddev.id==0X5310||lcddev.id==0X1963)
        LCD_WR_REG(0X28);//关闭显示
	else if(lcddev.id==0X5510)
        LCD_WR_REG(0X2800);//关闭显示
	else
        LCD_WriteReg(0X07,0x0);//关闭显示 
}

//画点
//x,y:坐标
//POINT_COLOR:此点的颜色
void LCD_DrawPoint(u16 x,u16 y)
{
	LCD_SetCursor(x,y);//设置光标位置 
	LCD_WriteRAM_Prepare();//开始写入GRAM
	LCD->LCD_RAM=POINT_COLOR; 
}
//快速画点
//x,y:坐标
//color:颜色
void LCD_Fast_DrawPoint(u16 x,u16 y,u16 color)
{	   
	if(lcddev.id==0X9341||lcddev.id==0X5310)
	{
		LCD_WR_REG(lcddev.setxcmd); 
		LCD_WR_DATA(x>>8);
        LCD_WR_DATA(x&0XFF);  			 
		LCD_WR_REG(lcddev.setycmd); 
		LCD_WR_DATA(y>>8);
        LCD_WR_DATA(y&0XFF); 		 	 
	}
    else if(lcddev.id==0X5510)
	{
		LCD_WR_REG(lcddev.setxcmd);
        LCD_WR_DATA(x>>8);  
		LCD_WR_REG(lcddev.setxcmd+1);
        LCD_WR_DATA(x&0XFF);	  
		LCD_WR_REG(lcddev.setycmd);
        LCD_WR_DATA(y>>8);  
		LCD_WR_REG(lcddev.setycmd+1);
        LCD_WR_DATA(y&0XFF); 
	}
    else if(lcddev.id==0X1963)
	{
		if(lcddev.dir==0)
            x=lcddev.width-1-x;
		LCD_WR_REG(lcddev.setxcmd); 
		LCD_WR_DATA(x>>8);
        LCD_WR_DATA(x&0XFF); 		
		LCD_WR_DATA(x>>8);
        LCD_WR_DATA(x&0XFF); 		
		LCD_WR_REG(lcddev.setycmd); 
		LCD_WR_DATA(y>>8);
        LCD_WR_DATA(y&0XFF); 		
		LCD_WR_DATA(y>>8);
        LCD_WR_DATA(y&0XFF); 		
	}
    else if(lcddev.id==0X6804)
	{		    
		if(lcddev.dir==1)
            x=lcddev.width-1-x;//横屏时处理
		LCD_WR_REG(lcddev.setxcmd); 
		LCD_WR_DATA(x>>8);
        LCD_WR_DATA(x&0XFF);			 
		LCD_WR_REG(lcddev.setycmd); 
		LCD_WR_DATA(y>>8);
        LCD_WR_DATA(y&0XFF); 		
	}
    else
	{
 		if(lcddev.dir==1)
            x=lcddev.width-1-x;//横屏其实就是调转x,y坐标
		LCD_WriteReg(lcddev.setxcmd,x);
		LCD_WriteReg(lcddev.setycmd,y);
	}			 
	LCD->LCD_REG=lcddev.wramcmd; 
	LCD->LCD_RAM=color; 
}

//清屏函数
//color:要清屏的填充色
void LCD_Clear(u16 color)
{
	u32 index=0;      
	u32 totalpoint=lcddev.width;
	totalpoint*=lcddev.height;//得到总点数
	if((lcddev.id==0X6804)&&(lcddev.dir==1))//6804横屏的时候特殊处理  
	{						    
 		lcddev.dir=0;	 
 		lcddev.setxcmd=0X2A;
		lcddev.setycmd=0X2B;  	 			
		LCD_SetCursor(0x00,0x0000);//设置光标位置为初始位置
 		lcddev.dir=1;
  		lcddev.setxcmd=0X2B;
		lcddev.setycmd=0X2A;  	 
 	}
    else
        LCD_SetCursor(0x00,0x0000);//设置光标位置
    
	LCD_WriteRAM_Prepare();//开始写入GRAM	 	  
	for(index=0;index<totalpoint;index++)
	{
		LCD->LCD_RAM=color;	
	}
}

//在指定位置显示一个字符
//x,y:起始坐标
//num:要显示的字符:" "--->"~"
//size:字体大小 12/16/24
//mode:叠加方式(1)还是非叠加方式(0)
void LCD_ShowChar(u16 x,u16 y,u8 num,u8 size,u8 mode)
{  							  
    u8 temp,t1,t;
	u16 y0=y;
	u8 csize=(size/8+((size%8)?1:0))*(size/2);//得到字体一个字符对应点阵集所占的字节数	
 	num=num-' ';//得到偏移后的值（ASCII字库是从空格开始取模，所以-' '就是对应字符的字库）
    
	for(t=0;t<csize;t++)
	{   
		if(size==12)
            temp=asc2_1206[num][t];//调用1206字体
		else if(size==16)
            temp=asc2_1608[num][t];//调用1608字体
		else if(size==24)
            temp=asc2_2412[num][t];//调用2412字体
		else
            return;//没有的字库
        
		for(t1=0;t1<8;t1++)
		{			    
			if(temp&0x80)LCD_Fast_DrawPoint(x,y,POINT_COLOR);
			else if(mode==0)LCD_Fast_DrawPoint(x,y,BACK_COLOR);
			temp<<=1;
			y++;
			if(y>=lcddev.height)
                return;//超区域了
			if((y-y0)==size)
			{
				y=y0;
				x++;
				if(x>=lcddev.width)
                    return;//超区域了
				break;
			}
		}  	 
	}  	    	   	 	  
}   

//显示数字,高位为0,还是显示
//x,y:起点坐标
//num:数值(0~999999999);	 
//len:长度(即要显示的位数)
//size:字体大小
//mode:
//[7]:0,不填充;1,填充0.
//[6:1]:保留
//[0]:0,非叠加显示;1,叠加显示.
void LCD_ShowxNum(u16 x,u16 y,u32 num,u8 len,u8 size,u8 mode)
{  
	u8 t,temp;
	u8 enshow=0;						   
	for(t=0;t<len;t++)
	{
		temp=(num/LCD_Pow(10,len-t-1))%10;
        
		if(enshow==0&&t<(len-1))
		{
			if(temp==0)
			{
				if(mode&0X80)
                    LCD_ShowChar(x+(size/2)*t,y,'0',size,mode&0X01);  
				else
                    LCD_ShowChar(x+(size/2)*t,y,' ',size,mode&0X01);  
 				continue;
			}
            else
                enshow=1;
		}
	 	LCD_ShowChar(x+(size/2)*t,y,temp+'0',size,mode&0X01); 
	}
}

//显示字符串
//x,y:起点坐标
//width,height:区域大小  
//size:字体大小
//*p:字符串起始地址		  
void LCD_ShowString(u16 x,u16 y,u16 width,u16 height,u8 size,u8 *p)
{         
	u8 x0=x;
	width+=x;
	height+=y;
    while((*p<='~')&&(*p>=' '))//判断是不是非法字符!
    {       
        if(x>=width)
        {
            x=x0;
            y+=size;
        }
        
        if(y>=height)
            break;//退出
        
        LCD_ShowChar(x,y,*p,size,0);
        x+=size/2;
        p++;
    }
}
```

lcd.c

这里用伪代码说明LCD初始化函数内容，详细内容见例程

```c
//LCD初始化函数
void LCD_init(void)
{
    vu32 i=0;

	GPIO_InitTypeDef GPIO_InitStructure;
	FSMC_NORSRAMInitTypeDef FSMC_NORSRAMInitStructure;
	FSMC_NORSRAMTimingInitTypeDef readWriteTiming; 
	FSMC_NORSRAMTimingInitTypeDef writeTiming;
    
    /*初始化GPIO和FSMC*/

    //使能PD,PE,PF,PG和FSMC时钟
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB|
                           RCC_AHB1Periph_GPIOD|
                           RCC_AHB1Periph_GPIOE|
                           RCC_AHB1Periph_GPIOF|
                           RCC_AHB1Periph_GPIOG, ENABLE); 
	RCC_AHB3PeriphClockCmd(RCC_AHB3Periph_FSMC,ENABLE);

	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_15;//PB15 推挽输出,控制背光
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;//普通输出
	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;//100MHz
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用设置
	GPIO_Init(GPIOB, &GPIO_InitStructure);
	GPIO_InitStructure.GPIO_Pin = (3<<0)|(3<<4)|(7<<8)|(3<<14);//PD0,1,4,5,8,9,10,14,15复用输出
    //应用设置
	GPIO_Init(GPIOD, &GPIO_InitStructure);  
	GPIO_InitStructure.GPIO_Pin = (0X1FF<<7);//PE7~15复用输出
    //应用设置
	GPIO_Init(GPIOE, &GPIO_InitStructure); 
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_12;//PF12,FSMC_A6
    //应用设置
	GPIO_Init(GPIOF, &GPIO_InitStructure);  
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_12;//PF12,FSMC_A6
    //应用设置
	GPIO_Init(GPIOG, &GPIO_InitStructure); 

    /*设置引脚复用*/
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource0,GPIO_AF_FSMC);//PD0,AF12
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource1,GPIO_AF_FSMC);//PD1,AF12
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource4,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource5,GPIO_AF_FSMC); 
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource8,GPIO_AF_FSMC); 
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource9,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource10,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource14,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource15,GPIO_AF_FSMC);//PD15,AF12

	GPIO_PinAFConfig(GPIOE,GPIO_PinSource7,GPIO_AF_FSMC);//PE7,AF12
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource8,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource9,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource10,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource11,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource12,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource13,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource14,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource15,GPIO_AF_FSMC);//PE15,AF12

	GPIO_PinAFConfig(GPIOF,GPIO_PinSource12,GPIO_AF_FSMC);//PF12,AF12
	GPIO_PinAFConfig(GPIOG,GPIO_PinSource12,GPIO_AF_FSMC);

    /*读写时序初始化*/
	readWriteTiming.FSMC_AddressSetupTime=0XF;//地址建立时间（ADDSET）为16个HCLK 1/168M=6ns*16=96ns
	readWriteTiming.FSMC_AddressHoldTime=0x00;//地址保持时间（ADDHLD）模式A未用到	
	readWriteTiming.FSMC_DataSetupTime=60;//数据保存时间为60个HCLK=6*60=360ns
	readWriteTiming.FSMC_BusTurnAroundDuration=0x00;
	readWriteTiming.FSMC_CLKDivision=0x00;
	readWriteTiming.FSMC_DataLatency=0x00;
	readWriteTiming.FSMC_AccessMode=FSMC_AccessMode_A;//模式A
    /*写时序初始化*/
	writeTiming.FSMC_AddressSetupTime =9;//地址建立时间（ADDSET）为9个HCLK =54ns 
	writeTiming.FSMC_AddressHoldTime = 0x00;//地址保持时间（A		
	writeTiming.FSMC_DataSetupTime = 8;//数据保存时间为6ns*9个HCLK=54ns
	writeTiming.FSMC_BusTurnAroundDuration = 0x00;
	writeTiming.FSMC_CLKDivision = 0x00;
	writeTiming.FSMC_DataLatency = 0x00;
	writeTiming.FSMC_AccessMode = FSMC_AccessMode_A;//模式A 

	FSMC_NORSRAMInitStructure.FSMC_Bank=FSMC_Bank1_NORSRAM4;//NE4对应BTCR[6],[7]
	FSMC_NORSRAMInitStructure.FSMC_DataAddressMux=FSMC_DataAddressMux_Disable;//不使用数据地址复用
	FSMC_NORSRAMInitStructure.FSMC_MemoryType=FSMC_MemoryType_SRAM;//外部SRAM操作
	FSMC_NORSRAMInitStructure.FSMC_MemoryDataWidth=FSMC_MemoryDataWidth_16b;//存储器数据宽度为16位
	FSMC_NORSRAMInitStructure.FSMC_BurstAccessMode=FSMC_BurstAccessMode_Disable;//不使用突发访问模式
	FSMC_NORSRAMInitStructure.FSMC_WaitSignalPolarity=FSMC_WaitSignalPolarity_Low;
	FSMC_NORSRAMInitStructure.FSMC_AsynchronousWait=FSMC_AsynchronousWait_Disable;
	FSMC_NORSRAMInitStructure.FSMC_WrapMode=FSMC_WrapMode_Disable;
	FSMC_NORSRAMInitStructure.FSMC_WaitSignalActive=FSMC_WaitSignalActive_BeforeWaitState;
	FSMC_NORSRAMInitStructure.FSMC_WriteOperation=FSMC_WriteOperation_Enable;//存储器写使能
	FSMC_NORSRAMInitStructure.FSMC_WaitSignal=FSMC_WaitSignal_Disable;
	FSMC_NORSRAMInitStructure.FSMC_ExtendedMode=FSMC_ExtendedMode_Enable;//读写使用不同时序
	FSMC_NORSRAMInitStructure.FSMC_WriteBurst=FSMC_WriteBurst_Disable;
	FSMC_NORSRAMInitStructure.FSMC_ReadWriteTimingStruct=&readWriteTiming;//读写时序生效
	FSMC_NORSRAMInitStructure.FSMC_WriteTimingStruct=&writeTiming;//写时序生效
	//应用设置
	FSMC_NORSRAMInit(&FSMC_NORSRAMInitStructure);

	FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM4, ENABLE);//使能BANK1 
	
    /*读取LCD ID并进行核验*/
 	delay_ms(50);
 	LCD_WriteReg(0x0000,0x0001);
	delay_ms(50);
  	lcddev.id=LCD_ReadReg(0x0000);   

    printf("LCD ID:%x\r\n",lcddev,id);//在串口1打印LCD ID
    
根据不同ID执行不同的LCD初始化代码;//全都是if...else if... else if...else...
    
    LCD_Display_Dir(0);//默认为竖屏
	LCD_LED=1;//点亮背光
	LCD_Clear(WHITE);//清屏，准备显示
}
```

## 特殊情况：使用GPIO连接LCD

在不使用FSMC的情况下，可以使用GPIO模拟FSMC读取/写入GRAM

直接操作GPIO会占用CPU且速度较慢，但可作为替代方式

# FSMC

FSMC(Flexible Static Memory Controller)即“灵活的静态存储控制器”，能够与同步/异步存储器和16位PC存储器卡连接，STM32的FSMC接口支持SRAM、NANDFLASH、NORFLASH、PSRAM等存储器，**对f407来说不支持SDRAM**，由HCLK直接提供时钟，能够设置FSMC中断

FSMC驱动外部SRAM时，一般通过地址线（A0\~A25）、数据线（D0\~D15）、写信号（WE/WR）、读信号（OD/RD）、片选信号（CS）、UB/LB信号（仅支持字节控制的SRAM可使用）进行控制

## FSMC控制TFTLCD

将LCD的GRAM看作外部SRAM即可使用FSMC控制LCD

TFTLCD通过RS信号决定传输的数据是数据还是命令，即可把LCD映射为一个具有2个地址的SRAM，向其中存入数据就等效为向LCD发送指令或发送数据

## FSMC外设接口

stm32f4的FSMC支持8/16/32位数据宽度，自动将外部存储器划分为固定大小为256M字节的四个存储块

如下所示

| 地址       | 存储块 | 支持的存储器类型 |
| ---------- | ------ | ---------------- |
| 6000 0000H | 块1    | NORFLASH/PSRAM   |
| 6FFF FFFFH | 4*64MB | NORFLASH/PSRAM   |
| 7000 0000H | 块2    | NANDFLASH        |
| 7FFF FFFFH | 4*64MB | NANDFLASH        |
| 8000 0000H | 块3    | NANDFLASH        |
| 8FFF FFFFH | 4*64MB | NANDFLASH        |
| 9000 0000H | 块4    | PC卡             |
| 9FFF FFFFH | 4*64MB | PC卡             |

### 存储块1

==用于驱动NORFLASH/PSRAM/SRAM==

Bank1被划分为4个区，每个区64MB，都有独立的寄存器进行配置，由28根地址线（HADDR[27:0]）寻址，HADDR是内部AHB地址总线的外延，其中**HADDR[25:0]来自外部存储器地址FSMC_A[25:0]**，**HADDR[26:27]对四个区进行寻址**

当外接16位存储器，HADDR[25:1]->FAMC_A[24:0]（右移1位对齐 即 除以2）

当外接8位存储器，HADDR[25:0]->FAMC_A[25:0]

**不管外接8位还是16位宽设备，FSMC_A[0]永远接在外部设备地址A[0]**

支持多种异步突发访问模式，详见芯片手册

### 存储块2、3

==用于驱动NANDFLASH==

### 存储块4

==用于驱动PC卡==

详见数据手册

### 寄存器库函数封装

在标准库中，ST将FSMC_BCRx FSMC_BTRx FSMC_BWTRx三个单独寄存器进行组合封装

1. FSMC_BCRx和FSMC_BTRx组合成BTCR[8]寄存器数组

| BTCR[0] | FSMC_BCR1 | 对应关系 | BTCR[1] | FSMC_BTR1 |
| ------- | --------- | -------- | ------- | --------- |
| BTCR[2] | FSMC_BCR2 |          | BTCR[3] | FSMC_BTR2 |
| BTCR[4] | FSMC_BCR3 |          | BTCR[5] | FSMC_BTR3 |
| BTCR[6] | FSMC_BCR4 |          | BTCR[7] | FSMC_BTR4 |

2. 将FSMC_BWTRx组合位BWTR[7]数组

BWTR[0]对应FSMC_BWTR1

BWTR[2]对应FSMC_BWTR2

BWTR[4]对应FSMC_BWTR3

BWTR[6]对应FSMC_BWTR4

BWTR[1]、BWTR[3]、BWTR[5]保留，未用到

# 外部SRAM操作

## IS62WV51216ALL参数简介

IS62WV51216是ISSI(Intergrated Silicon Solution,Inc)公司生产的16位宽512K(512*16=1MB)容量的CMOS静态内存(SRAM)芯片

特点：

1. 高速（45ns/55ns访问速度）
2. 低功耗（操作电流36mW，待机12uW）
3. 兼容TTL电平
4. 全静态操作（SRAM特点，不需要刷新和时钟电路）
5. 支持三态输出
6. 字节控制（支持高/低字节控制）

引脚：

1. A0~A18共19根地址线（2^19=512K）
2. IO0~IO15共16根数据线
3. CS1、CS2：片选信号，其中CS1低电平有效，CS2高电平有效
4. OE：输出使能信号（读使能信号）
5. WE：输入使能信号（写使能信号）
6. UB、LB：高字节/低字节控制信号，低电平有效

**读写时序参考芯片数据手册**

示例项目使用55ns的IS62WV51216，读周期时间tRC=写周期时间tWC=55ns；读取寻址时间tAA=55ns(MAX)；写入寻址时间tAA=0ns；读信号OE建立时间tOE=25ns(MAX)；写信号WE建立时间tPWE=45ns

## 硬件连接

| 连接方式 | 数据线 | 地址线 | 读使能 | 写使能 | 片选 | 高字节控制 | 低字节控制 |
| -------- | ------ | ------ | ------ | ------ | ---- | ---------- | ---------- |
| SRAM     | IO0~15 | A0~18  | OE     | WE     | CS   | UB         | LB         |
| FSMC     | D0~15  | A0~18  | OE     | WE     | CS   | UB         | LB         |

## 软件配置

sram.c

```c
#include "sram.h"

//使用NOR/SRAM的Bank1.sector3,地址位HADDR[27,26]=10
//对IS61LV25616/IS62WV25616,地址线范围为A0~A17
//对IS61LV51216/IS62WV51216,地址线范围为A0~A18
#define Bank1_SRAM3_ADDR ((u32)(0x68000000))
  						   
//初始化FSMC与外部SRAM
void FSMC_SRAM_Init(void)
{	
	GPIO_InitTypeDef GPIO_InitStructure;
	FSMC_NORSRAMInitTypeDef FSMC_NORSRAMInitStructure;
  	FSMC_NORSRAMTimingInitTypeDef readWriteTiming; 

    //使能PB、PD、PE、PF、PG与FSMC时钟
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB|
                 		   RCC_AHB1Periph_GPIOD|
                           RCC_AHB1Periph_GPIOE|
                           RCC_AHB1Periph_GPIOF|
                           RCC_AHB1Periph_GPIOG, ENABLE);  
  	RCC_AHB3PeriphClockCmd(RCC_AHB3Periph_FSMC,ENABLE);

    //PB15推挽输出,控制背光
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_15;//PB15 
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;//普通输出模式
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;//100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用设置
 	GPIO_Init(GPIOB, &GPIO_InitStructure);
	GPIO_InitStructure.GPIO_Pin = (3<<0)|(3<<4)|(0XFF<<8);//PD0,1,4,5,8~15 AF OUT
    //应用设置
  	GPIO_Init(GPIOD, &GPIO_InitStructure); 
  	GPIO_InitStructure.GPIO_Pin = (3<<0)|(0X1FF<<7);//PE0,1,7~15,AF OUT
    //应用设置
  	GPIO_Init(GPIOE, &GPIO_InitStructure);
 	GPIO_InitStructure.GPIO_Pin = (0X3F<<0)|(0XF<<12);//PF0~5,12~15
    //应用设置
  	GPIO_Init(GPIOF, &GPIO_InitStructure);  
	GPIO_InitStructure.GPIO_Pin =(0X3F<<0)| GPIO_Pin_10;//PG0~5,10
	//应用设置
  	GPIO_Init(GPIOG, &GPIO_InitStructure);
 
    /*读写时序设置*/
    readWriteTiming.FSMC_AddressSetupTime=0x00;//地址建立时间（ADDSET）为1个HCLK 1/36M=27ns
  	readWriteTiming.FSMC_AddressHoldTime=0x00;//地址保持时间（ADDHLD）模式A未用到
  	readWriteTiming.FSMC_DataSetupTime=0x08;//数据保持时间（DATAST）为9个HCLK 6*9=54ns	 	 
  	readWriteTiming.FSMC_BusTurnAroundDuration=0x00;
  	readWriteTiming.FSMC_CLKDivision=0x00;
  	readWriteTiming.FSMC_DataLatency=0x00;
  	readWriteTiming.FSMC_AccessMode=FSMC_AccessMode_A;//模式A 
    
    /*配置引脚复用*/
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource0,GPIO_AF_FSMC);//PD0,AF12
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource1,GPIO_AF_FSMC);//PD1,AF12
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource4,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource5,GPIO_AF_FSMC); 
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource8,GPIO_AF_FSMC); 
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource9,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource10,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource11,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOD,GPIO_PinSource12,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource13,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource14,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOD,GPIO_PinSource15,GPIO_AF_FSMC);//PD15,AF12
 
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource0,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource1,GPIO_AF_FSMC);
	GPIO_PinAFConfig(GPIOE,GPIO_PinSource7,GPIO_AF_FSMC);//PE7,AF12
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource8,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource9,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource10,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource11,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource12,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource13,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource14,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOE,GPIO_PinSource15,GPIO_AF_FSMC);//PE15,AF12
 
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource0,GPIO_AF_FSMC);//PF0,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource1,GPIO_AF_FSMC);//PF1,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource2,GPIO_AF_FSMC);//PF2,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource3,GPIO_AF_FSMC);//PF3,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource4,GPIO_AF_FSMC);//PF4,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource5,GPIO_AF_FSMC);//PF5,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource12,GPIO_AF_FSMC);//PF12,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource13,GPIO_AF_FSMC);//PF13,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource14,GPIO_AF_FSMC);//PF14,AF12
  	GPIO_PinAFConfig(GPIOF,GPIO_PinSource15,GPIO_AF_FSMC);//PF15,AF12
	
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource0,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource1,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource2,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource3,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource4,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource5,GPIO_AF_FSMC);
  	GPIO_PinAFConfig(GPIOG,GPIO_PinSource10,GPIO_AF_FSMC);

  	FSMC_NORSRAMInitStructure.FSMC_Bank=FSMC_Bank1_NORSRAM3;//NE3对应BTCR[4],[5]
  	FSMC_NORSRAMInitStructure.FSMC_DataAddressMux=FSMC_DataAddressMux_Disable;//关闭数据地址复用
  	FSMC_NORSRAMInitStructure.FSMC_MemoryType=FSMC_MemoryType_SRAM;//操作外部SRAM   
  	FSMC_NORSRAMInitStructure.FSMC_MemoryDataWidth=FSMC_MemoryDataWidth_16b;//存储器数据宽度16位  
  	FSMC_NORSRAMInitStructure.FSMC_BurstAccessMode=FSMC_BurstAccessMode_Disable;//关闭突发访问模式
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignalPolarity=FSMC_WaitSignalPolarity_Low;//等待信号电平为低电平
	FSMC_NORSRAMInitStructure.FSMC_AsynchronousWait=FSMC_AsynchronousWait_Disable;//关闭异步等待传输
  	FSMC_NORSRAMInitStructure.FSMC_WrapMode=FSMC_WrapMode_Disable;//关闭抓取模式
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignalActive=FSMC_WaitSignalActive_BeforeWaitState;  
  	FSMC_NORSRAMInitStructure.FSMC_WriteOperation=FSMC_WriteOperation_Enable;//存储器写使能 
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignal=FSMC_WaitSignal_Disable;//关闭信号等待
  	FSMC_NORSRAMInitStructure.FSMC_ExtendedMode=FSMC_ExtendedMode_Disable;//不使用扩展模式，读写使用相同时序
  	FSMC_NORSRAMInitStructure.FSMC_WriteBurst=FSMC_WriteBurst_Disable;//关闭写突发
  	FSMC_NORSRAMInitStructure.FSMC_ReadWriteTimingStruct=&readWriteTiming;
  	FSMC_NORSRAMInitStructure.FSMC_WriteTimingStruct=&readWriteTiming;//读写使用同步时序，设置生效

  	FSMC_NORSRAMInit(&FSMC_NORSRAMInitStructure);//初始化FSMC配置

 	FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM3, ENABLE);//使能BANK1区域3
}
	  														  
//在指定地址(WriteAddr+Bank1_SRAM3_ADDR)开始,连续写入n个字节.
//pBuffer:字节指针
//WriteAddr:要写入地址
//n:写入字节数
void FSMC_SRAM_WriteBuffer(u8* pBuffer,u32 WriteAddr,u32 n)
{
	for(;n!=0;n--)  
	{
        //Bank1_SRAM3_ADDR为((u32)(0x68000000))
		*(vu8*)(Bank1_SRAM3_ADDR+WriteAddr)=*pBuffer;
		WriteAddr++;
		pBuffer++;
	}   
}

//在指定地址((WriteAddr+Bank1_SRAM3_ADDR))开始,连续读出n个字节.
//pBuffer:字节指针
//ReadAddr:要读出的起始地址
//n:读取字节数
//将写入函数位置调换即可
void FSMC_SRAM_ReadBuffer(u8* pBuffer,u32 ReadAddr,u32 n)
{
	for(;n!=0;n--)  
	{
        //Bank1_SRAM3_ADDR为((u32)(0x68000000))
		*pBuffer++=*(vu8*)(Bank1_SRAM3_ADDR+ReadAddr);    
		ReadAddr++;
	}  
}
```

sram.h

```c
#ifndef __SRAM_H
	#define __SRAM_H															    
	#include "sys.h"

	void FSMC_SRAM_Init(void);//初始化FSMC
	void FSMC_SRAM_WriteBuffer(u8* pBuffer,u32 WriteAddr,u32 NumHalfwordToWrite);//向外部SRAM写字节
	void FSMC_SRAM_ReadBuffer(u8* pBuffer,u32 ReadAddr,u32 NumHalfwordToRead);//从外部SRAM读字节

	void fsmc_sram_test_write(u32 addr,u8 data);//写SRAM
	u8 fsmc_sram_test_read(u32 addr);//读SRAM
#endif
```