module type DB = Caqti_lwt.CONNECTION

module Q = struct
  let create_session =
    [%rapper
      get_one
        {sql|
          INSERT INTO sessions (session_name, bank_player_id)
          VALUES (%string{name}, %int{player_id})
          RETURNING @int{session_id}
        |sql}]

  let get_session_of_player =
    [%rapper
      get_opt
        {sql|
          SELECT @int{session_id}
          FROM participants
          WHERE player_id = %int{player_id}
        |sql}]

  let get_players_in_session =
    [%rapper
      get_many
        {sql|
          SELECT @int{player_id}, @string{display_name}
          FROM players
          WHERE player_id IN (
            SELECT player_id
            FROM participants
            WHERE session_id = %int{session_id}
          )
        |sql}]

  let register_player =
    [%rapper
      execute
        {sql|
          INSERT INTO players (email, display_name)
          VALUES (%string{email}, %string{name})
          ON CONFLICT (email) DO NOTHING
        |sql}]

  let get_player_id =
    [%rapper
      get_one
        {sql|
          SELECT @int{player_id}
          FROM players
          WHERE email = %string{email}
        |sql}]

  let add_transaction =
    (* NOTE: no protection against recording a transaction of a non-participant *)
    [%rapper
      execute
        {sql|
          INSERT INTO transactions (session_id, player_id, bank_player_id, amount)
          SELECT %int{session_id}, %int{player_id}, sessions.bank_player_id, %int{amount}
          FROM sessions
          WHERE sessions.session_id = %int{session_id}
        |sql}]

  let set_bank =
    (* NOTE: no protection against setting the bank to a non-participant *)
    [%rapper
      execute
        {sql|
          UPDATE sessions
          SET bank_player_id = %int{player_id}
          WHERE sessions.session_id = %int{session_id}
        |sql}]
end

let or_err r = Lwt_result.map_error Caqti_error.show r

let create_session ~name ~player_id (module Db : DB) =
  Q.create_session ~name ~player_id (module Db) |> or_err

let transact ~session_id ~player_id ~amount (module Db : DB) =
  Q.add_transaction ~session_id ~player_id ~amount (module Db) |> or_err

let set_bank ~session_id ~player_id (module Db : DB) =
  Q.set_bank ~session_id ~player_id (module Db) |> or_err

let register_player ~email ~name (module Db : DB) =
  let open Lwt_result.Syntax in
  let* () = Q.register_player ~email ~name (module Db) |> or_err in
  Q.get_player_id ~email (module Db) |> or_err

let get_session_of_player ~player_id (module Db : DB) =
  Q.get_session_of_player ~player_id (module Db) |> or_err

let get_players_in_session ~session_id (module Db : DB) =
  Q.get_players_in_session ~session_id (module Db) |> or_err
