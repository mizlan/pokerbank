open Cohttp
open Cohttp_lwt_unix

let ( let* ) = Lwt.bind

let get ?(headers = []) uri =
  let headers = Header.of_list headers in
  let* response, body = Client.get ~headers uri in
  let* body = Cohttp_lwt.Body.to_string body in
  Lwt.return (response, body)

let post ?(headers = []) ~body uri =
  let headers = Header.of_list headers in
  let body = Cohttp_lwt.Body.of_string body in
  let* response, body = Client.post ~headers ~body uri in
  let* body = Cohttp_lwt.Body.to_string body in
  Lwt.return (response, body)
