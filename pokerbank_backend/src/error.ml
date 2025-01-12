  let mk_error status msg =
    Dream.json ~status (Printf.sprintf {|{"error": "%s"}|} msg)

  let internal = mk_error `Internal_Server_Error
  let unauthorized = mk_error `Unauthorized
  let bad_req = mk_error `Bad_Request
