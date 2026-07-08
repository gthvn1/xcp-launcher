let vms : Vm.vm list =
  [
    {
      (* base_dir is relative to HOME, if HOME doesn't exist when VM is
         started the program will fail. *)
      base_dir = "qemu-env/xcpng/8.3";
      name = "vm1";
      memory = 4096;
      cores = 2;
      uefi_vars = "nvram_vm1.fd";
      disks = [ { ty = Vm.Qcow2; path = "disk_vm1.qcow2" } ];
      redirections =
        [
          { ty = Vm.Tcp; port_host = 8022; port_vm = 22 };
          { ty = Vm.Tcp; port_host = 8443; port_vm = 443 };
          { ty = Vm.Tcp; port_host = 8080; port_vm = 80 };
        ];
    };
    {
      base_dir = "qemu-env/xcpng/8.3";
      name = "vm2";
      memory = 4096;
      cores = 2;
      uefi_vars = "nvram_vm2.fd";
      disks = [ { ty = Vm.Qcow2; path = "disk_vm2.qcow2" } ];
      redirections = [];
    };
  ]
