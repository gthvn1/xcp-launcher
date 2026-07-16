(* This launcher is our first experiment: it loads a hardcoded pool
   (Pool_as_code.my_pool) and starts every host concurrently with Eio.

   We originally reached for Eio because we wanted a REPL to interact with
   hosts and their guest domains. It turned out that utop itself makes a great
   REPL: with `dune utop`, we can load a pool (from code or from an s-expression
   file) and drive it directly through the Pool functions.

   So interactive management now happens in utop, and this file is kept only as
   a record of that first Eio-based attempt. *)

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
  Pool.load Pool_as_code.my_pool;
  match Pool.sanity_checks () with
  | Ok () ->
      Eio_main.run (fun env ->
          main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
  | Error Pool.Empty_pool ->
      Printf.eprintf "Empty pool. You need to load a pool from s-exp or conf\n";
      exit 1
  | Error (Pool.Sanity lst) ->
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
      exit 2
  | Error (Pool.Runtime _) ->
      Printf.eprintf "runtime error are not expected during sanity checks";
      exit 3
