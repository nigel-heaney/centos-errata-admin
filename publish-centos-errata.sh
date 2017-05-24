#!/bin/bash
#  publish-centos-errata  : This script will publish the updateinfo.xml into the relevant centos repo.  This will then 
#                           allow server to pull the errata DB and all machines to identify what missing security 
#	                    updates they are missing.
#                
#   Version      Author          Date        Description      
#     0.1        Nigel Heaney    06-07-2016  Initial version
#
BASEPATH=/opt/centos-errata
YUMBASEPATH=/var/www/html/repo/CentOS
RELEASESEQ="5 7"       #What releases are we interested in? (5,6,7)

#MAIN 
if [ ! $USER == root ]; then 
    echo "ERROR - This script must be run as root!"
    exit 1
fi

if [ ! -e $YUMBASEPATH ]; then 
    echo "ERROR - Cannot locate $YUMBASEPATH!"
    exit 1
fi

cd $BASEPATH

for u in `seq $RELEASESEQ`; do
    repoopts=""
    echo -e "\nProcessing CentOS $u:"
    if [ ! -e $YUMBASEPATH/$u/updates/x86_64/repodata/repomd.xml ]; then
        echo "ERROR: Cannot locate $YUMBASEPATH/$u/updates/x86_64/repodata/repomd.xml ... Abandoning this update!"
        continue
    fi
    sourcefile=`ls -tr1 $BASEPATH/CentOS_${u}_*updateinfo.xml | head -1  2>/dev/null`
    if [ ! $sourcefile ]; then 
        echo "ERROR: Cannot locate a source file in $BASEPATH for CentOS $U ... Abandoning this update!"
        continue
    fi

    #check if repo already has updateinfo publish -> cleanup
    if [[ `grep updateinfo $YUMBASEPATH/$u/updates/x86_64/repodata/repomd.xml 2>/dev/null` ]]; then
        echo -en "\tCleaning up exsiting repository information..."
        /usr/bin/modifyrepo --remove updateinfo.xml $YUMBASEPATH/$u/updates/x86_64/repodata &>/dev/null
        rm -f $YUMBASEPATH/$u/updates/x86_64/repodata/*updateinfo.xml.gz
        echo -e "Done"
    fi
    if [ $u == 5 ]; then
	repoopts="-s sha"
    fi

    #import updateinfo into repo.
    echo -en "\tPublishing repository information..."
    cp -f $sourcefile $BASEPATH/updateinfo.xml
    /usr/bin/modifyrepo $repoopts updateinfo.xml $YUMBASEPATH/$u/updates/x86_64/repodata &>/dev/null
    echo -e "Done"

done


