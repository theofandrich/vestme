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
        var amountSent : Nat;
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
};
