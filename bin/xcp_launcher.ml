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
  (* TODO: maybe pass vm_dir because it is recomputed in sanity checks *)
  if Option.is_none (Sys.getenv_opt "HOME") then (
    Printf.eprintf "$HOME is not set, cannot check disks and other files";
    exit 1);
  match Vm.sanity_checks Conf.vms with
  | Ok () ->
      Eio_main.run (fun env ->
          main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
  | Error lst ->
      List.iter
        (fun e ->
          match e with
          | Vm.Duplicated_port p ->
              Printf.eprintf "Host port %d is duplicated\n" p
          | Vm.Missing_file f -> Printf.eprintf "File %s not found\n" f
          | Vm.Tap_not_found t -> Printf.eprintf "Tap %s not found\n" t)
        lst;
      exit 1
