#!/bin/bash

echo "Backup existing cmd1.php to /root/patch_1.62/cmd1.php.bak"
mv /usr/local/edomi/main/queuecmd/cmd1.php /root/patch_1.62/cmd1.php.bak

echo "Copy patched version to /usr/local/edomi/main/queuecmd/"
cp /root/patch_1.62/cmd1.php /usr/local/edomi/main/queuecmd/

echo "Fixing permissions"
chmod 777 /usr/local/edomi/main/queuecmd/cmd1.php

echo "Done"
