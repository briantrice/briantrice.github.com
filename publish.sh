#! /bin/sh


SITE='_site'
FTP_SITE='jonasboner.com'
FTP_USER='jonabon7'
FTP_PASSWORD='7dc1c1d'
FTP_SITE_DIR='public_html'

jekyll

cd $SITE
rm ./publish.sh
rm -rf bin

echo '===================================================='
echo 'Uploading site:' $FTP_SITE
echo '===================================================='
lftp -d -u $FTP_USER,$FTP_PASSWORD $FTP_SITE<<END_SCRIPT
cd $FTP_SITE_DIR
mirror -n -R . /
#put -R .
put ../../css
quit

echo '===================================================='
echo 'Site published'