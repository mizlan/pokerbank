open Containers

module type DB = Caqti_lwt.CONNECTION

let ( let* ) = Lwt.bind

let db_create_session =
  [%rapper
    get_one
      {sql|
      INSERT INTO sessions (session_name)
      VALUES (%string{name})
      RETURNING @int{session_id}
    |sql}]

let db_transact =
  [%rapper
    execute
      {sql|
      INSERT INTO transactions (session_id, player_id, bank_player_id, amount)
      SELECT %int{session_id}, players.player_id, bank.player_id, %int{amount}
      FROM players
      JOIN bank ON bank.session_id = %int{session_id}
      WHERE username = %string{username}
    |sql}]

let db_register_player =
  [%rapper
    execute
      {sql|
      INSERT INTO players (username)
      VALUES (%string{username})
      ON CONFLICT (username) DO NOTHING
    |sql}]

let db_set_bank_if_unset =
  [%rapper
    execute
      {sql|
      INSERT INTO bank (session_id, player_id)
      SELECT %int{session_id}, player_id
      FROM players
      WHERE username = %string{username}
      ON CONFLICT (session_id) DO NOTHING
    |sql}]

let db_set_bank =
  [%rapper
    execute
      {sql|
      INSERT INTO bank (session_id, player_id)
      SELECT %int{session_id}, player_id
      FROM players
      WHERE username = %string{username}
      ON CONFLICT (session_id) 
      DO UPDATE SET player_id = excluded.player_id
    |sql}]

let transact ~session_id ~username ~amount (module Db : DB) =
  let open Lwt_result.Syntax in
  let* () = db_register_player ~username (module Db) in
  let* () = db_set_bank_if_unset ~session_id ~username (module Db) in
  db_transact ~session_id ~username ~amount (module Db)

let () =
  Dream.run ~interface:"0.0.0.0" ~port:6868
  @@ Dream.logger
  @@ Dream.sql_pool "sqlite3:db.db"
  @@ Dream.router
       [
         Dream.post "/create_session" (fun request ->
             let name_param = Dream.query request "name" in
             match name_param with
             | None -> Dream.html "need name"
             | Some name -> (
                 let* res = Dream.sql request (db_create_session ~name) in
                 match res with
                 | Error e -> Dream.html (Caqti_error.show e)
                 | Ok session_id ->
                     Dream.html
                       ("created session " ^ name ^ " with id "
                      ^ string_of_int session_id)));
         Dream.post "/set_bank" (fun request ->
             let param =
               let open Option.Infix in
               let* session_id =
                 Dream.query request "session_id" >>= int_of_string_opt
               in
               let* username = Dream.query request "username" in
               Option.pure (session_id, username)
             in
             match param with
             | None -> Dream.html "need session_id and username"
             | Some (session_id, username) -> (
                 let* res =
                   Dream.sql request (db_set_bank ~session_id ~username)
                 in
                 match res with
                 | Error e -> Dream.html (Caqti_error.show e)
                 | Ok () -> Dream.html "success"));
         Dream.post "/transact" (fun request ->
             let param =
               let open Option.Infix in
               let* session_id =
                 Dream.query request "session_id" >>= int_of_string_opt
               in
               let* username = Dream.query request "username" in
               let* amount =
                 Dream.query request "amount" >>= int_of_string_opt
               in
               Option.pure (session_id, username, amount)
             in
             match param with
             | None -> Dream.html "need session_id, player_id, and amount"
             | Some (session_id, username, amount) -> (
                 let* res =
                   Dream.sql request (transact ~session_id ~username ~amount)
                 in
                 match res with
                 | Error x -> Dream.html (Caqti_error.show x)
                 | Ok () -> Dream.html "success"));
       ]
