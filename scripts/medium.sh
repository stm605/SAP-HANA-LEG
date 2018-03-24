Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
HANAVHOST=$6
SecondaryStaticIP=$7
cidr=/24
SecIP=$SecondaryStaticIP$cidr
sadm=adm
sidadm=$HANASID$sadm
lsidadm=${sidadm,,}

/usr/bin/wget --quiet $Uri/LaMaBits/resolv.conf -P /tmp/LaMaBits

cp /tmp/LaMaBits/resolv.conf /etc

echo $HANAVHOST >> /tmp/vhost.txt
echo $SecondaryStaticIP >> /tmp/SecondaryStaticIP.txt
echo $SecIP >> /tmp/SecIP.txt

#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y krb5-client samba-winbind
sudo zypper install -y saptune
mkdir /etc/systemd/login.conf.d
mkdir -p /tmp/LaMaBits/hostagent
mkdir -p /tmp/LaMaBits/sapaext
mkdir -p /hana/data/$HANASID
mkdir -p /hana/log/$HANASID
mkdir -p /hana/shared/$HANASID
mkdir -p /hana/backup/$HANASID
mkdir -p /usr/sap/$HANASID


groupadd -g 1001 sapsys
useradd -g 1001 -u 488 -s /bin/false sapadm

# Install .NET Core and AzCopy
sudo zypper install -y libunwind
sudo zypper install -y libicu
curl -sSL -o dotnet.tar.gz https://go.microsoft.com/fwlink/?linkid=848824
mkdir -p /opt/dotnet && sudo tar zxf dotnet.tar.gz -C /opt/dotnet
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
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=229376/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf

/usr/bin/wget --quiet $Uri/LaMaBits/SC -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPHOSTAGENT.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPACEXT.SAR -P /tmp/LaMaBits

chmod -R 777 /tmp/LaMaBits

/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPHOSTAGENT.SAR -R /tmp/LaMaBits/hostagent -manifest SIGNATURE.SMF
/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPACEXT.SAR -R /tmp/LaMaBits/sapaext -manifest SIGNATURE.SMF

cd /tmp/LaMaBits/hostagent

./saphostexec -install &> /tmp/hostageninst.txt

echo  "sapadm:Lama1234567!" | chpasswd

cd /usr/sap/hostctrl/exe/

rm SIGNATURE.SMF

./sapacosprep -a InstallAcExt -m /tmp/LaMaBits/SAPACEXT.SAR &> /tmp/sapacextinst.txt

./SAPCAR -xvf /tmp/LaMaBits/SAPACEXT.SAR libsapacosprep_azr.so
./SAPCAR -xvf /tmp/LaMaBits/SAPACEXT.SAR libsapacext_lvm.so

echo "acosprep/sapifconfig = 1" >> /usr/sap/hostctrl/exe/host_profile
/usr/sap/hostctrl/exe/saphostexec -restart

/usr/sap/hostctrl/exe/sapacosprep -a ifup -i "eth0" -h $HANAVHOST -n 255.255.255.0 &> /tmp/sapacosprep.txt

number="$(lsscsi [*] 0 0 4| cut -c2)"
echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 5 | grep -o '.\{9\}$')"
  pvcreate hanavg $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%FREE -n datalv$HANASID hanavg
  lvcreate -l 20%VG -n loglv$HANASID hanavg
  mkfs.xfs /dev/hanavg/datalv$HANASID
  mkfs.xfs /dev/hanavg/loglv$HANASID
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun1="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  backupvglun2="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  pvcreate $backupvglun1 $backupvglun2 $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun1 $backupvglun2
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv$HANASID sharedvg 
  lvcreate -l 100%FREE -n backuplv$HANASID backupvg 
  lvcreate -l 100%VG -n usrsaplv$HANASID usrsapvg
  mkfs -t xfs /dev/sharedvg/sharedlv$HANASID 
  mkfs -t xfs /dev/backupvg/backuplv$HANASID 
  mkfs -t xfs /dev/usrsapvg/usrsaplv$HANASID
echo "logicalvols2 end" >> /tmp/parameter.txt

#!/bin/bash
#echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/data$HANASID /hana/shared/$HANASID
mount -t xfs /dev/sharedvg/log$HANASID /hana/log/$HANASID
mount -t xfs /dev/sharedvg/sharedlv$HANASID /hana/shared/$HANASID
mount -t xfs /dev/sharedvg/backup$HANASID /hana/backup/$HANASID
mount -t xfs /dev/sharedvg/usrsaplv$HANASID /usr/sap/$HANASID
#echo "mounthanashared end" >> /tmp/parameter.txt
chown $lsidadm:sapsys /hana/shared/$HANASID
chown $lsidadm:sapsys /hana/backup/$HANASID
chown $lsidadm:sapsys /usr/sap/$HANASID
chown $lsidadm:sapsys /hana/data/$HANASID
chown $lsidadm:sapsys /hana/log/$HANASID

#mount -t xfs /dev/sharedvg/sharedlv /hana/shared
#mount -t xfs /dev/backupvg/backuplv /hana/backup 
#mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap/$HANASID
#mount -t xfs /dev/hanavg/datalv /hana/data
#mount -t xfs /dev/hanavg/loglv /hana/log 

#echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/hanavg-datalv$HANASID /hana/data/$HANASID xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/hanavg-loglv$HANASID /hana/log/$HANASID xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv$HANASID /hana/shared/$HANASID xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv$HANASID /hana/backup/$HANASID xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv$HANASID /usr/sap/$HANASID xfs defaults 0 0" >> /etc/fstab
#echo "write to fstab end" >> /tmp/parameter.txt

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
