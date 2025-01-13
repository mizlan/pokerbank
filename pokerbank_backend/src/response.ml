let mk_error status msg =
  Dream.json ~status
    (Printf.sprintf {|{"status": "error", "message": "%s"}|} msg)

let internal = mk_error `Internal_Server_Error
let unauthorized = mk_error `Unauthorized
let bad_req = mk_error `Bad_Request
let forbidden = mk_error `Forbidden

let success msg =
  Dream.json (Printf.sprintf {|{"status": "success", "message": "%s"}|} msg)
