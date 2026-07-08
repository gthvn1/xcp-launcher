let qemu_system = "qemu-system-x86_64"

let main out proc_mgr =
  (* TODO: process all VMs, while testing only consider the first one *)
  let vm = List.hd Conf.vms in
  Eio.Process.run proc_mgr [ qemu_system; "--version" ];
  let cmd = String.concat " " (qemu_system :: Vm.vm_to_args vm) in
  Eio.Flow.copy_string (cmd ^ "\n") out

let () =
  Eio_main.run (fun env ->
      main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
