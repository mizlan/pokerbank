open Containers

module type DB = Caqti_lwt.CONNECTION

module Q = struct
  let create_session =
    [%rapper
      get_one
        {sql|
      INSERT INTO sessions (session_name)
      VALUES (%string{name})
      RETURNING @int{session_id}
    |sql}]

  let add_transaction =
    [%rapper
      execute
        {sql|
      INSERT INTO transactions (session_id, player_id, bank_player_id, amount)
      SELECT %int{session_id}, players.player_id, bank.player_id, %int{amount}
      FROM players
      JOIN bank ON bank.session_id = %int{session_id}
      WHERE email = %string{email}
    |sql}]

  let register_player =
    [%rapper
      execute
        {sql|
      INSERT INTO players (email, display_name)
      VALUES (%string{email}, %string{name})
      ON CONFLICT (email) DO NOTHING
    |sql}]

  let set_bank_if_unset =
    [%rapper
      execute
        {sql|
      INSERT INTO bank (session_id, player_id)
      SELECT %int{session_id}, player_id
      FROM players
      WHERE email = %string{email}
      ON CONFLICT (session_id) DO NOTHING
    |sql}]

  let set_bank =
    [%rapper
      execute
        {sql|
      INSERT INTO bank (session_id, player_id)
      SELECT %int{session_id}, player_id
      FROM players
      WHERE email = %string{email}
      ON CONFLICT (session_id) 
      DO UPDATE SET player_id = excluded.player_id
    |sql}]
end

let or_err r = Lwt.map (Result.map_err Caqti_error.show) r

let create_session ~name (module Db : DB) =
  Q.create_session ~name (module Db) |> or_err

let transact ~session_id ~email ~amount (module Db : DB) =
  let open Lwt_result.Syntax in
  let* () = Q.set_bank_if_unset ~session_id ~email (module Db) |> or_err in
  Q.add_transaction ~session_id ~email ~amount (module Db) |> or_err

let set_bank ~session_id ~email (module Db : DB) =
  Q.set_bank ~session_id ~email (module Db) |> or_err

let register_player ~email ~name (module Db : DB) =
  Q.register_player ~email ~name (module Db) |> or_err
