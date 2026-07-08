module Vm = Xcp.Vm
module Conf = Xcp.Conf

let qemu_system = "qemu-system-x86_64"

let main out proc_mgr =
  (* Eio.Fiber.all takes a list of function unit->unit *)
  List.map
    (fun vm ->
      fun () ->
       let cmd = qemu_system :: Vm.vm_to_args vm in
       Eio.Flow.copy_string
         ("== Starting " ^ Vm.name vm ^ " ==\n" ^ String.concat " " cmd ^ "\n\n")
         out;
       try Eio.Process.run proc_mgr cmd
       with _ex -> Printf.eprintf "%s failed\n" (Vm.name vm))
    Conf.vms
  |> Eio.Fiber.all

let () =
  (* TODO: group checks, and pass vm_dir maybe *)
  if Option.is_none (Sys.getenv_opt "HOME") then (
    Printf.eprintf "$HOME is not set, cannot check disks and other files";
    exit 1);
  match Vm.check_host_ports Conf.vms with
  | Ok () ->
      Eio_main.run (fun env ->
          main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
  | Error lst ->
      Printf.eprintf "Following ports host are duplicated: %s\n"
        (String.concat " " (List.map string_of_int lst));
      exit 1
