open Containers
module C = Oidc.SimpleClient

let ( let* ) = Lwt.bind
let provider_uri = Uri.of_string "https://accounts.google.com"
let redirect_uri = Uri.of_string "http://localhost:6868/auth/callback"
let client_secret_object = Yojson.Safe.from_file "client_secret.json"

let client_id =
  client_secret_object
  |> Yojson.Safe.Util.member "web"
  |> Yojson.Safe.Util.member "client_id"
  |> Yojson.Safe.Util.to_string

let client_secret =
  client_secret_object
  |> Yojson.Safe.Util.member "web"
  |> Yojson.Safe.Util.member "client_secret"
  |> Yojson.Safe.Util.to_string

let client = C.make ~redirect_uri ~provider_uri ~secret:client_secret client_id

let discovery, jwks =
  Lwt_main.run
  @@
  (* discovery *)
  let discovery_uri = C.discovery_uri client in
  let* _, discovery_string = Http_client.get discovery_uri in
  let discovery = Result.get_exn (Oidc.Discover.of_string discovery_string) in
  (* jwks *)
  let jwks_uri = discovery.jwks_uri in
  let* _, jwks_string = Http_client.get jwks_uri in
  let jwks = Jose.Jwks.of_string jwks_string in
  Lwt.return (discovery, jwks)

let auth_uri =
  C.make_auth_uri
    ~scope:[ `OpenID; `Email; `Profile ]
    ~state:"state" ~discovery client

let get_token code =
  let { C.body; headers; uri; _ } =
    C.make_token_request ~code ~discovery client
  in
  match body with
  | None -> Lwt.return (Error "Auth: oidc: callback: no body")
  | Some body ->
      let* _, body = Http_client.post ~headers ~body uri in
      C.valid_token_of_string ~jwks ~discovery client body
      |> Result.map_err Oidc.Error.to_string
      |> Lwt.return

let get_userinfo token =
  match C.make_userinfo_request ~token ~discovery with
  | Error _ -> Lwt.return (Error "could not make userinfo request")
  | Ok { C.headers; uri; _ } ->
      let* _, body = Http_client.get ~headers uri in
      C.valid_userinfo_of_string ~token_response:token body
      |> Result.map_err Oidc.Error.to_string
      |> Lwt.return
