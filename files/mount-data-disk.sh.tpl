if [ ! -d "/data" ]; then
  yes | mkfs -t ext4 /dev/disk/azure/scsi1/lun0
  mkdir -p /data
  echo "/dev/disk/azure/scsi1/lun0 /data ext4 defaults,nofail,noatime,nodelalloc 0 2" >> /etc/fstab
  mount -a
  ret=$?
  chown -R azureuser:azureuser /data
  exit $ret
fi
exit 0
