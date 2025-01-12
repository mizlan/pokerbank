open Containers
module Db = Database

let ( let* ) = Lwt.bind

module E = struct
  let mk_error status msg =
    Dream.json ~status (Printf.sprintf {|{"error": "%s"}|} msg)

  let internal = mk_error `Internal_Server_Error
  let unauthorized = mk_error `Unauthorized
  let bad_req = mk_error `Bad_Request
end

module F = struct
  let player_id = Dream.new_field ~name:"player_id" ()
  let session_id = Dream.new_field ~name:"session_id" ()

  let get_player_id req =
    Option.get_exn_or "get_player_id must be called from within a player route"
      (Dream.field req player_id)
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
