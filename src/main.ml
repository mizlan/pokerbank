open Containers
module C = Oidc.SimpleClient
module Db = Database

let ( let* ) = Lwt.bind

let dream_render = function
  | Ok x -> Dream.json x
  | Error e ->
      Dream.json ~status:`Bad_Request (Printf.sprintf {|{"error": "%s"}|} e)

let dream_query_string req key =
  match Dream.query req key with
  | None -> Lwt.return (Error ("missing string query parameter " ^ key))
  | Some x -> Lwt.return (Ok x)

let dream_query_int req key =
  let open Option.Infix in
  match Dream.query req key >>= Int.of_string with
  | None -> Lwt.return (Error ("missing int query parameter " ^ key))
  | Some x -> Lwt.return (Ok x)

let routes =
  [
    Dream.get "/login" (fun req ->
        Dream.redirect req (Uri.to_string Auth.auth_uri));
    Dream.get "/auth/callback" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* code = dream_query_string req "code" in
          let* tok = Auth.get_token code in
          Auth.get_userinfo tok
          (* TODO: store user info in session and redirect *)
        in
        dream_render v);
    Dream.post "/create_session" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* name = dream_query_string req "name" in
          let+ i = Dream.sql req (Db.create_session ~name) in
          Int.to_string i
        in
        dream_render v);
    Dream.post "/set_bank" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* username = dream_query_string req "username" in
          let+ () = Dream.sql req (Db.set_bank ~session_id ~username) in
          "success"
        in
        dream_render v);
    Dream.post "/transact" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* username = dream_query_string req "username" in
          let* amount = dream_query_int req "amount" in
          let+ () = Dream.sql req (Db.transact ~session_id ~username ~amount) in
          "success"
        in
        dream_render v);
  ]

let () =
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.router routes
