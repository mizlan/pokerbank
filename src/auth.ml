open Containers
open Ppx_yojson_conv_lib.Yojson_conv.Primitives
module C = Oidc.SimpleClient

type userinfo = { email : string; name : string }
[@@deriving yojson] [@@yojson.allow_extra_fields]

let ( let* ) = Lwt.bind
let provider_uri = Uri.of_string "https://accounts.google.com"
let redirect_uri = Uri.of_string "http://localhost:6868/api/auth/callback"
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

let generate_state () =
  let random_char () = Char.chr (Stdlib.Random.int 26 + 97) in
  String.init 20 (fun _ -> random_char ())

let make_auth_uri state =
  C.make_auth_uri ~scope:[ `OpenID; `Email; `Profile ] ~state ~discovery client

let get_token code =
  let { C.body; headers; uri; _ } =
    C.make_token_request ~code ~discovery client
  in
  match body with
  | None -> Lwt.return_error "Auth: oidc: callback: no body"
  | Some body ->
      let* _, body = Http_client.post ~headers ~body uri in
      C.valid_token_of_string ~jwks ~discovery client body
      |> Result.map_err Oidc.Error.to_string
      |> Lwt.return

let get_userinfo token =
  match C.make_userinfo_request ~token ~discovery with
  | Error e ->
      Lwt.return_error ("Auth: oidc: userinfo: " ^ Oidc.Error.to_string e)
  | Ok { C.headers; uri; _ } ->
      let* _, body = Http_client.get ~headers uri in
      C.valid_userinfo_of_string ~token_response:token body
      |> Result.map_err Oidc.Error.to_string
      |> Result.map Yojson.Safe.from_string
      |> Result.map userinfo_of_yojson
      |> Lwt.return
