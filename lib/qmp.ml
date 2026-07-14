type 'flow t = { flow : 'flow; buf : Eio.Buf_read.t }

let send_command (params : 'flow t) (cmd : string) : string =
  Eio.Flow.copy_string cmd params.flow;
  Eio.Buf_read.line params.buf

let with_session net path f =
  let addr = `Unix path in
  Eio.Switch.run (fun sw ->
      let flow = Eio.Net.connect ~sw net addr in
      let buf = Eio.Buf_read.of_flow ~max_size:512 flow in
      let params = { flow; buf } in
      let get_capabilities = {|{"execute":"qmp_capabilities"}|} ^ "\n" in

      Eio.traceln "First we need to read the greeting from Qemu";
      Eio.traceln "Got: %s\n" (Eio.Buf_read.line params.buf);

      Eio.traceln "Now we can send the get_capabilities";
      Eio.traceln "Got: %s\n" (send_command params get_capabilities);

      Eio.traceln "Ready to run any command...\n";
      f params)
