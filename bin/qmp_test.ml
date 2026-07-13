let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Unix socket is expected as argument";
    exit 1);
  let sock_path = Sys.argv.(1) in

  Eio_main.run (fun env ->
      Xcp.Qmp.connect (Eio.Stdenv.net env) (Eio.Stdenv.stdout env) sock_path)
