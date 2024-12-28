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

module F = struct
  let player_id = Dream.new_field ~name:"player_id" ()
  let session_id = Dream.new_field ~name:"session_id" ()

  let get_player_id req =
    Option.get_exn_or "get_player_id must be called from within a player route"
      (Dream.field req player_id)
end

module E = struct
  let mk_error status msg =
    Dream.json ~status (Printf.sprintf {|{"error": "%s"}|} msg)

  let internal = mk_error `Internal_Server_Error
  let unauthorized = mk_error `Unauthorized
end

let auth_player_middleware next_handler req =
  match Dream.session_field req "player_id" with
  | None -> E.unauthorized "not signed in"
  | Some player_id -> (
      let player_id = Int.of_string player_id in
      match player_id with
      | None -> E.unauthorized "malformed player_id"
      | Some player_id ->
          Dream.set_field req F.player_id player_id;
          next_handler req)

let auth_bank_middleware next_handler req =
  match Dream.field req F.player_id with
  | None -> E.unauthorized "no player_id"
  | Some player_id -> (
      let* session_id = Dream.sql req (Db.get_session_of_player ~player_id) in
      match session_id with
      | Error msg -> E.internal msg
      | Ok session_id -> (
          match session_id with
          | None -> E.unauthorized "not a bank player"
          | Some session_id ->
              Dream.set_field req F.session_id session_id;
              next_handler req))

let bank_routes =
  [
    Dream.post "/api/set_bank" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* player_id = dream_query_int req "player_id" in
          let+ () = Dream.sql req (Db.set_bank ~session_id ~player_id) in
          "success"
        in
        dream_render v);
    Dream.post "/api/transact" (fun req ->
        let* v =
          let open Lwt_result.Syntax in
          let* session_id = dream_query_int req "session_id" in
          let* player_id = dream_query_int req "player_id" in
          let* amount = dream_query_int req "amount" in
          let+ () =
            Dream.sql req (Db.transact ~session_id ~player_id ~amount)
          in
          "success"
        in
        dream_render v);
  ]

let player_routes =
  [
    Dream.scope "/" [ auth_bank_middleware ] bank_routes;
    Dream.get "/api/ping" (fun _ -> Dream.json {|{"message": "pong"}|});
    Dream.get "/api/session_info" (fun req ->
        let player_id = F.get_player_id req in
        let* v =
          let open Lwt_result.Syntax in
          let+ session_id =
            Dream.sql req (Db.get_session_of_player ~player_id)
          in
          match session_id with
          | None -> "null"
          | Some session_id -> Int.to_string session_id
        in
        dream_render v);
    Dream.post "/api/create_session" (fun req ->
        let player_id = F.get_player_id req in
        let* v =
          let open Lwt_result.Syntax in
          let* name = dream_query_string req "name" in
          let+ i = Dream.sql req (Db.create_session ~name ~player_id) in
          Int.to_string i
        in
        dream_render v);
  ]

let routes =
  [
    (* Currently, all routes are prefixed with /api, and there is
       nothing else but /api. This is for future proofing and in case
       I ever decided to have both the frontend and backend on the exact same
       domain *)
    Dream.scope "/" [ auth_player_middleware ] player_routes;
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
              let+ player_id =
                Dream.sql req (Db.register_player ~email ~name)
              in
              let open Lwt.Syntax in
              let* () = Dream.invalidate_session req in
              let* () =
                Dream.set_session_field req "player_id"
                  (Int.to_string player_id)
              in
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
    Dream.get "/api/logout" (fun req ->
        let* () = Dream.invalidate_session req in
        Dream.json {|{"message": "logged out"}|});
  ]

let () =
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.memory_sessions @@ Dream.router routes
