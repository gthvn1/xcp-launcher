let connect net out sock_path =
  ignore net;
  Eio.Flow.copy_string (Printf.sprintf "todo: open %s\n" sock_path) out
