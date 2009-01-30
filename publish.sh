#! /bin/sh


SITE='_site'
FTP_SITE='jonasboner.com'
FTP_USER='jonabon7'
FTP_PASSWORD='7dc1c1d'

cd $SITE
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