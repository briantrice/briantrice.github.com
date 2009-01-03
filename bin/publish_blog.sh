#! /bin/sh
MIRROR_SCRIPT='./curlmirror.pl'
TARGET_SITE='http://jboner.github.com'
FTP_SITE='jonasboner.com'
FTP_USER='jonabon7'
FTP_PASSWORD='7dc1c1d'
FTP_SITE_DIR='public_html/jekyll'

echo '====================================='
echo 'Grabbing site:' $TARGET_SITE
echo '===================================================='
$MIRROR_SCRIPT -v -o . $TARGET_SITE

echo '===================================================='
echo 'Uploading site:' $FTP_SITE
echo '===================================================='
ncftp -u $FTP_USER -p $FTP_PASSWORD $FTP_SITE<<END_SCRIPT
cd $FTP_SITE_DIR
put -R .
quit

echo '===================================================='
echo 'Site mirrored successfully'