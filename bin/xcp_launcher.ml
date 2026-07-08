let qemu_system = "qemu-system-x86_64"

let main out proc_mgr =
  (* Eio.Fiber.all takes a list of function unit->unit *)
  List.map
    (fun vm ->
      fun () ->
       let cmd = qemu_system :: Vm.vm_to_args vm in
       Eio.Flow.copy_string
         ("== Starting " ^ vm.name ^ "==\n" ^ String.concat " " cmd ^ "\n\n")
         out;
       Eio.Process.run proc_mgr cmd)
    Conf.vms
  |> Eio.Fiber.all

let () =
  Eio_main.run (fun env ->
      main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
