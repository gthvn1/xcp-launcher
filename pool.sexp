(
 ((description "XCP-ng host1 poolA")
  (base_dir qemu-env/xcpng/8.3) (name xcpng1) (memory 4096) (cores 2)
  (uefi_vars nvram_vm1.fd) (network User)
  (disks (((ty Qcow2) (path disk_vm1.qcow2))))
  (redirections
   (((ty Tcp) (port_host 8022) (port_vm 22))
    ((ty Tcp) (port_host 8443) (port_vm 443))
    ((ty Tcp) (port_host 8080) (port_vm 80)))))
 ((description "XCP-ng host2 poolA")
  (base_dir qemu-env/xcpng/8.3) (name xcpng2) (memory 4096) (cores 2)
  (uefi_vars nvram_vm2.fd) (network User)
  (disks (((ty Qcow2) (path disk_vm2.qcow2)))) (redirections ())))
