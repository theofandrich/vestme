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

    let vestingArgs : T.VestingUserMapType = {
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
          tokens = Vector.make<T.VestingUserMapType>(vestingArgs);
        };
        globalMap.put(caller, newGlobalMapEntry);
      };
      case (?userMap) {
        Vector.add(userMap.tokens, vestingArgs);
        let updatedUserMap : T.VestingGlobalMapType = {
          user = caller;
          tokens = userMap.tokens;
        };
        globalMap.put(caller, updatedUserMap);
      };
    };

    ignore triggerTimer(vestingArgs);

    return "Successfully Added";
  };

  func triggerTimer(vestingArgs : T.VestingUserMapType) : async () {
    ignore setTimer<system>(
      #nanoseconds(Int.abs(vestingArgs.periodDuration)),
      func() : async () {
        ignore sendTokens(vestingArgs);
      },
    );
  };

  func takeTokens(userPrincipal : Principal, amount : Nat, tokenCanisterId : Text) : async Result.Result<Nat, Text> {
    let tokenCanister = actor (tokenCanisterId) : actor {
      icrc2_transfer_from : (ICRC2.TransferFromArgs) -> async ICRC2.TransferFromResult;
    };

    let transferFromArgs : ICRC2.TransferFromArgs = {
      from = { owner = userPrincipal; subaccount = null };
      memo = null;
      amount = amount;
      spender_subaccount = null;
      fee = null;
      to = { owner = backendPrincipal; subaccount = null };
      created_at_time = null;
    };

    let transferFromResult = await tokenCanister.icrc2_transfer_from(transferFromArgs);

    switch (transferFromResult) {
      case (#Err(transferError)) {
        return #err("Couldn't transfer funds:\n" # debug_show (transferError));
      };
      case (#Ok(_)) { return #ok(0) };
    };
  };

  func sendTokens(vestingArgs : T.VestingUserMapType) : async () {
    let tokenCanister = actor (vestingArgs.tokenCanisterId) : actor {
      icrc1_transfer : (ICRC1.TransferArgs) -> async ICRC1.TransferResult;
    };

    let amountToSend = vestingArgs.amountStarted / vestingArgs.periods;

    Debug.print("sendTokens: " # debug_show (vestingArgs));

    let transferArgs : ICRC1.TransferArgs = {
      to = { owner = vestingArgs.to; subaccount = null };
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

    Debug.print("sendTokens: " # debug_show (vestingArgs));

    let newEntry : T.CompletedVestingEntryType = {
      amountSent = amountToSend;
      timestamp = Time.now();
    };

    Vector.add(vestingArgs.entries, newEntry);
    vestingArgs.amountSent += amountToSend;

    if (Vector.size(vestingArgs.entries) < vestingArgs.periods) {
      ignore triggerTimer(vestingArgs);
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
