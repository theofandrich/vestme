import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import { recurringTimer } = "mo:base/Timer";
import { setTimer } "mo:base/Timer";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import T "types";
import ICRC1 "mo:icrc1-types";
import ICRC2 "mo:icrc2-types";
import Vector "mo:vector";

actor {
  let isLocal = false;

  let backendPrincipal = if (isLocal) {
    Principal.fromText("by6od-j4aaa-aaaaa-qaadq-cai");
  } else {
    Principal.fromText("kpxzg-2iaaa-aaaal-asawa-cai");
  };
  //Receive Tokens for Periodic Vesting
  let globalMap = HashMap.HashMap<Principal, T.VestingGlobalMapType>(1000, Principal.equal, Principal.hash); //this is the main mutable map for player [id (index), privacy, inLiveGame (for mines), username, totalWagered].

  public shared ({ caller }) func receiveTokens(to : Principal, amount : Nat, tokenCanisterId : Text, periods : Nat, durationMS : Nat) : async Text {
    let durationNS = durationMS * 1_000_000;

    Debug.print("receiveTokens: " # debug_show (caller, amount, tokenCanisterId, periods, durationNS));

    switch (await takeTokens(caller, amount, tokenCanisterId)) {
      case (#err(err)) {
        return "Error: " # err;
      };
      case (#ok(_)) {};
    };

    Debug.print("Tokens Received: " # debug_show (caller, amount, tokenCanisterId, periods, durationNS));

    let args : T.VestingUserMapType = {
      tokenCanisterId = tokenCanisterId;
      to = to;
      periods = periods;
      periodDuration = durationNS;
      amountStarted = amount;
      var amountSent = 0;
      entries = Vector.new<T.CompletedVestingEntryType>();
      timeStarted = Time.now();
    };

    switch (globalMap.get(caller)) {

      case (null) {
        let newGlobalMapEntry : T.VestingGlobalMapType = {

          user = caller;

          tokens = Vector.make<T.VestingUserMapType>(args);

        };

        globalMap.put(caller, newGlobalMapEntry);

      };

      case (?userMap) {

        Vector.add(userMap.tokens, args);

        let newUserMap : T.VestingGlobalMapType = {
          user = caller;
          tokens = userMap.tokens;
        };

        globalMap.put(caller, newUserMap);
      };
    };

    ignore triggerTimer(args);

    return "Successfuly Added";
  };

  func triggerTimer(args : T.VestingUserMapType) : async () {
    ignore setTimer<system>(
      #nanoseconds(Int.abs(args.periodDuration)),
      func() : async () {
        ignore sendTokens(args);
      },
    );
  };

  func takeTokens(userPrincipal : Principal, amount : Nat, tokenCanisterId : Text) : async Result.Result<Nat, Text> {
    let tokenCanister = actor (tokenCanisterId) : actor {
      icrc2_transfer_from : (ICRC2.TransferFromArgs) -> async ICRC2.TransferFromResult;
    };

    let transferFromArgs : ICRC2.TransferFromArgs = {
      // the account we want to transfer tokens from
      from = {
        owner = userPrincipal;
        subaccount = null;
      };
      // can be used to distinguish between transactions
      memo = null;
      // the amount we want to transfer
      amount = amount;
      // the subaccount we want to spend the tokens from
      spender_subaccount = null;
      // if not specified, the default fee for the canister is used
      fee = null;
      // the account we want to transfer tokens to
      to = {
        owner = backendPrincipal;
        subaccount = null;
      };
      // a timestamp indicating when the transaction was created
      created_at_time = null;
    };

    // initiate the transfer
    let transferFromResult = await tokenCanister.icrc2_transfer_from(transferFromArgs);

    // check if the transfer was successful
    switch (transferFromResult) {
      case (#Err(transferError)) {
        return #err("Couldn't transfer funds:\n" # debug_show (transferError));
      };
      case (#Ok(_)) { return #ok(0) };
    };

  };

  func sendTokens(args : T.VestingUserMapType) : async () {

    let tokenCanister = actor (args.tokenCanisterId) : actor {
      icrc1_transfer : (ICRC1.TransferArgs) -> async ICRC1.TransferResult;
    };

    let amountToSend = args.amountStarted / args.periods;

    Debug.print("sendTokens: " # debug_show (args));

    let transferArgs : ICRC1.TransferArgs = {
      to = {
        owner = args.to;
        subaccount = null;
      };
      fee = null;
      memo = null;
      from_subaccount = null;
      created_at_time = null;
      amount = amountToSend;
    };

    Debug.print("transferArgs: " # debug_show (transferArgs));

    let transferResult = await tokenCanister.icrc1_transfer(transferArgs);

    Debug.print("transferResult: " # debug_show (transferResult));

    switch (transferResult) {
      case (#Err(_)) {};
      case (#Ok(_)) {};
    };

    Debug.print("sendTokens: " # debug_show (args));

    let newEntry : T.CompletedVestingEntryType = {
      amountSent = amountToSend;
      timestamp = Time.now();
    };

    Vector.add(args.entries, newEntry);
    args.amountSent += amountToSend;

    if (Vector.size(args.entries) < args.periods) {
      ignore triggerTimer(args);
    };
  };

  public shared ({ caller }) func getVestingInfo() : async [T.VestingShareableType] {
    let userMap = globalMap.get(caller);
    let buffer : Buffer.Buffer<T.VestingShareableType> = Buffer.Buffer<T.VestingShareableType>(1000);

    switch (userMap) {
      case (null) { return [] };
      case (?userMap) {
        let tokens = Vector.toArray(userMap.tokens);
        for (token in tokens.vals()) {
          buffer.add({
            tokenCanisterId = token.tokenCanisterId;
            to = token.to;
            periods = token.periods;
            periodDuration = token.periodDuration;
            amountStarted = token.amountStarted;
            amountSent = token.amountSent;
            entries = Vector.toArray(token.entries);
            timeStarted = token.timeStarted;
          });
        };
      };
    };
    return Buffer.toArray(buffer);
  };
};
