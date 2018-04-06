(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* This is the genesis protocol: initialise the state *)
let prepare_first_block ctxt ~level ~timestamp ~fitness =
  Raw_context.prepare_first_block
    ~level ~timestamp ~fitness ctxt >>=? fun ctxt ->
  Roll_storage.init ctxt >>=? fun ctxt ->
  Seed_storage.init ctxt >>=? fun ctxt ->
  Contract_storage.init ctxt >>=? fun ctxt ->
  Bootstrap_storage.init ctxt >>=? fun ctxt ->
  Roll_storage.init_first_cycles ctxt >>=? fun ctxt ->
  Vote_storage.init ctxt >>=? fun ctxt ->
  Commitment_storage.init ctxt >>=? fun ctxt ->
  return ctxt

let prepare ctxt ~level ~timestamp ~fitness =
  Raw_context.prepare ~level ~timestamp ~fitness ctxt
