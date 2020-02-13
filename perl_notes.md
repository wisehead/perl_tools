#一、perl安装
1，取得perl , http://www.perl.org/

2，解文件包，$tar -xzvf perl-$verion.tar.gz

3，在解压目录 perl-$version 下

$rm -f config.sh Policy.sh

$sh Configure -de

$make && make test && make install

config.sh Policy.sh 为以前安装时的配置文件，新安装或升级安装时，需要将其删除。

sh Configure -de 安装使用默认配置，一般而言将会 ok 。

安装完成后 perl 所在目录为 /usr/local/lib/perl$version, perl 执行文件在 /usr/local/bin 中。

4，关于 .html 文件

安装 perl 时不能自动安装 .html 文件， 在 perl-$version目录中有一个installhtml 文件， 执行 perl installhtml --help 可得到使用帮助，

使用installhtml可将 .pod 及 .pm 文件编译得到相应的 .html 文件文件，

#二、perl模块安装
1，下载所需模块，http://www.cpan.org/

2，安装

*手工安装的步骤：　

解压缩模块包：　

$tar　xvzf　DBI-$version.tar.gz　

进入解包的目录

$cd　DBI-$version　

$perl　Makefile.PL　 　

$make && make test && make　install　

　上述步骤适合于Linux/Unix下绝大多数的Perl模块。可能还有少数模块的安装方法略有差别，　 所以最好先看看安装目录里的README或INSTALL。另外，上述过程是针对动态链接的Perl编译　 器（所有Linux下预安装的Perl都是动态链接的），如果您在使用一个静态链接的Perl，您需要将　 新的模块静态链接到perl编译器中，可能还需要重启机器。　 　　

*使用CPAN模块自动安装：　

安装前需要先连上internet，并且您需要取得root权限。　

$perl　-MCPAN　-e　shell　

初次运行CPAN时需要做一些设置，如果您的机器是直接与internet相联（拨号上网、专线，etc.），　 那么一路回车就行了，只需要在最后选一个离您最近的CPAN镜像站点。否则，如果您的机器　 位于防火墙之后，还需要设置ftp代理或http代理。　

获得帮助　

cpan>h　

列出CPAN上所有模块的列表　

cpan>m　

安装模块　

cpan>install　DBI　

自动完成DBI模块从下载到安装的全过程。　

退出　

cpan>q　

安装完成后模块在 /usr/local/lib/perl$version/site_perl 目录中