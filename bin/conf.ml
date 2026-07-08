let my_vm : Vm.vm =
  {
    name = "my_vm";
    memory = 4096;
    cores = 4;
    disks = [ { ty = Vm.Qcow2; path = "disk.qcow2" } ];
    redirections =
      [
        { ty = Vm.Tcp; port_host = 8022; port_vm = 22 };
        { ty = Vm.Tcp; port_host = 8443; port_vm = 443 };
        { ty = Vm.Tcp; port_host = 8080; port_vm = 80 };
      ];
  }
