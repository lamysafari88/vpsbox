#!/bin/bash

enableNetworkIfce="yes"
networkIfce="$NFCE"

VERSION="v1.0.0"

function bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(B {K,M,G,T,P,E,Z,Y}B)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

usedMem=$(free -m | grep Mem | awk '{print $3}')
totalMem=$(free -m | grep Mem | awk '{print $2}')
usedDisk="$(df -l | grep -E '^/dev' | awk '{print $3}' | awk '{s+=$1} END {print s}')000"
totalDisk="$(df -l | grep -E '^/dev' | awk '{print $2}' | awk '{s+=$1} END {print s}')000"
cpuCount=$(cat /proc/cpuinfo | grep processor | wc -l)
cpuName=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -b 14- | awk -F@ '{print $1}' | sed -e 's/[[:space:]]*$//')
if [ "$cpuName" == "" ]; then
  cpuName=$(lscpu 2> /dev/null | grep 'Model name' | head -1 | awk -F ':' '{print $2}' | sed -E 's/^\s+//')
fi
if [ "$cpuName" == "" ]; then
  cpuName=$(cat /proc/cpuinfo | grep -P "^Model" | head -1 | cut -b 10- | awk -F@ '{print $1}' | sed -e 's/[[:space:]]*$//')
fi
cpuFreq=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | cut -b 12-)
if [ "$cpuFreq" == "" ]; then
  cpuFreqRaw=$(lscpu 2> /dev/null | grep MHz | grep CPU | head -1 | awk -F ':' '{print $2}' | awk -F '.' '{print $1}')
  if [ "$cpuFreqRaw" != "" ]; then
    cpuFreq="$(($cpuFreqRaw / 1))"
  fi
fi
if [ "$cpuFreq" == "" ]; then
  cpuFreq="unknown"
fi
cpuSteal=$(top -bn1 | sed -n '/Cpu/p' | awk -F , '{print $8}' | awk '{print $1}' | awk -F % '{print $1}')
cpuIdle=$(top -bn1 | sed -n '/Cpu/p' | awk -F , '{print $4}' | awk '{print $1}' | awk -F % '{print $1}')
cpuIdle=$(echo "100 $cpuIdle" | awk '{print $1-$2}')
virtualization=$(hostnamectl status 2> /dev/null | grep "irtualization" | awk -F ': ' '{print $2}')
architecture=$(arch)
os=$(hostnamectl status 2> /dev/null | grep "perating" | awk -F ': ' '{print $2}')
procCount=$(ps -ax | grep -v 'ps -ax' | grep -v -E '\[.*\]' | wc -l)
kernelInfo=$(uname -r)
uptimeInfo=$(uptime -p | sed 's/up //g')
loadInfo=$(uptime | awk -F 'average: ' '{print $2}')
dns=$(cat /etc/resolv.conf | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
# hostMemCount=$(lshw -short -quiet 2> /dev/null | grep memory | wc -l)
# $(lshw -short -quiet 2> /dev/null | grep processor | wc -l)
# hostCpuCount=$(cat /proc/cpuinfo 2> /dev/null | grep processor | wc -l)
tempurature=""
if cat /sys/class/thermal/thermal_zone0/temp &> /dev/null; then
    tempurature=" ($(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))°C)"
fi
if [ "$networkIfce" == "" ]; then
    networkIfce=$(ls /sys/class/net/ | grep -E '^e' | head -1)
fi
if [ "$networkIfce" == "" ]; then
    networkIfce=$(ls /sys/class/net/ | grep -E '^n' | head -1)
fi
if [ "$networkIfce" == "" ]; then
    networkIfce=$(ls /sys/class/net/ | grep -E '^v' | head -1)
fi
if [ "$virtualization" == "" ]; then
    virtualization="dedi"
fi
if [ "$architecture" == "" ];then
    architecture="NoArch"
fi
if [ "$os" == "" ]; then
    os="无法获取"
fi
txIfce=$(cat /sys/class/net/$networkIfce/statistics/tx_bytes)
rxIfce=$(cat /sys/class/net/$networkIfce/statistics/rx_bytes)

bbr=$(lsmod 2> /dev/null | grep bbr | head -1)
bbrMsg=" bbr"
if [ -z "$bbr" ]; then
    bbrMsg=""
fi

# nat=$(ps -ax | grep -v 'grep' | grep dnat | head -1)
# natMsg="开启"
# if [ -z "$nat" ]; then
#     natMsg="关闭"
# fi

ipInfo=$(wget -T 1 -t 1 -qO- -4 ipinfo.io 2> /dev/null)
ipInfo4=$(echo "$ipInfo" | grep '"ip"' | awk -F '"' '{print $4}')
ipOrg=$(echo "$ipInfo" | grep '"org"' | awk -F '"' '{print $4}')
ipCon=$(echo "$ipInfo" | grep '"country"' | awk -F '"' '{print $4}')
ipInfo6=$(wget -T 1 -t 1 -qO- -6 ip.sb 2> /dev/null)
ipExtra=""

if [ "$ipInfo4" != "" ]; then
    ipExtra=" ($ipOrg, $ipCon)"
else
    ipInfo4=$(wget -T 1 -t 1 -qO- -4 ip.sb 2> /dev/null)
fi

if [ -z "$ipInfo4" ]; then
    ipInfo="无法获取"
fi

if [ -z "$ipInfo6" ]; then
    ipInfo6="无法获取"
fi

red="\033[31m"
black="\033[0m"

function printInterface() {
    ifceTXT=""
    if ip addr > /dev/null; then
      ipTXT="$(ip addr show up scope global)\n99999: unknown: <UNKNOWN>"
      currentIfce="default"
      addressInfo=""
      while read line; do
        # interface
        if echo "$line" | grep -P '^\d+: \S+: <' > /dev/null; then
          if [ "$addressInfo" != "" ]; then
            lineTXT=$(printf "%-18s %s" "${currentIfce}:" "${addressInfo}")
            ifceTXT="${ifceTXT}\n${lineTXT}"
            addressInfo=""
          fi
          currentIfce="$(echo "$line" | awk -F ': ' '{print $2}')"
        fi
        # ip address
        ipAddress=""
        if echo "$line" | grep -P '^\s*inet ' > /dev/null; then
          ipAddress="$(echo "$line" | awk -F 'inet ' '{print $2}' | awk -F ' ' '{print $1}')"
        fi
        if echo "$line" | grep -P '^\s*inet6 ' > /dev/null; then
          ipAddress="$(echo "$line" | awk -F 'inet6 ' '{print $2}' | awk -F ' ' '{print $1}')"
        fi
        if [ "$ipAddress" != "" ]; then
          if [ "$addressInfo" != "" ]; then
            addressInfo="${addressInfo}, "
          fi
          addressInfo="${addressInfo}${red}${ipAddress}${black}"
        fi
      done < <(echo -e "$ipTXT")
    fi

    if [ "$ifceTXT" != "" ]; then
      echo -e "接口信息:$ifceTXT"
      echo
    fi
}

function printItem() {
    key="$1"
    val="$2"
    if [ "$val" == "" ]; then
      if [ "$3" != "" ]; then
        val="$3"
      fi
    fi

    if [ "$val" != "" ]; then
      echo -e "$(printf "%-22s %s" "${key}:" "${red}${val}${black}")"
    fi
}

function printScreen() {
    echo
    echo "系统指标:"
    echo -e "版本: ${red}${VERSION}${black}，@nhfetch制作组 modified by Steven"
    echo
    printItem "进程数量" "$procCount"
    printItem "运行时间" "$uptimeInfo"
    printItem "处理信息" "${cpuCount} x ${cpuName} @ ${cpuFreq} MHz${tempurature}"
    printItem "内存使用" "${usedMem} MB / ${totalMem} MB"
    printItem "硬盘信息" "$(bytesToHuman $usedDisk) / $(bytesToHuman $totalDisk)"
    printItem "系统信息" "${os} (${kernelInfo}, ${architecture} ${virtualization}${bbrMsg})"
    printItem "主机地址" "${ipInfo4}, ${ipInfo6}${ipExtra}"
    printItem "流量信息" "$(bytesToHuman $txIfce) ↑ $(bytesToHuman $rxIfce) ↓"
    printItem "系统负载" "${loadInfo}"
    printItem "虚拟负载" "${cpuSteal}, ${cpuIdle}"
    printItem "系统 DNS" "${dns}"
    echo
    
    if [ "$enableNetworkIfce" == "yes" ]; then
      printInterface
    fi
}

txOld="0"
rxOld="0"
prepareNetwork() {
    [[ "$networkIfce" == "" ]] && echo "Cannot find network device!" && exit 1
    txOld="$(cat /sys/class/net/$networkIfce/statistics/tx_bytes)"
    rxOld="$(cat /sys/class/net/$networkIfce/statistics/rx_bytes)"
}

printNetwork() {
  txNew=$(cat /sys/class/net/$networkIfce/statistics/tx_bytes)
  rxNew=$(cat /sys/class/net/$networkIfce/statistics/rx_bytes)
  txRate=$(bytesToHuman $(($txNew-$txOld)))
  rxRate=$(bytesToHuman $(($rxNew-$rxOld)))
  txData=$(bytesToHuman $txNew)
  rxData=$(bytesToHuman $rxNew)
  txOld="$txNew"
  rxOld="$rxNew"
  clear
  echo -e "Network Interface ${red}$networkIfce${black}:"
  echo "-----------"
  echo -e "Since Up: ${red}${txData}${black} ↑  ${red}${rxData}${black} ↓"
  echo -e "Realtime: ${red}${txRate}/s${black} ↑  ${red}${rxRate}/s${black} ↓"
}

if [ "$1" == "uninstall" ]; then

    [[ "$EUID" -ne '0' ]] && echo -e "${red}[错误]${black} 请使用 root 权限运行安装指令" && exit 1;
    rm -f /etc/update-motd.d/00-nhfetch
    rm -f /etc/profile.d/nhfetch.sh
    rm -f /usr/local/bin/nhfetch
    
    hasBak=$(ls /etc/update-motd.d.bak/ 2> /dev/null)
    if [ ! -z "$hasBak" ]; then
        mv /etc/update-motd.d.bak/* /etc/update-motd.d/ 2> /dev/null
        rm -rf /etc/update-motd.d.bak/
    fi
    
    echo -e "${red}[成功]${black} 卸载完成"
    [[ "$2" != "keep" ]] && rm -f $0
    exit 0

fi

if [ "$1" == "install" ]; then

    [[ "$EUID" -ne '0' ]] && echo -e "${red}[错误]${black} 请使用 root 权限运行安装指令" && exit 1;
    isUpdated=$(ls /etc/update-motd.d/ 2> /dev/null)
    isProfiled=$(ls /etc/profile.d/ 2> /dev/null)
    
    echo '' > /etc/motd
    
    # use update-motd.d
    if [ ! -z "$isUpdated" ]; then
        isLocked=$(cat /etc/ssh/sshd_config 2> /dev/null | grep -E "UsePAM.*no" 2> /dev/null)
        if [ ! -z "$isLocked" ]; then
            sed -i 's/UsePAM.*no/UsePAM yes/' /etc/ssh/sshd_config
            systemctl restart sshd &> /dev/null
        fi
        
        mkdir -p /etc/update-motd.d.bak
        rm -rf /etc/update-motd.d/00-nhfetch
        mv /etc/update-motd.d/* /etc/update-motd.d.bak/ 2> /dev/null
        
        # rm -rf /etc/update-motd.d/00-header
        # rm -rf /etc/update-motd.d/10-help-text
        # rm -rf /etc/update-motd.d/50-landscape-sysinfo
        # rm -rf /etc/update-motd.d/50-motd-news
        # rm -rf /etc/update-motd.d/80-esm
        # rm -rf /etc/update-motd.d/80-livepatch
        # rm -rf /etc/update-motd.d/90-updates-available
        # rm -rf /etc/update-motd.d/91-release-upgrade
        # rm -rf /etc/update-motd.d/95-hwe-eol
        # rm -rf /etc/update-motd.d/97-overlayroot
        # rm -rf /etc/update-motd.d/98-fsck-at-reboot
        # rm -rf /etc/update-motd.d/98-reboot-required
        
        cp -f $0 /etc/update-motd.d/00-nhfetch
        chmod +x /etc/update-motd.d/00-nhfetch
        cp -f $0 /usr/local/bin/nhfetch
        chmod +x /usr/local/bin/nhfetch
        
        echo -e "${red}[成功]${black} 安装完成"
        [[ "$2" != "keep" ]] && rm -f $0
        exit 0
    fi
    
    # use profile.d
    if [ ! -z "$isProfiled" ]; then
        cp -f $0 /etc/profile.d/nhfetch.sh
        chmod +x /etc/profile.d/nhfetch.sh
        cp -f $0 /usr/local/bin/nhfetch
        chmod +x /usr/local/bin/nhfetch
        
        echo -e "${red}[成功]${black} 安装完成"
        [[ "$2" != "keep" ]] && rm -f $0
        exit 0
    fi
    
    # otherwise exit
    echo -e "${red}[错误]${black} 无法识别系统使用的命令加载器"
    [[ "$2" != "keep" ]] && rm -f $0
    exit 0

fi

if [ "$1" == "--nocolor" ]; then
    red=""
    black=""
fi

if [ "$1" == "--monitor" ]; then
    prepareNetwork
    while [ "" == "" ]; do
      sleep 1
      printNetwork
    done
fi

printScreen

