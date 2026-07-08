let qemu_system = "qemu-system-x86_64"

let main out proc_mgr =
  Eio.Process.run proc_mgr [ qemu_system; "--version" ];
  let cmd = String.concat " " (qemu_system :: Vm.vm_to_args Conf.my_vm) in
  Eio.Flow.copy_string (cmd ^ "\n") out

let () =
  Eio_main.run (fun env ->
      main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
