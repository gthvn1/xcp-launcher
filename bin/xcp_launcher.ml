module Host = Xcp.Host
module Pool = Xcp.Pool

let qemu_system = "qemu-system-x86_64"

let main out proc_mgr =
  (* Eio.Fiber.all takes a list of function unit->unit *)
  List.map
    (fun h ->
      fun () ->
       let cmd = qemu_system :: Host.to_args h in
       Eio.Flow.copy_string
         ("== Starting " ^ Host.name h ^ " ==\n" ^ String.concat " " cmd
        ^ "\n\n")
         out;
       try Eio.Process.run proc_mgr cmd
       with _ex -> Printf.eprintf "%s failed\n" (Host.name h))
    Pool_as_code.my_pool
  |> Eio.Fiber.all

let () =
  Pool.from_sexp_file "conf/pool_example.sexp";
  match Pool.sanity_checks () with
  | Ok () ->
      Eio_main.run (fun env ->
          main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
  | Error lst ->
      List.iter
        (fun e ->
          match e with
          | Pool.Duplicated_port p ->
              Printf.eprintf "Host port %d is duplicated\n" p
          | Pool.Host_error (Host.Missing_file f) ->
              Printf.eprintf "File %s not found\n" f
          | Pool.Host_error (Host.Tap_not_found t) ->
              Printf.eprintf
                "Interface %s missing. Create it with:\n\
                \  sudo ip tuntap add %s mode tap user $(whoami)\n\
                \  sudo ip link set %s master virbr0\n\
                \  sudo ip link set %s up\n"
                t t t t)
        lst;
      exit 1
