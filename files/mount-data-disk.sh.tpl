if [ ! -d "/data" ]; then
  yes | mkfs -t ext4 /dev/sdc
  mkdir -p /data
  echo "/dev/sdc /data ext4 defaults,nofail,noatime,nodelalloc 0 2" >> /etc/fstab
  mount -a
  ret=$?
  chown -R azureuser:azureuser /data
  exit $ret
fi
exit 0
