let base_dir = "qemu-env/xcpng/8.3"

let hosts : Host.t list =
  [
    Host.make "xcpng1" ~base_dir ~uefi_vars:"nvram_vm1.fd"
      ~disks:[ Host.qcow2 "disk_vm1.qcow2" ]
      ~redirections:
        [
          Host.tcp ~port_host:8022 ~port_guest:22;
          Host.tcp ~port_host:8443 ~port_guest:443;
          Host.tcp ~port_host:8080 ~port_guest:80;
        ];
    Host.make "xcpng2" ~base_dir ~uefi_vars:"nvram_vm2.fd"
      ~disks:[ Host.qcow2 "disk_vm2.qcow2" ];
  ]
