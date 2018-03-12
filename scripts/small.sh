Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
HANAVHOST=$6
SecondaryStaticIP=$7

echo $HANAVHOST >> /tmp/vhost.txt
echo $SecondaryStaticIP >> /tmp/SecondaryStaticIP.txt

sudo ifconfig eth0:0 $SecondaryStaticIP netmask 255.255.255.0 up

touch /etc/sysconfig/network/ifcfg-eth0:0

echo DEVICE=eth0:0 >> /etc/sysconfig/network/ifcfg-eth0:0
echo BOOTPROTO=static >> /etc/sysconfig/network/ifcfg-eth0:0
echo ONBOOT=yes >> /etc/sysconfig/network/ifcfg-eth0:0
echo IPADDR=$SecondaryStaticIP >> /etc/sysconfig/network/ifcfg-eth0:0
echo NETMASK=255.255.255.0 >> /etc/sysconfig/network/ifcfg-eth0:0

#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y krb5-client samba-winbind
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /hana
sudo mkdir /hana/data
sudo mkdir /hana/log
sudo mkdir /hana/shared
sudo mkdir /hana/backup
sudo mkdir /usr/sap
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /tmp/LaMaBits
sudo mkdir /tmp/LaMaBits/hostagent
sudo mkdir /tmp/LaMaBits/sapaext

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

/usr/bin/wget --quiet $Uri/LaMaBits/SC -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPHOSTAGENT.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPACEXT.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/resolv.conf -P /tmp/LaMaBits


number="$(lsscsi [*] 0 0 4| cut -c2)"

echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%VG -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  pvcreate $backupvglun $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 97%VG -n usrsaplv usrsapvg
  lvcreate -l 3%VG -n homelv usrsapvg
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
  mkfs -t xfs /dev/usrsapvg/homelv
echo "logicalvols2 end" >> /tmp/parameter.txt


#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/usrsapvg/homelv /home
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mkdir /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt

echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/hanavg-datalv /hana/data xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/hanavg-loglv /hana/log xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv /hana/shared xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv /hana/backup xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-homelv /home xfs defaults 0 0" >> /etc/fstab
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


if [ ! -d "/hana/data/sapbits" ]
 then
 mkdir "/hana/data/sapbits"
fi



#!/bin/bash
cd /hana/data/sapbits
echo "hana download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $Uri/SapBits/md5sums
/usr/bin/wget --quiet $Uri/SapBits/51052325_part1.exe
/usr/bin/wget --quiet $Uri/SapBits/51052325_part2.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part3.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part4.rar
/usr/bin/wget --quiet "https://raw.githubusercontent.com/stm605/SAP-HANA-LEG/master/hdbinst.cfg"
echo "hana download end" >> /tmp/parameter.txt

cp /tmp/LaMaBits/resolv.conf /etc

date >> /tmp/testdate
cd /hana/data/sapbits

echo "hana unrar start" >> /tmp/parameter.txt
#!/bin/bash
cd /hana/data/sapbits
unrar x 51052325_part1.exe
echo "hana unrar end" >> /tmp/parameter.txt

echo "hana prepare start" >> /tmp/parameter.txt
cd /hana/data/sapbits

#!/bin/bash
cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$HANAVHOST/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/AweS0me@PW/$HANAPWD/g"
sedcmd5="s/sid=H10/sid=$HANASID/g"
sedcmd6="s/number=00/number=$HANANUMBER/g"
cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
echo "hana preapre end" >> /tmp/parameter.txt

#!/bin/bash
echo "install hana start" >> /tmp/parameter.txt
cd /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
echo "install hana end" >> /tmp/parameter.txt

shutdown -r 1
