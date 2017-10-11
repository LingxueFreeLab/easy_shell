#!/usr/bin/env bash
####Change your personal settings####
localport="1080"
ssdomain="yourdomain"
ssconfig="config-client"	#完整路径为/etc/shadowsocks-libev/config-client.json
FANCYDISPLAY=true	#用于在终端中画出一个小飞机图标
USE_CHINADNS=true	#使用true,false或/bin/true,/bin/false
STOP_CHINADNS=false	#退出shadowsocks时是否关闭chinadns
#######################

##DO NOT MODIFY BELOW##
sstool="ss-nat"
#############################
ErrorSolve(){
if [ "$IS_TERMINAL" == "true" ] ; then
[ -n "$*" ] && echo "$*"
read -n 1 -t 5 -p "发生错误，等待5秒或任意键退出"
fi
exit 1
}
Update(){
echo "下载路由表"
wget -O chnroute.tmp 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'
if [ ! -f chnroute.tmp ] ; then
	#echo "错误：路由表下载失败，检查网络连接"
	ErrorSolve "错误：路由表下载失败，检查网络连接"
fi
cat chnroute.tmp | grep ipv4 | grep CN | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute.txt
rm chnroute.tmp
}
Checkenv(){
if [[ $EUID != "0" ]] ; then
	#echo "错误：设置iptables需要root权限"
	ErrorSolve "错误：设置iptables需要root权限"
fi
if [ ! -f "/etc/shadowsocks-libev/${ssconfig}.json" ] ; then
	#echo "错误：配置文件/etc/shadowsocks-libev/${ssconfig}.json不存在"
	ErrorSolve "错误：配置文件/etc/shadowsocks-libev/${ssconfig}.json不存在"
fi
if [ ! -f chnroute.txt ] ; then
Update
fi
if $USE_CHINADNS ; then
	echo -e "\e[1;32m● \e[0m使用chinadns \c"
else
	echo -e "\e[1;31m● \e[0m不使用chinadns \c"
fi
}
Start(){
#Get ip from domain
serverip=$(ping ${ssdomain} -s 1 -c 1 -W 2 | grep ${ssdomain} | head -n 1)
serverip=$(echo ${serverip} | cut -d '(' -f 2 | cut -d ')' -f 1)
if [ -z "$serverip" ] ; then
	#echo "错误：查找服务器ip失败，检查网络连接"
	ErrorSolve "错误：查找服务器ip失败，检查网络连接"
fi
touch /run/ss-iptables.lock
#Start ss client
systemctl start shadowsocks-libev-redir@"$ssconfig".service
$sstool -s ${serverip} -l ${localport} -i chnroute.txt -o
[ $? == 0 ] || ErrorSolve "sstool返回错误"
#Start chinadns if necessary
if $USE_CHINADNS ; then
systemctl is-active chinadns.service >/dev/null || systemctl start chinadns.service
fi
}
Stop(){
$sstool -f
systemctl stop shadowsocks-libev-redir@"$ssconfig".service
if $USE_CHINADNS ; then
${STOP_CHINADNS} && systemctl stop chinadns.service
fi
rm /run/ss-iptables.lock
}
#主进程开始
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
cd "$SCRIPTPATH"
case $* in
update)
Update
exit 0
;;
start)
Checkenv
Start
;;
stop)
Checkenv
Stop
;;
restart)
Checkenv
Stop
systemctl restart networking
Start
;;
"")
IS_TERMINAL="true"
Checkenv
if [ -f /run/ss-iptables.lock ] ; then
	echo -e "\e[41;30m关闭中...\e[0m"
	Stop
else
	echo -e "\e[42;30m启动中...\e[0m"
	Start
fi
if $FANCYDISPLAY ; then
PicShadowsocks="                                   
                                 CO
                              Ls40a
                          e088S4S8C
                       O48S88STT84 
                   Ca4SS48SSTTTT4O 
                L08S88SSSSs4UTTS8  
            3s44S4STTS48ssSUTTT4Y  
         es4888STTTS48sL4STTTTTS3  
     3O0484STTTTTS44s1aSSTTTTT80   
 3Y44S48STTTTTTS44s e44TTTTTTT8e   
 tO08SS48STTTS44Y  a8STTTTTTTS4    
     7sa48SS44Y  O44TTTTTTTTT4Y    
          3YO   Y4088STTTTTTT8?    
                lL0448SS848S4s     
                0ast  2O008842     
                Saa0C       3      
                Ta4e               
                T0                 
                O                  "
systemctl is-failed shadowsocks-libev-redir@"$ssconfig".service >/dev/null && echo -e "\e[41;34m${PicShadowsocks}\e[0m\nShadowsocks-libev启动失败！" || echo -e "\e[1;34m${PicShadowsocks}\e[0m"
if $USE_CHINADNS ; then
systemctl is-failed chinadns.service >/dev/null && echo "ChinaDns启动失败！"
fi
fi
read -n 1 -t 5 -p "等待5秒或任意键退出"
;;
*)
echo "用法:
	update	更新路由表
	start	配置iptables
	stop	取消配置iptables
	restart	重新配置iptables"
;;
esac
exit 0
