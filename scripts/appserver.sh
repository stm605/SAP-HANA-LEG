Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
HANAVHOST=$6
SecondaryStaticIP=$7
cidr=/24
SecIP=$SecondaryStaticIP$cidr

#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y krb5-client samba-winbind
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /sapmnt
sudo mkdir /usr/sap
sudo mkdir /tmp/LaMaBits
sudo mkdir /tmp/LaMaBits/hostagent
sudo mkdir /tmp/LaMaBits/sapaext

/usr/bin/wget --quiet $Uri/LaMaBits/resolv.conf -P /tmp/LaMaBits

cp /tmp/LaMaBits/resolv.conf /etc

echo $HANAVHOST >> /tmp/vhost.txt
echo $SecondaryStaticIP >> /tmp/SecondaryStaticIP.txt
echo $SecIP >> /tmp/SecIP.txt

ip addr add $SecIP dev eth0 label eth0:1


groupadd -g 1001 sapsys


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

# SAPTUNE profile options

# BOBJ.  Profile for servers hosting SAP BusinessObjects.
# HANA.  Profile for servers hosting an SAP HANA database.
# MAXDB.  Profile for servers hosting a MaxDB database.
# NETWEAVER.  Profile for servers hosting an SAP NetWeaver application.
# S4HANA-APPSERVER.  Profile for servers hosting an SAP S/4HANA application.
# S4HANA-DBSERVER.  Profile for servers hosting the SAP HANA database of an SAP S/4HANA installation.
# SAP-ASE.  Profile for servers hosting an SAP Adaptive Server Enterprise database (formerly Sybase Adaptive Server Enterprise).

sudo saptune solution apply S4HANA-APPSERVER


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
/usr/bin/wget --quiet $Uri/LaMaBits/SC -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPHOSTAGENT.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPACEXT.SAR -P /tmp/LaMaBits

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

chmod -R 777 /tmp/LaMaBits

/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPHOSTAGENT.SAR -R /tmp/LaMaBits/hostagent -manifest SIGNATURE.SMF
/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPACEXT.SAR -R /tmp/LaMaBits/sapaext -manifest SIGNATURE.SMF

cd /tmp/LaMaBits/hostagent

./saphostexec -install &> /tmp/hostageninst.txt

echo  "sapadm:Lama1234567!" | chpasswd

cd /tmp/LaMaBits/sapaext

cp *.so /usr/sap/hostctrl/exe/

mkdir /usr/sap/hostctrl/exe/operations.d
cp operations.d/*.conf /usr/sap/hostctrl/exe/operations.d/

cp SIGNATURE.SMF /usr/sap/hostctrl/exe/SAPACEXT.SMF

cp sapacext /usr/sap/hostctrl/exe/

cd /usr/sap/hostctrl/exe/

chown root:sapsys sapacext
chmod 750 sapacext

shutdown -r 1
