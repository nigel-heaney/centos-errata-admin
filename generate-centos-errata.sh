#!/bin/bash
#  generate-centos-errata  : This script will coordinate the steps necessary to download and process the spacewalk erratafile as maintained by 
#                            Sid Meier. The output of which will be yum repo compatible errata files which we can then use for yum security updates.
#                
#   Version      Author          Date        Description      
#     0.1        Nigel Heaney    06-07-2016  Initial version
#

BASEPATH=/opt/centos-errata
ERRATAURL='https://cefs.steve-meier.de/errata.latest.xml'

#MAIN
if [ ! $USER == root ]; then 
    echo "ERROR - This script must be run as root!"
    exit 1
fi

cd $BASEPATH
[ ! -e $BASEPATH/archive ] && mkdir -p -m 755 $BASEPATH/archive

#Move old errata file to old so we can compare for changes
mv -f $BASEPATH/errata.latest.*.xml $BASEPATH/archive 2>/dev/null
if [ -e $BASEPATH/errata.latest.xml ]; then 
    oldname="errata.latest."`stat -c %y $BASEPATH/errata.latest.xml | cut -d' ' -f 1`".xml"
    cp -pr $BASEPATH/errata.latest.xml $oldname
    oldsha512=`sha512sum $oldname  | cut -d' ' -f 1`
else
    touch $BASEPATH/errata.latest.xml
fi

#download the spacewalk errate file using the option as specified here https://cefs.steve-meier.de/
wget -qN $ERRATAURL -O $BASEPATH/errata.latest.xml
newsha512=`sha512sum errata.latest.xml  | cut -d' ' -f 1`

#check if the files have changed, no changes = no work.
if [ $oldsha512 == $newsha512 ]; then
    #nothing to generate so give up.
    echo "INFO: Errata has not changed since previous run, abandoning generation..."
    exit 2
fi

#Lets move any Centos XML files into archive 
mv -f $BASEPATH/CentOS*updateinfo.xml $BASEPATH/archive 2>/dev/null

#Lets generate the xml files.
$BASEPATH/centos-generate-updateinfo.py $BASEPATH/errata.latest.xml

#Cleanup
mv -f $BASEPATH/$oldname $BASEPATH/archive

#Housekeeping
#Compress all files in archive
find $BASEPATH/archive -name '*.xml' -exec xz -f9 {} \;
#Delete files older than 90 days (maintain ~50mb of legacy data)
find $BASEPATH/archive -mtime +90 -type f -name '*.xz' -delete
