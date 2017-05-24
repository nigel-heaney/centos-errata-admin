#!/bin/bash
#  publish-rhel-errata  : This script will publish the updateinfo.xml into the relevant rhel repo.  This will then
#                         allow server to pull the errata DB and all machines to identify what missing security
#                         updates they are missing.
#
#   Version      Author          Date        Description
#     0.1        Nigel Heaney    06-07-2016  Initial version
#

BASEPATH=/root/scripts
YUMBASEPATH=/var/www/html/repo/rhel-7-server-rpms
REPOMDDIR=/var/www/html/repo/rhel-7-server-rpms/Packages/repodata
YUMCACHEFILE=/var/cache/yum/x86_64/7Server/rhel-7-server-rpms/gen/updateinfo.xml
RELEASE=7

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
yum updateinfo &> /dev/null
echo -e "Done"

if [ ! -e $YUMCACHEFILE ]; then
    echo "ERROR - Cannot locate $YUMCACHEFILE"
    exit 1
fi

#problem - reposync does not mirror files, so it will not delete files so will need to force the deletion of any potentially old updateinfo files
rm -f $YUMBASEPATH/$u/updates/x86_64/repodata/*updateinfo.xml.gz

#check if repo already has updateinfo publish -> cleanup
if [[ `grep updateinfo $REPOMDDIR/repomd.xml 2>/dev/null` ]]; then
    echo -en "\tCleaning up exsiting repository information..."
    modifyrepo --remove updateinfo.xml $REPOMDDIR/repomd.xml &>/dev/null
    echo -e "Done"
fi
#import updateinfo into repo.
echo -en "\tPublishing repository information..."
/usr/bin/modifyrepo $YUMCACHEFILE $REPOMDDIR &>/dev/null
echo -e "Done"
