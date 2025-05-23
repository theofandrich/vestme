import { Principal } from "@dfinity/principal";
import type { ApproveArgs, Result_1 } from "$lib/candid/icrc.did";

export const checkAllowance = async (tokenApi: any, backendPID: string, pid: Principal): Promise<boolean> => {
  try {
    const args = {
      account: {
        owner: pid, // User's principal
      subaccount: [], // Optional, can be left empty if not using subaccounts
    },
    spender: {
      owner: Principal.fromText(backendPID), // Convert the string to a Principal
      subaccount: [], // Optional, can be left empty if not using subaccounts
    },
  };
  
  const result = await tokenApi.icrc2_allowance(args);
  
  if (result.allowance > 0n) {
    return true;
  } else {
      return await getApproval(tokenApi, backendPID);
    }
  } catch (error) {
    console.error("Unexpected error during checkAllowance:", error);
    return false;
  }
};

export const getApproval = async (tokenApi: any, backendPID: string) => {
    try {
      let args: ApproveArgs = {
        fee: [], // Optional, can be left empty if not needed
        memo: [], // Optional, can be left empty if not needed
        from_subaccount: [], // Optional, can be left empty if not using subaccounts
        created_at_time: [], // Optional, can be left empty if not specifying a creation time
        amount: 10_000_000_000_000_000_000n, // The amount to approve, as a bigint
        expected_allowance: [], // Optional, can be left empty if not specifying an expected allowance
        expires_at: [], // You can set an expiration time as needed, using [] if you don't want to specify one
        spender: {
          owner: Principal.fromText(backendPID), // Convert the string to a Principal
          subaccount: [], // Optional, can be left empty if not using subaccounts
        },
      }
  
      let result: Result_1 = await tokenApi.icrc2_approve(args);
      
      if(result.Ok) {
        return true;
      }
      return false;
  
    } catch (error) {
      console.error("Unexpected error during getApproval:", error);
      return false;
    }
  };