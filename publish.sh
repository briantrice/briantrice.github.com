#! /bin/sh
 
SITE='_site'
FTP_SITE='jonasboner.com'
 
cd $SITE
echo 'Stepping into' $SITE
rm ./publish.sh
rm -rf bin
 
echo '===================================================='
echo 'Uploading site:' $FTP_SITE
echo '===================================================='
lftp -d -u $FTP_USER,$FTP_PASSWORD $FTP_SITE<<END_SCRIPT
mirror -n -R . /public_html
quit
 
echo '===================================================='
echo 'Site published'