open Containers
module C = Oidc.SimpleClient
module Db = Database

let ( let* ) = Lwt.bind
let ( let+ ) a b = Lwt.map b a
let ( let& ) b a = a b
let rr = Lwt.return (Ok ())

let dream_render = function
  | Ok x -> Dream.json x
  | Error e -> Dream.json (Printf.sprintf {|{"error": "%s"}|} e)

let dream_query_string request key =
  match Dream.query request key with
  | None -> Lwt.return (Error ("missing string query parameter " ^ key))
  | Some x -> Lwt.return (Ok x)

let dream_query_int request key =
  let open Option.Infix in
  match Dream.query request key >>= Int.of_string with
  | None -> Lwt.return (Error ("missing int query parameter " ^ key))
  | Some x -> Lwt.return (Ok x)

let () =
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.router
       [
         Dream.get "/login" (fun request ->
             Dream.redirect request (Uri.to_string Auth.auth_uri));
         Dream.get "/auth/callback" (fun request ->
             let* v =
               let open Lwt_result.Syntax in
               let* code = dream_query_string request "code" in
               let* tok = Auth.get_token code in
               Auth.get_userinfo tok
               (* TODO: store user info in session and redirect *)
             in
             dream_render v);
         Dream.post "/create_session" (fun request ->
             let* v =
               let open Lwt_result.Syntax in
               let* name = dream_query_string request "name" in
               let+ i = Dream.sql request (Db.create_session ~name) in
               Int.to_string i
             in
             dream_render v);
         Dream.post "/set_bank" (fun request ->
             let* v =
               let open Lwt_result.Syntax in
               let* session_id = dream_query_int request "session_id" in
               let* username = dream_query_string request "username" in
               let+ () =
                 Dream.sql request (Db.set_bank ~session_id ~username)
               in
               "success"
             in
             dream_render v);
         Dream.post "/transact" (fun request ->
             let* v =
               let open Lwt_result.Syntax in
               let* session_id = dream_query_int request "session_id" in
               let* username = dream_query_string request "username" in
               let* amount = dream_query_int request "amount" in
               let+ () =
                 Dream.sql request (Db.transact ~session_id ~username ~amount)
               in
               "success"
             in
             dream_render v);
       ]
