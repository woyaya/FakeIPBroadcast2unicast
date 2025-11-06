# WHY
## CN
通过AP－client方式无线桥接的（子）路由器中，主路由器（及其下挂设备）无法获取子路由器下挂设备的MAC，只能将报文发给子路由器，再由子路由器转发
当主路由器将fake IP报文路由给子路由的下挂设备时，由于fake IP在子路由中没有ARP表，所以子路由器只能使用广播方式（目标MAC地址为全'FF'）转发fake IP报文。这种广播报文会在iptables的filter的INPUT链处理结束后被丢弃
这个脚本使用ebtables将广播报文转换成单播报文，避免报文丢弃

## EN
In a wireless bridged (sub)router setup using AP-client, the main router (and its connected devices) cannot obtain the MAC addresses of the connected devices under the sub-router. It can only send packets to the sub-router, which then forwards them.

When the main router routes fake IP packets to the connected devices under the sub-router, because fake IPs are not listed in the sub-router's ARP table, the sub-router can only forward the fake IP packets using broadcast (with all 'FF' as the destination MAC address). These broadcast packets are discarded after processing in the 'INPUT' chain of the iptables 'filter'.

This script uses 'ebtables' to convert broadcast packets into unicast packets, preventing packet discarding.
