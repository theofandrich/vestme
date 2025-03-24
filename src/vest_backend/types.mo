import Vector "mo:vector";

module {
    public type VestingGlobalMapType = {
        user : Principal;
        tokens : Vector.Vector<VestingUserMapType>;
    };

    public type VestingUserMapType = {
        tokenCanisterId : Text;
        to : Principal;
        periods : Nat;
        periodDuration : Nat;
        amountStarted : Nat;
        amountSent : Nat;
        entries : Vector.Vector<CompletedVestingEntryType>;
        timeStarted : Int;
    };

    public type VestingShareableType = {
        tokenCanisterId : Text;
        to : Principal;
        periods : Nat;
        periodDuration : Nat;
        amountStarted : Nat;
        amountSent : Nat;
        entries : [CompletedVestingEntryType];
        timeStarted : Int;
    };

    public type CompletedVestingEntryType = {
        amountSent : Nat;
        timestamp : Int;
    };

    public type TransferError = {
        GenericError : {
            message : Text;
            error_code : Nat;
        };
        TemporarilyUnavailable : Null;
        BadBurn : { min_burn_amount : Nat };
        Duplicate : { duplicate_of : Nat };
        BadFee : { expected_fee : Nat };
        CreatedInFuture : { ledger_time : Nat64 };
        TooOld : Null;
        InsufficientFunds : { balance : Nat };
    };
};
