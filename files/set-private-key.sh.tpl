mkdir -p /home/azureuser/.ssh
chmod 700 /home/azureuser/.ssh
echo '${private_key_openssh}' > /home/azureuser/.ssh/id_rsa
ret=$?
chmod 600 /home/azureuser/.ssh/id_rsa
chown -R azureuser:azureuser /home/azureuser/.ssh/
exit $ret
