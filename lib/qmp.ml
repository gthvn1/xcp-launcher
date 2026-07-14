let connect net sock_path =
  let addr = `Unix sock_path in
  let get_capabilities = {|{"execute":"qmp_capabilities"}|} ^ "\n" in
  let query_status = {|{"execute":"query-status"}|} ^ "\n" in

  Eio.Switch.run @@ fun sw ->
  let flow = Eio.Net.connect ~sw net addr in
  let buf = Eio.Buf_read.of_flow ~max_size:512 flow in

  Eio.traceln "First we need to read the greeting from Qemu";
  Eio.traceln "Got: %s\n" (Eio.Buf_read.line buf);

  Eio.traceln "now we can send the get_capabilities";
  Eio.Flow.copy_string get_capabilities flow;
  Eio.traceln "Got: %s\n" (Eio.Buf_read.line buf);

  Eio.traceln "and query status of the VM";
  Eio.Flow.copy_string query_status flow;
  Eio.traceln "Got: %s\n" (Eio.Buf_read.line buf)
