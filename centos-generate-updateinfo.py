#!/usr/bin/python
"""
   centos-generate-updateinfo:  This program will convert a spacewalk errata catalogue file into yum repo compatible catalogues which 
                                can then be inserted into local yum repos.  This will then permit patching based on security notices and 
                                critical flaws.
                
   Version      Author          Date         Description      
     0.1        Nigel Heaney    01-7-2016    Initial version
"""

import os
import time
import re
import xml.sax
import sys

class XMLHandler( xml.sax.ContentHandler ):
    ''' 
        XML handler class to process the spacewalk errata file.
    '''
    def __init__(self):
        self.debug = 0
        self.tag = ""
        self.SAtag = "CE"           #This will be the beginning of each security announcement as per the source data
        self.id = ""                #this will be the SA tag
        self.updatefrom = "someone@example.test"
        self.status = "Stable"
        self.severity = ""
        self.type = ""              #Security/BugFix/Enhancement
        self.version = "1"          #Looks to be meaningless from our perspective
        self.title = ""             #friendly name of patch
        self.release = ""           #This is the OS release tag "CentOS 6"
        self.issuedate = ""         #err lets think
        self.references = ""        #This will be a list of references (url's that describe update and reasoning etc)
        self.description = self.title
        self.packages = ""          #Converted to string because of buffering issues and will split manually when writing to file. list of rpms which we will process in more detail when writing to the xml file.
        self.header = '<?xml version="1.0" encoding="UTF-8"?>\n<updates>\n'
        self.footer = '</updates>'
        self.filename_prefix = "CentOS_"
        self.filename_path = "./"
        self.datenow = time.strftime("%Y-%m-%d")
        self.filesout = {}      #list of filehandles for each version of Centos.


    def startElement(self, tag, attributes):
        #Check if we have found an opening tag for a security announcement so lets start collating information
        self.tag = tag
        if tag.startswith(self.SAtag):
            self.id = tag
            self.type = attributes['type']
            self.title = attributes['synopsis']
            self.issuedate = attributes['issue_date']
            self.references = attributes['references']
            if tag.startswith('CESA'): 
                if attributes.has_key('severity'):
                    self.severity=attributes['severity']
                else:
                    self.severity="Moderate"
                self.type="security"
            elif tag.startswith('CEBA'):
                self.type="bugfix"
            elif tag.startswith('CEEA'):
                self.type="enhancement"
                
        if self.debug: 
            print "TAG:", tag
            print "Attributes:", attributes.keys()
            print "Items:", attributes.items()
            

    def endElement(self, tag):
        if tag.startswith(self.SAtag):
            if self.debug:
                print "ID:", self.id
                print "Type:", self.type
                print "Title:", self.title
                print "Severity:", self.severity
                print "IssueDate:", self.issuedate
                print "References:", self.references
                print "Release:", self.release
                print "Packages:", self.packages
                print "\n- - - E N D - - -\n"
            #write the record out.
            self.process_record()
            #Now reset values so we can process the next record
            self.id = ""
            self.status = "Stable"
            self.type = ""            
            self.version = "1"        
            self.title = ""           
            self.release = ""         
            self.issuedate = ""       
            self.references = ""
            self.severity = ""
            self.packages = ""

    def characters(self, content):
        if self.tag == "os_arch":
            return
        elif self.tag == "os_release":
            if not self.release: self.release = content
        elif self.tag == "packages":
            if not content.startswith(" ") and not content.startswith("\n") : 
                #self.packages.append(content)
                #Bug - turns out that once a file gets to a certain size it will be buffered and "characters" may only return some of the data of a tag and its upto you to stick it back together
                #      which is annoying.  Might need to use a different parser in the future but for now pakcages is now a string and we concatenate all the packages
                #      into a long string and split later. Luckily release is 1 character in size so it will be impossible to split that up...we hope!

                #if rpm is on the end then its finsished so add comma
                if content.endswith("rpm"):
                    self.packages += content + ","
                else:
                    self.packages += content
            

    def process_record(self):
        '''This will check if the Centos file has been initialised and write the record'''
        #Lets check if we have encountered this OS Release, if not then open file and write record, otherwise append data.
        if self.filesout.has_key(self.release):
            self.write_record()
        else:
            self.filesout[self.release] = open(self.filename_path + self.filename_prefix + self.release + "_" + self.datenow + "_updateinfo.xml", 'w')
            #initialise the file
            self.filesout[self.release].write(self.header)
            self.write_record()
            
            
    def write_record(self):
        '''here we will just write all the records out to the xml file in the correct format.'''
        #update tag with author, status, type and version
        self.filesout[self.release].write('  <update from="' + self.updatefrom + '" status="' + self.status + '" type="' + self.type + '" version="' + self.version + '">\n')
        self.filesout[self.release].write('    <id>' + self.id + '</id>\n')
        self.filesout[self.release].write('    <title>' + self.title + " - " + self.references.rstrip().split(" ")[0] + '</title>\n')
        if self.severity:
            self.filesout[self.release].write('    <severity>' + self.severity + '</severity>\n')
            
        self.filesout[self.release].write('    <release>CentOS ' + self.release + '</release>\n')
        self.filesout[self.release].write('    <issued date="' + self.issuedate + '"/>\n')
        self.filesout[self.release].write('    <references>\n')
        for i in self.references.rstrip().split(" "):
            self.filesout[self.release].write('      <reference href="' + i +  '" type="CELSA"/>\n')
        self.filesout[self.release].write('    </references>\n')
        self.filesout[self.release].write('    <description>' + self.title + '</description>\n')
        self.filesout[self.release].write('    <pkglist>\n')
        self.filesout[self.release].write('      <collection short="EL' + self.release + '">\n')
        self.filesout[self.release].write('        <name>CentOS ' + self.release + '</name>\n')
        
        #trim off the last comma
        self.packages=self.packages[:-1]
        for i in self.packages.split(","):
                                                    #i = libuser-0.56.13-8.el6_7.i686.rpm
            if i.endswith("src.rpm"): continue      #ignore source rpms because we can
            pname = re.sub('\.rpm', '',i)           #libuser-0.56.13-8.el6_7.i686
            arch = re.sub('^.*\.', '', pname)    
            pname = re.sub("." + arch, '', pname)   #libuser-0.56.13-8.el6_7
            release = re.sub('^.*-', '', pname)
            pname = re.sub("-"+release, '', pname)  #libuser-0.56.13
            version = re.sub('^.*-', '', pname)
            pname = re.sub("-" +version, '', pname) #libuser
            if self.debug:
                print "RPM         :", i
                print "Package name:", pname
                print "Version     :", version
                print "Release     :", release
                print "Arch        :", arch, "\n"
            #write the package definition
            self.filesout[self.release].write('        <package arch="' + arch +  '" epoch="0" name="' + pname + '" release="' + release + '" src="" version="' + version + '">\n')
            self.filesout[self.release].write('          <filename>' + i +  '</filename>\n')
            self.filesout[self.release].write('        </package>\n')
        self.filesout[self.release].write('      </collection>\n')
        self.filesout[self.release].write('    </pkglist>\n')
        self.filesout[self.release].write('  </update>\n')
            
    def close_files(self):            
        '''write footer to close remaining open tags and close the file handles.'''
        for i in self.filesout.keys():
            self.filesout[i].write(self.footer)
            self.filesout[i].close()

    def usage(self):            
        '''A little help.'''
        print "Usage:  centos-generate-updateinfo <location of the errara catalogue xml file>"
        print "\n        e.g. centos-generate-updateinfo errata.latest.xml"
        
            
if ( __name__ == "__main__"):
    parser = xml.sax.make_parser()
    # turn off namepsaces
    parser.setFeature(xml.sax.handler.feature_namespaces, 0)
    # override the default ContextHandler
    Handler = XMLHandler()

    #Lets test the errata file exists 
    if len(sys.argv) < 2:
        print "ERROR you must supply the location to the errata file...\n"
        Handler.usage()
        exit(1)
    else:
        if not os.path.isfile(sys.argv[1]):
            print "ERROR problem with erratafile, please check location and permissions...\n"
            Handler.usage()
            exit(2)
    
    parser.setContentHandler( Handler )
    parser.parse(sys.argv[1])
    Handler.close_files()
