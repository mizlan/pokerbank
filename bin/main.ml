open Containers

module type DB = Caqti_lwt.CONNECTION

let ( let* ) = Lwt.bind

let db_create_session =
  [%rapper
    get_one
      {sql|
      INSERT INTO sessions (session_name)
      VALUES (%string{name})
      RETURNING session_id
    |sql}]

let db_transact =
  [%rapper
    execute
      {sql|
      INSERT INTO transactions (session_id, player_id, bank_id, amount)
      SELECT %int{session_id}, player_id, %int{bank_id}, %int{amount}
      FROM players
      WHERE username = %string{username}
    |sql}]

let db_get_bank_or_default =
  [%rapper
    get_one
      {sql|
      INSERT INTO players (username)
      VALUES (%string{default_user})
      ON CONFLICT (username) DO NOTHING;

      INSERT INTO bank (session_id, player_id)
      SELECT %int{session_id}, player_id
      FROM players
      WHERE username = %string{default_user}
      ON CONFLICT (session_id) DO NOTHING;

      SELECT @int{player_id} FROM bank
      WHERE session_id = %int{session_id}
    |sql}]

let db_set_bank =
  [%rapper
    execute
      {sql|
      INSERT INTO bank (session_id, player_id)
      VALUES (%int{session_id}, %int{player_id}) 
      ON CONFLICT (session_id) 
      DO UPDATE SET player_id=%int{player_id};
    |sql}]

let transact ~session_id ~username ~amount (module Db : DB) =
  let open Lwt_result.Syntax in
  let* bank_id =
    Lwt_result.map_error (fun _ -> "caqti database error querying bank")
    @@ db_get_bank_or_default ~session_id ~default_user:username (module Db)
  in
  Lwt_result.map_error (fun _ -> "caqti database error transacting")
  @@ db_transact ~session_id ~username ~bank_id ~amount (module Db)

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
             | Some name ->
                 let* _ = Dream.sql request (db_create_session ~name) in
                 Dream.html ("created session " ^ name));
         Dream.post "/set_bank" (fun request ->
             let param =
               let open Option.Infix in
               let* session_id =
                 Dream.query request "session_id" >>= int_of_string_opt
               in
               let* player_id =
                 Dream.query request "player_id" >>= int_of_string_opt
               in
               Option.pure (session_id, player_id)
             in
             match param with
             | None -> Dream.html "need session_id and player_id"
             | Some (session_id, player_id) -> (
                 let* res =
                   Dream.sql request (db_set_bank ~session_id ~player_id)
                 in
                 match res with
                 | Error _ -> Dream.html "db fail"
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
                 | Error x -> Dream.html x
                 | Ok () -> Dream.html "success"));
       ]
