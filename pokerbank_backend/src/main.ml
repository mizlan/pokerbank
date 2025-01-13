open Containers
module C = Oidc.SimpleClient
module Db = Database
module M = Middleware
module R = Response
open Lwt.Syntax

let dream_render v =
  let* p = v in
  Result.catch ~ok:Fun.id ~err:Fun.id p

let dream_render_err r = Lwt_result.map_error R.bad_req r
let dream_render_internal_err r = Lwt_result.map_error R.internal r
let dream_sql_or_err req f = Dream.sql req f |> dream_render_err

let dream_query_string req key =
  match Dream.query req key with
  | None ->
      Lwt.return_error (R.bad_req ("missing string query parameter " ^ key))
  | Some x -> Lwt.return_ok x

let dream_query_int req key =
  let open Option.Infix in
  match Dream.query req key >>= Int.of_string with
  | None -> Lwt.return_error (R.bad_req ("missing int query parameter " ^ key))
  | Some x -> Lwt.return_ok x

let bank_routes =
  [
    Dream.post "/api/set_bank" (fun req ->
        dream_render
        @@
        let open Lwt_result.Syntax in
        let* session_id = dream_query_int req "session_id" in
        let* player_id = dream_query_int req "player_id" in
        let+ () = dream_sql_or_err req (Db.set_bank ~session_id ~player_id) in
        R.success "set bank");
    Dream.post "/api/transact" (fun req ->
        dream_render
        @@
        let open Lwt_result.Syntax in
        let* session_id = dream_query_int req "session_id" in
        let* player_id = dream_query_int req "player_id" in
        let* amount = dream_query_int req "amount" in
        let+ () =
          dream_sql_or_err req (Db.transact ~session_id ~player_id ~amount)
        in
        R.success "transacted");
  ]

let player_routes =
  [
    Dream.scope "/" [ M.auth_bank_middleware ] bank_routes;
    Dream.get "/api/ping" (fun _ -> R.success "pong");
    Dream.get "/api/session_info" (fun req ->
        dream_render
        @@
        let player_id = M.F.get_player_id req in
        let open Lwt_result.Syntax in
        let+ txs = dream_sql_or_err req (Db.get_transactions ~player_id) in
        Dream.json
          (* TODO is there a nicer way of doing this? *)
          (Yojson.Safe.to_string
             (`List (txs |> List.map Db.yojson_of_player_transactions))));
    Dream.post "/api/create_session" (fun req ->
        dream_render
        @@
        let player_id = M.F.get_player_id req in
        let open Lwt_result.Syntax in
        let* name = dream_query_string req "name" in
        let+ i = dream_sql_or_err req (Db.create_session ~name ~player_id) in
        R.success (Printf.sprintf "created session %d" i));
  ]

let routes =
  [
    (* Currently, all routes are prefixed with /api, and there is
       nothing else but /api. This is for future proofing and in case
       I ever decided to have both the frontend and backend on the exact same
       domain *)
    Dream.scope "/" [ M.auth_player_middleware ] player_routes;
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
          | None -> Lwt.return_error (R.unauthorized "oauth: missing state")
          | Some state when String.(state <> reported_state) ->
              Lwt.return_error (R.unauthorized "oauth: state mismatch")
          | _ ->
              let* tok = Auth.get_token code |> dream_render_internal_err in
              let* { email; name } =
                Auth.get_userinfo tok |> dream_render_internal_err
              in
              let+ player_id =
                dream_sql_or_err req (Db.register_player ~email ~name)
              in
              let open Lwt.Syntax in
              let* () = Dream.invalidate_session req in
              let* () =
                Dream.set_session_field req "player_id"
                  (Int.to_string player_id)
              in
              Lwt.return_unit
        in
        let* resp =
          match v with
          | Ok _ -> Dream.redirect req "http://localhost:5173"
          | Error e -> e
        in
        Dream.drop_cookie resp req "google_oauth_state";
        Lwt.return resp);
    Dream.get "/api/logout" (fun req ->
        let* () = Dream.invalidate_session req in
        R.success "logged out");
  ]

let arg_private_admin = ref false

let private_admin_routes =
  [
    Dream.get "/test/autoauth" (fun req ->
        let* player_id = dream_query_string req "id" in
        let player_id = Result.get_or player_id ~default:"1" in
        let* () = Dream.set_session_field req "player_id" player_id in
        R.success "autoauthenticated");
  ]

let () =
  let usage_msg = "pokerbank_backend [-private_admin]" in
  let speclist =
    [
      ( "-private_admin",
        Arg.Set arg_private_admin,
        "Enable private administrative routes" );
    ]
  in
  let anon_fun = fun _ -> failwith "No positional arguments expected" in
  Arg.parse speclist anon_fun usage_msg

let () =
  let routes =
    routes @ if !arg_private_admin then private_admin_routes else []
  in
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.livereload @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.memory_sessions @@ M.cors_middleware @@ Dream.router routes
