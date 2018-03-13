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
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /sapmnt
sudo mkdir /usr/sap


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

touch /home/me.txt

mv /home /home.new
mkdir /home 

echo "logicalvols start" >> /tmp/parameter.txt
  sapmntvglun="$(lsscsi 5 0 0 0 | grep -o '.\{9\}$')"  
  pvcreate sapmntvg $sapmntvglun 
  vgcreate sapmntvg $sapmntvglun
  lvcreate -l 50%VG -n usrsaplv sapmntvg
  lvcreate -l 40%VG -n sapmntlv sapmntvg
  lvcreate -l 10%VG -n homelv sapmntvg
  mkfs.xfs /dev/sapmntvg/sapmntlv
  mkfs.xfs /dev/sapmntvg/usrsaplv
  mkfs.xfs /dev/sapmntvg/homelv
echo "logicalvols end" >> /tmp/parameter.txt

#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sapmntvg/sapmntlv /sapmnt
mount -t xfs /dev/sapmntvg/usrsaplv /usr/sap
mount -t xfs /dev/sapmntvg/homelv /home
echo "mounthanashared end" >> /tmp/parameter.txt
echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/sapmntvg-sapmntlv /sapmnt xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sapmntvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sapmntvg-homelv /home xfs defaults 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

mv /home.new/* /home

echo "It worked" >> /home/me.txt
