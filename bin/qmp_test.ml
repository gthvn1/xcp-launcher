module Qmp = Xcp.Qmp

let () =
  let query_status = {|{"execute":"query-status"}|} ^ "\n" in
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Unix socket is expected as argument";
    exit 1);
  let sock_path = Sys.argv.(1) in

  Eio_main.run (fun env ->
      Qmp.with_session (Eio.Stdenv.net env) sock_path (fun t ->
          let resp = Xcp.Qmp.send_command t query_status in
          Eio.traceln "Got: %s\n" resp))
