#!/bin/bash
###
 # @Author: Steven
 # @Date: 2022-09-21 09:54:02
 # @LastEditors: Steven
 # @LastEditTime: 2022-09-22 17:34:21
 # @FilePath: \vpsbox\node_exporter.sh
 # @Description: 
 # 
 # Copyright (c) 2022 by Steven, All Rights Reserved. 
### 
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[INFO]${Font_color_suffix}"

check_arc(){
if arch | grep -q -E -i "x86"; then
	arc="Amd64"
elif dpkg --print-architecture | grep -q -E -i "arm64"; then
	arc="Arm64"
else
		echo -e "${Info} System Arc Detect Failed"
	fi
}


wgetfile(){
	if [[ "${arc}" == "Amd64" ]]; then
		echo -e "${Info} Downloading File"
		wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz >/dev/null 2>&1
		tar xvf node_exporter-1.3.1.linux-amd64.tar.gz >/dev/null 2>&1
		mv node_exporter-1.3.1.linux-amd64 /usr/local/bin/node_exporter
		echo -e "${Info} Download Completed"
	elif [[ "${arc}" == "Arm64" ]]; then
		echo -e "${Info} Downloading File"
		wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-arm64.tar.gz >/dev/null 2>&1
		tar xvf node_exporter-1.3.1.linux-arm64.tar.gz >/dev/null 2>&1
		mv node_exporter-1.3.1.linux-arm64 /usr/local/bin/node_exporter
		echo -e "${Info} Download Completed"
	else
		echo -e "${Info} System Arc Detect Failed"
		exit
	fi
	enablefile
}

enablefile(){
	groupadd prometheus >/dev/null 2>&1
	useradd -g prometheus -m -d /var/lib/prometheus -s /sbin/nologin prometheus >/dev/null 2>&1
	mkdir /usr/local/prometheus >/dev/null 2>&1
	chown prometheus.prometheus -R /usr/local/prometheus >/dev/null 2>&1
 
	cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=node_exporter
Documentation=https://prometheus.io/
After=network.target
[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/node_exporter/node_exporter --collector.processes  --collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($|/)
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
 
systemctl daemon-reload
systemctl enable --now node_exporter.service
systemctl restart node_exporter.service
systemctl status node_exporter
}

main(){
check_arc
echo -e "${Info} System Arc: ${arc}"
wgetfile

}

main