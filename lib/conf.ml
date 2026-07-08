let base_dir = "qemu_env/xcpng/8.3"

let vms : Vm.vm list =
  [
    Vm.make "vm1" ~base_dir ~uefi_vars:"nvram_vm1.fd"
      ~disks:[ Vm.qcow2 "disk_vm1.qcow2" ]
      ~redirections:
        [
          Vm.tcp ~host:8022 ~guest:22;
          Vm.tcp ~host:8443 ~guest:443;
          Vm.tcp ~host:8080 ~guest:80;
        ];
    Vm.make "vm2" ~base_dir ~uefi_vars:"nvram_vm2.fd"
      ~disks:[ Vm.qcow2 "disk_vm2.qcow2" ];
  ]
