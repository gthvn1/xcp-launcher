let base_dir = "qemu-env/xcpng/8.3"

let hosts : Host.t list =
  [
    Host.make "xcpng1" ~base_dir ~uefi_vars:"nvram_vm1.fd"
      ~disks:[ Host.qcow2 "disk_vm1.qcow2" ]
      ~redirections:
        [
          Host.tcp ~host:8022 ~guest:22;
          Host.tcp ~host:8443 ~guest:443;
          Host.tcp ~host:8080 ~guest:80;
        ];
    Host.make "xcpng2" ~base_dir ~uefi_vars:"nvram_vm2.fd"
      ~disks:[ Host.qcow2 "disk_vm2.qcow2" ];
  ]
