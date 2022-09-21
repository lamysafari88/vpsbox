#!/bin/bash
###
 # @Author: Steven
 # @Date: 2022-09-21 09:54:02
 # @LastEditors: Steven
 # @LastEditTime: 2022-09-21 10:42:49
 # @FilePath: \vpsbox\node_exporter.sh
 # @Description: 
 # 
 # Copyright (c) 2022 by Steven, All Rights Reserved. 
### 
case $(uname -m) in 
    aarch64 ) PLATFORM='arm64';; 
    x86_64 ) PLATFORM='amd64';; 
    * ) exit 1;; 
esac 
echo $PLATFORM 
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-$PLATFORM.tar.gz 
tar xvf node_exporter-1.3.1.linux-$PLATFORM.tar.gz  
mv node_exporter-1.3.1.linux-$PLATFORM /usr/local/bin/node_exporter 
  
groupadd prometheus 
useradd -g prometheus -m -d /var/lib/prometheus -s /sbin/nologin prometheus 
mkdir /usr/local/prometheus 
chown prometheus.prometheus -R /usr/local/prometheus 
  
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
systemctl restart node_exporter.service 
systemctl enable node_exporter.service 
  
systemctl start node_exporter.service 
systemctl status node_exporter