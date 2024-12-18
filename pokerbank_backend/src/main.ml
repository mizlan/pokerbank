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
  | None -> Lwt.return_error ("missing string query parameter " ^ key)
  | Some x -> Lwt.return_ok x

let dream_query_int req key =
  let open Option.Infix in
  match Dream.query req key >>= Int.of_string with
  | None -> Lwt.return_error ("missing int query parameter " ^ key)
  | Some x -> Lwt.return_ok x

let routes =
  [
    (* Currently, all routes are prefixed with /api, and there is
       nothing else but /api. This is for future proofing and in case
       I ever decided to have both the frontend and backend on the exact same
       domain *)
    Dream.get "/api/notifs" (fun req ->
        let email = Dream.session_field req "email" in
        match email with
        (* TODO *)
        | None -> Dream.html "<a href='/login'>Login</a>"
        | Some email ->
            let name = Dream.session_field req "name" in
            Dream.json
              (Printf.sprintf {|{"email": "%s", "name": "%s"}|} email
                 (Option.get_or ~default:"no name" name)));
    Dream.get "/api/logout" (fun req ->
        let* () = Dream.invalidate_session req in
        Dream.redirect req "/");
    Dream.get "/api/login" (fun req ->
        let state = Auth.generate_state () in
        let* resp =
          Auth.make_auth_uri state |> Uri.to_string |> Dream.redirect req
        in
        Dream.set_cookie resp req "google_oauth_state" state;
        Lwt.return resp);
    Dream.get "/api/auth/callback" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* code = dream_query_string req "code" in
          let* reported_state = dream_query_string req "state" in
          let recorded_state = Dream.cookie req "google_oauth_state" in
          match recorded_state with
          | None -> Lwt.return_error "oauth: missing state"
          | Some state when String.(state <> reported_state) ->
              Lwt.return_error "oauth: state mismatch"
          | _ ->
              let* tok = Auth.get_token code in
              let* { email; name } = Auth.get_userinfo tok in
              let+ () = Dream.sql req (Db.register_player ~email ~name) in
              let open Lwt.Syntax in
              let* () = Dream.invalidate_session req in
              let random_str = Auth.generate_state () in
              let* () = Dream.set_session_field req "ssid" random_str in
              let* () = Dream.set_session_field req "email" email in
              let* () = Dream.set_session_field req "name" name in
              Lwt.return ()
        in
        let* resp =
          match v with
          | Ok _ -> Dream.redirect req "http://localhost:3000"
          | Error e ->
              Dream.json ~status:`Bad_Request
                (Printf.sprintf {|{"error": "%s"}|} e)
        in
        Dream.drop_cookie resp req "google_oauth_state";
        Lwt.return resp);
    Dream.post "/api/create_session" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* name = dream_query_string req "name" in
          let+ i = Dream.sql req (Db.create_session ~name) in
          Int.to_string i
        in
        dream_render v);
    Dream.post "/api/set_bank" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* email = dream_query_string req "email" in
          let+ () = Dream.sql req (Db.set_bank ~session_id ~email) in
          "success"
        in
        dream_render v);
    Dream.post "/api/transact" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* email = dream_query_string req "email" in
          let* amount = dream_query_int req "amount" in
          let+ () = Dream.sql req (Db.transact ~session_id ~email ~amount) in
          "success"
        in
        dream_render v);
  ]

let () =
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.memory_sessions @@ Dream.router routes
