#! /bin/sh
 
SITE='_site'
FTP_SITE='ftp.s1080089.crystone.net'
 
cd $SITE
echo 'Stepping into' $SITE
rm ./publish.sh
rm -rf bin
 
echo '===================================================='
echo 'Uploading site:' $FTP_SITE
echo '===================================================='
lftp -d -u $FTP_USER,$FTP_PASSWORD $FTP_SITE<<END_SCRIPT
mirror -n -R . /webspace/httpdocs/logs
quit
 
echo '===================================================='
echo 'Site published'