Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
vmSize=$6


#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y sapconf
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /sapmnt
sudu mkdir /usr/sap


# Install .NET Core and AzCopy
sudo zypper install -y libunwind
sudo zypper install -y libicu
curl -sSL -o dotnet.tar.gz https://go.microsoft.com/fwlink/?linkid=848824
sudo mkdir -p /opt/dotnet && sudo tar zxf dotnet.tar.gz -C /opt/dotnet
sudo ln -s /opt/dotnet/dotnet /usr/bin

wget -O azcopy.tar.gz https://aka.ms/downloadazcopyprlinux
tar -xf azcopy.tar.gz
sudo ./install.sh

sudo zypper se -t pattern
sudo zypper in -t pattern sap-hana
sudo saptune solution apply HANA

# step2
echo $Uri >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf


echo "logicalvols start" >> /tmp/parameter.txt
  sapmntvglun="$(lsscsi 5 0 0 0 | grep -o '.\{9\}$')"  
  pvcreate sapmntvg $sapmntvglun 
  vgcreate sapmntvg $sapmntvglun
  lvcreate -l 50%FREE -n usrsaplv sapmntvg
  lvcreate -l 50% -n sapmntlv sapmntvg
  mkfs.xfs /dev/sapmntvg/sapmntlv
  mkfs.xfs /dev/sapmntvg/usrsaplv
echo "logicalvols end" >> /tmp/parameter.txt

#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sapmntvg/sapmntlv
mount -t xfs /dev/sapmntvg/usrsaplv
echo "mounthanashared end" >> /tmp/parameter.txt
echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/sapmntvg/sapmntlv /sapmnt xfs defaults 0 0" >> /etc/fstab
echo "/dev/sapmntvg/usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt
