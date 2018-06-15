#!/bin/bash
#ZStack Version 1.5
#此脚本解决的问题：当云主机挂载EIP后，云主机获得到网关的MAC地址为多个，造成挂载EIP的云主机连续中断。未挂载EIP的云主机不存在此问题。
#解决方法：取已有EIP的云主机网卡所使用namespace中的MAC地址，将网关地址和MAC地址进行匹配，如果ARP包中的网关地址使用的不是namespace中的MAC，将其在云主机网卡出口方向上进行阻止。

#创建文件和目录 
path="/var/lib/zstack/EIP-mac-filter"
configfile="ebtables.conf"
configfilepath=$path"/"$configfile
#mkdir -p $path
#touch $configfilepath

function mac_filter_create () {
cat /dev/null > $configfilepath

	#print bridge 打印所有的网桥
for num_X_o in $(printf "%s \n" `brctl show` | grep _o) ; 
	do
	#  print num_X_o 打印所有使用EIP的网卡(159_0_o)
	echo $num_X_o

	# print num_X_i for namespace 打印出EIP网卡对应的namespace中的名字(159_0_i)
	num_X_i=${num_X_o//o/i}
	echo $num_X_i 

	# print num  打印网卡名称前面的编号(159)
	num=${num_X_o%%_*} 
	echo $num

	# print vnic_num.X 打印挂载EIP网卡的云主机网卡名称(vnic159.0)
	num_X=${num_X_o%%_o} 
	vnic_num_X=vnic${num_X//_/.} 
	echo $vnic_num_X
		
		#print network namespace 打印所有网络namespace
	for i in $(ip netns | awk '{print $1}');
		do
		# print v_gw_ip for namespace 打印虚拟网关的IP地址
		v_gw_ip=$(ip netns exec $i ifconfig $num_X_i 2> /dev/null | grep mask | awk '{print $2}')
		if [ $v_gw_ip ]; then
			echo $v_gw_ip
			#print v_gw_mac for namespace 打印有虚拟网关IP地址所对应的namespace中的虚拟网关MAC地址
			v_gw_mac=$(ip netns exec $i ifconfig $num_X_i 2> /dev/null | grep ether | awk '{print $2}')
			echo $v_gw_mac
			#print ebtables 打印ebtables表
			echo "ebtables -A FORWARD -p ARP -o" $vnic_num_X "--arp-ip-src" $v_gw_ip "-s !" $v_gw_mac "-j DROP"  >> $configfilepath
		fi
	done

done	
}


function mac_filter_apply () {
while read create
do
    $create
done < $configfilepath

}


function mac_filter_delete () {
while read delete
do
   delete=${delete//-A/-D}
   $delete
done < $configfilepath
}

function start_eip_mac_filter (){
while true
do
sleep 60s
#每次创建新配置文件前,先删除ebtables中原有的配置
mac_filter_delete
#执行一遍网卡扫描，生成新配置文件
mac_filter_create
#通过配置文件创建MAC地址过滤
mac_filter_apply
done
}

start_eip_mac_filter
#mac_filter_delete
#做成服务自动判断网卡变量，如果网卡变量化将重新执行以上过程。
