(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Client_config

let display_warning_banner ctxt =
  let default () =
    Format.eprintf
      "@[<v 2>@{<warning>@{<title>Warning@}@}@,@,\
      \                       This is @{<warning>NOT@} the Tezos Mainnet.@,\
      \                    The Tezos Mainnet is not yet released.@,\
       @,\
      \                 Use your fundraiser keys @{<warning>AT YOUR OWN RISK@}.@,\
       All transactions happening on the Betanet @{<warning>are expected to be valid in the Mainnet@}.@,\
      \        In doubt, we recommend that you wait for the lunch of the Mainnet.@]@\n@." ;
    Lwt.return () in
  Shell_services.P2p.versions ctxt >>= function
  | Error _ -> default ()
  | Ok versions ->
      match String.split_on_char '_' (List.hd versions).name with
      | "TEZOS" :: "ZERONET" :: _date :: [] ->
          Format.eprintf
            "@[<v 2>@{<warning>@{<title>Warning@}@}@,@,\
            \               This is @{<warning>NOT@} the Tezos Mainnet.@,\
            \            The Tezos Mainnet is not yet released.@,\
             @,\
            \    The node you are connecting to claims to be running on the@,\
            \               @{<warning>Tezos Zeronet DEVELOPMENT NETWORK@}.@,\
            \         Do @{<warning>NOT@} use your fundraiser keys on this network.@,\
             Zeronet is a testing network, with free tokens and frequent resets.@]@\n@." ;
          Lwt.return ()
      | "TEZOS" :: "ALPHANET" :: _date :: [] ->
          Format.eprintf
            "@[<v 2>@{<warning>@{<title>Warning@}@}@,@,\
            \               This is @{<warning>NOT@} the Tezos Mainnet.@,\
            \            The Tezos Mainnet is not yet released.@,\
             @,\
            \   The node you are connecting to claims to be running on the@,\
            \             @{<warning>Tezos Alphanet DEVELOPMENT NETWORK.@}@,\
            \        Do @{<warning>NOT@} use your fundraiser keys on this network.@,\
            \        Alphanet is a testing network, with free tokens.@]@\n@." ;
          Lwt.return ()
      | "TEZOS" :: "BETANET" :: _date :: [] ->
          Format.eprintf
            "@[<v 2>@{<warning>@{<title>Warning@}@}@,@,\
            \                         This is @{<warning>NOT@} the Tezos Mainnet.@,\
            \                      The Tezos Mainnet is not yet released.@,\
             @,\
            \            The node you are connecting to claims to be running on the@,\
            \                      @{<warning>Tezos Betanet EXPERIMENTAL NETWORK@}.@,\
            \    Betanet is a pre-release experimental network and comes with no warranty.@,\
            \            Use your fundraiser keys on this network @{<warning>AT YOUR OWN RISK@}.@,\
            \  All transactions happening on the Betanet @{<warning>are expected to be valid in the Mainnet@}.@,\
            \          If in doubt, we recommend that you wait for the Mainnet lunch.@]@\n@." ;
          Lwt.return ()
      | "TEZOS" :: _date :: [] ->
          Format.eprintf
            "@[<v 2>@{<warning>@{<title>Warning@}@}@,@,\
            \             This is @{<warning>NOT@} the Tezos Mainnet.@,\
            \          The Tezos Mainnet is not yet released.@,\
             @,\
            \ The node you are connecting to claims to be running in a@,\
            \                  @{<warning>Tezos TEST SANDBOX@}.@,\
            \    Do @{<warning>NOT@} use your fundraiser keys on this network.@,\
             You should not see this message if you are not a developer.@]@\n@." ;
          Lwt.return ()
      | _ -> default ()

let get_commands_for_version ctxt block protocol =
  Shell_services.Blocks.protocols ctxt ~block () >>= function
  | Ok { next_protocol = version } -> begin
      match protocol with
      | None ->
          return (Some version, Client_commands.commands_for_version version)
      | Some given_version -> begin
          if not (Protocol_hash.equal version given_version) then
            Format.eprintf
              "@[<v 2>@{<warning>@{<title>Warning@}@}@,\
               The protocol provided via `--protocol` (%a)@,\
               is not the one retrieved from the node (%a).@]@\n@."
              Protocol_hash.pp_short given_version
              Protocol_hash.pp_short version ;
          return (Some version, Client_commands.commands_for_version given_version)
        end
    end
  | Error errs -> begin
      match protocol with
      | None -> begin
          Format.eprintf
            "@[<v 2>@{<warning>@{<title>Warning@}@}@,\
             Failed to acquire the protocol version from the node@,%a@]@\n@."
            (Format.pp_print_list pp) errs ;
          return (None, [])
        end
      | Some version ->
          return (Some version, Client_commands.commands_for_version version)
    end

let select_commands ctxt { block ; protocol } =
  display_warning_banner ctxt >>= fun () ->
  get_commands_for_version ctxt block protocol >>|? fun (_, commands_for_version)  ->
  Client_rpc_commands.commands @
  List.map
    (Clic.map_command
       (fun (o : Client_context.full) -> (o :> Client_context.io_wallet)))
    (Tezos_signer_backends.Ledger.commands () @
     Client_keys_commands.commands ()) @
  Client_helpers_commands.commands () @
  commands_for_version

let () = Client_main_run.run select_commands
