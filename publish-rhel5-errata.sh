#!/bin/bash
#  publish-rhel-errata  : This script will publish the updateinfo.xml into the relevant rhel repo.  This will then
#                         allow any server to pull the errata DB and all us to identify which security updates are missing.
#
#   Version      Author          Date        Description
#     0.1        Nigel Heaney    06-07-2016  Initial version
#

BASEPATH=/root/scripts
YUMBASEPATH=/var/www/html/repo/rhel-x86_64-server-5
REPOMDDIR=/var/www/html/repo/rhel-x86_64-server-5/getPackage/repodata
YUMCACHEFILE=`ls -1 /var/cache/yum/rhel-5-server-rpms/*-updateinfo.xml.gz`
RELEASE=5

#MAIN
if [ ! $USER == root ]; then
    echo "ERROR - This script must be run as root!"
    exit 1
fi

if [ ! -e $YUMBASEPATH ]; then
    echo "ERROR - Cannot locate $YUMBASEPATH!"
    exit 1
fi

echo -e "\nUpdating RHEL${RELEASE} Errata information...\n"
echo -en "\tPulling new Errata..."
yum info-sec &> /dev/null
echo -e "Done"

if [ ! -e $YUMCACHEFILE ]; then
    echo "ERROR - Cannot locate $YUMCACHEFILE"
    exit 1
fi

#Cleanup existing errata file.
rm -f $REPOMDDIR/*updateinfo.xml.gz

#check if repo already has updateinfo publish -> cleanup
if [[ `grep updateinfo $REPOMDDIR/repomd.xml 2>/dev/null` ]]; then
    echo -en "\tCleaning up exsiting repository information..."
    /usr/bin/modifyrepo --remove updateinfo.xml $REPOMDDIR/repomd.xml &>/dev/null
    echo -e "Done"
fi
#import updateinfo into repo.
echo -en "\tPublishing repository information..."
#RHEL5 seems to only download the gzip version so we will extract before import
cp -f $YUMCACHEFILE /tmp/updateinfo.xml.gz
gzip -fd /tmp/updateinfo.xml.gz
/usr/bin/modifyrepo /tmp/updateinfo.xml $REPOMDDIR &>/dev/null
echo -e "Done"
