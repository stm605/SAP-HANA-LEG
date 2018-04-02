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
sudo mkdir /tmp/LaMaBits
sudo mkdir /tmp/LaMaBits/hostagent
sudo mkdir /tmp/LaMaBits/sapaext

groupadd -g 1001 sapsys
useradd -g 1001 -u 488 -s /bin/false sapadm
useradd -g 1001 -u 1001 -s /bin/csh s42adm
useradd -g 1001 -u 1002 -s /bin/csh s43adm
useradd -g 1001 -u 1010 -s /bin/csh s41adm
useradd -g 1001 -u 1005 -s /bin/sh -M s49adm
useradd -g 1001 -u 1006 -s /bin/sh -M s48adm


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
# sudo saptune solution apply HANA

# SAPTUNE profile options

# BOBJ.  Profile for servers hosting SAP BusinessObjects.
# HANA.  Profile for servers hosting an SAP HANA database.
# MAXDB.  Profile for servers hosting a MaxDB database.
# NETWEAVER.  Profile for servers hosting an SAP NetWeaver application.
# S4HANA-APPSERVER.  Profile for servers hosting an SAP S/4HANA application.
# S4HANA-DBSERVER.  Profile for servers hosting the SAP HANA database of an SAP S/4HANA installation.
# SAP-ASE.  Profile for servers hosting an SAP Adaptive Server Enterprise database (formerly Sybase Adaptive Server Enterprise).


# step2
echo $Uri >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf

/usr/bin/wget --quiet $Uri/LaMaBits/SC -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPHOSTAGENT35_35-20009394.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/SAPACEXT_39-20010403.SAR -P /tmp/LaMaBits
/usr/bin/wget --quiet $Uri/LaMaBits/resolv.conf -P /tmp/LaMaBits

chmod -R 777 /tmp/LaMaBits

cp /tmp/LaMaBits/resolv.conf /etc

/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPHOSTAGENT35_35-20009394.SAR -R /tmp/LaMaBits/hostagent -manifest SIGNATURE.SMF
/tmp/LaMaBits/SC -xvf /tmp/LaMaBits/SAPACEXT_39-20010403.SAR -R /tmp/LaMaBits/sapaext -manifest SIGNATURE.SMF

cd /tmp/LaMaBits/hostagent

./saphostexec -install &> /tmp/hostageninst.txt

echo  "sapadm:Lama1234567!" | chpasswd

cd /usr/sap/hostctrl/exe/

rm SIGNATURE.SMF

./sapacosprep -a InstallAcExt -m /tmp/LaMaBits/SAPACEXT_39-20010403.SAR &> /tmp/sapacextinst.txt

./SAPCAR -xvf /tmp/LaMaBits/SAPACEXT_39-20010403.SAR libsapacosprep_azr.so
./SAPCAR -xvf /tmp/LaMaBits/SAPACEXT_39-20010403.SAR libsapacext_lvm.so

echo "acosprep/sapifconfig = 1" >> /usr/sap/hostctrl/exe/host_profile
/usr/sap/hostctrl/exe/saphostexec -restart
