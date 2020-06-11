#!/usr/bin/perl
 
# 换行 \n 位于双引号内，有效
$str = "菜鸟教程  \nwww.runoob.com";
print "$str\n";
 
# 换行 \n 位于单引号内，无效
$str = '菜鸟教程  \nwww.runoob.com';
print "$str\n";
 
# 只有 R 会转换为大写
$str = "\urunoob";
print "$str\n";
 
# 所有的字母都会转换为大写
$str = "\Urunoob";
print "$str\n";
 
# 指定部分会转换为大写
$str = "Welcome to \Urunoob\E.com!"; 
print "$str\n";
 
# 将到\E为止的非单词（non-word）字符加上反斜线
$str = "\QWelcome to runoob's family";
print "$str\n";
