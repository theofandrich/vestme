<script>
  // Import necessary modules and components
  import { Actor } from "@dfinity/agent";
  import { idlFactory } from "$lib/candid/icrc.did.js";
  import { auth } from "$lib/state/auth.state.svelte";
  import { checkAllowance } from "$lib/services/services";
  import { Principal } from "@dfinity/principal";

  // Props
  let { backendApi, backendCanisterId, onVestingCreated } = $props();

  // Token state
  let canisterId = $state("");
  let tokenApi = $state(null);
  let balance = $state(null);
  let error = $state(null);
  let isLoading = $state(false);

  // Vesting form state
  let recipientPrincipal = $state("");
  let vestingAmount = $state(0);
  let vestingPeriods = $state(1);
  let vestingDurationSeconds = $state(60); // Default: 60 seconds
  let vestingDurationMS = $derived(vestingDurationSeconds * 1000);
  let isVestingLoading = $state(false);
  let vestingError = $state(null);
  let vestingSuccess = $state(false);

  // Validate canister ID
  let isCidValid = $derived.by(() => {
    if (canisterId.length > 10) {
      return Principal.fromText(canisterId).toText() === canisterId;
    }
    return false;
  });

  // Agent and principal
  let agent = $derived(auth.agent);
  let pid = $derived(auth.identity?.getPrincipal() || null);

  // Format balance with 8 decimal places
  function formatBalance(rawBalance) {
    if (!rawBalance && rawBalance !== 0) return "—";
    const num = Number(rawBalance) / 100000000;
    return new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 8,
    }).format(num);
  }

  // Get token balance
  const getTokenBalance = async () => {
    if (!canisterId) {
      error = "Please enter a valid canister ID";
      return;
    }
    try {
      error = null;
      isLoading = true;

      // Create an actor if it doesn't exist yet
      tokenApi = Actor.createActor(idlFactory, {
        agent,
        canisterId,
      });

      // Get the balance
      balance = await tokenApi.icrc1_balance_of({
        owner: auth.identity?.getPrincipal(),
        subaccount: [],
      });

      if (balance > 0n) {
        await checkAllowance(tokenApi, backendCanisterId, pid);
      }

      isLoading = false;
    } catch (err) {
      error = `Failed to get balance: ${err.message}`;
      isLoading = false;
      balance = null;
    }
  };

  // Reset form after successful vesting creation
  function resetForm() {
    recipientPrincipal = "";
    vestingAmount = 0;
    vestingPeriods = 1;
    vestingDurationSeconds = 60;
  }

  // Create vesting schedule
  async function handleCreateVesting() {
    if (!canisterId) {
      vestingError = "Please enter a token canister ID";
      return;
    }

    if (!recipientPrincipal) {
      vestingError = "Please enter a recipient principal";
      return;
    }

    if (vestingAmount <= 0) {
      vestingError = "Amount must be greater than 0";
      return;
    }

    if (vestingPeriods <= 0) {
      vestingError = "Number of periods must be greater than 0";
      return;
    }

    if (vestingDurationSeconds <= 0) {
      vestingError = "Duration must be greater than 0";
      return;
    }

    if (!balance || balance <= 0n) {
      vestingError = "Your balance must be greater than 0";
      return;
    }

    try {
      vestingError = null;
      isVestingLoading = true;
      vestingSuccess = false;

      // Convert amount to e8s (assuming 8 decimal places)
      const amountE8s = Math.floor(vestingAmount * 100000000);

      // Call the backend receiveTokens function
      await backendApi.receiveTokens(Principal.fromText(recipientPrincipal), BigInt(amountE8s), canisterId, BigInt(vestingPeriods), BigInt(vestingDurationMS));

      vestingSuccess = true;
      resetForm();
      onVestingCreated();
      isVestingLoading = false;
    } catch (err) {
      vestingError = `Failed to create vesting: ${err.message}`;
      isVestingLoading = false;
    }
  }
</script>

<div class="widget combined-widget">
  <h2>Create Vesting Schedule</h2>

  <div class="vesting-form">
    <div class="form-group">
      <label for="canisterId">Token Canister ID</label>
      <div class="canister-input-group">
        <input type="text" id="canisterId" bind:value={canisterId} placeholder="Enter token canister ID" />
        <button type="button" onclick={getTokenBalance} class="balance-button"> Get Token Balance </button>

        {#if isLoading}
          <div class="loading-indicator">Loading...</div>
        {/if}
      </div>

      {#if !isCidValid && canisterId}
        <div class="error-message">Invalid canister ID</div>
      {/if}

      {#if balance !== null}
        <div class="balance-display">
          <span class="balance-label">Your Balance:</span>
          <span class="balance-value">{formatBalance(balance)}</span>
        </div>
      {/if}
    </div>

    <div class="form-group">
      <label for="recipientPrincipal">Recipient Principal ID</label>
      <input type="text" id="recipientPrincipal" bind:value={recipientPrincipal} placeholder="Principal ID of recipient" />
    </div>

    <div class="form-group">
      <label for="vestingAmount">Amount to Vest</label>
      <input type="number" id="vestingAmount" bind:value={vestingAmount} min="0" step="0.00000001" max={balance ? Number(balance) / 100000000 : undefined} />
    </div>

    <div class="form-group">
      <label for="vestingPeriods">Number of Payments</label>
      <input type="number" id="vestingPeriods" bind:value={vestingPeriods} min="1" step="1" />
    </div>

    <div class="form-group">
      <label for="vestingDuration">Payment Interval (seconds)</label>
      <input type="number" id="vestingDuration" bind:value={vestingDurationSeconds} min="1" step="1" placeholder="Enter seconds (e.g. 60 for 1 minute)" />
    </div>

    <button type="button" onclick={handleCreateVesting} disabled={isVestingLoading || !balance || balance <= 0n} class="vesting-action-button">
      {isVestingLoading ? "Creating..." : "Create Vesting Schedule"}
    </button>
  </div>

  {#if vestingSuccess}
    <div class="success-message">Vesting schedule created successfully!</div>
  {/if}

  {#if vestingError}
    <div class="error-message">
      {vestingError}
    </div>
  {/if}

  {#if error}
    <div class="error-message">
      {error}
    </div>
  {/if}
</div>

<style lang="scss">
  .combined-widget {
    background-color: var(--color-surface);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: var(--space-lg);
    height: fit-content;
    margin-bottom: var(--space-lg);
  }

  h2 {
    color: var(--color-primary);
    margin-bottom: var(--space-md);
  }

  .vesting-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-md);
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-xs);
  }

  .canister-input-group {
    position: relative;
    display: flex;
    justify-content: space-between;
  }

  .loading-indicator {
    position: absolute;
    right: 10px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.8rem;
    color: var(--color-text-light);
  }

  label {
    font-weight: 600;
    color: var(--color-text);
    font-size: 0.9rem;
  }

  input[type="text"],
  input[type="number"] {
    font-size: 1rem;
    padding: var(--space-sm);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    background-color: var(--color-background);

    &:focus {
      outline: 2px solid var(--color-primary-light);
      border-color: var(--color-primary);
    }
  }

  .balance-display {
    margin-top: var(--space-xs);
    padding: var(--space-sm);
    background-color: var(--color-background);
    border-radius: var(--radius-md);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .balance-label {
    font-weight: 600;
    color: var(--color-text);
  }

  .balance-value {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .vesting-action-button {
    background-color: var(--color-primary);
    color: white;
    padding: var(--space-md);
    margin-top: var(--space-sm);
    font-weight: 600;
    cursor: pointer;
    border: none;
    border-radius: var(--radius-sm);
    transition:
      background-color 0.2s,
      transform 0.1s;

    &:hover:not(:disabled) {
      opacity: 0.9;
      transform: translateY(-1px);
    }

    &:active:not(:disabled) {
      transform: translateY(0);
    }

    &:disabled {
      background-color: var(--color-text-light);
      cursor: not-allowed;
      opacity: 0.7;
    }
  }

  .error-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: var(--color-error);
    background-color: rgba(230, 57, 70, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
  }

  .success-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: #2a9d8f;
    background-color: rgba(42, 157, 143, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
  }

  .balance-button {
    background-color: var(--color-primary);
    color: white;
    padding: var(--space-sm);
    margin-top: var(--space-xs);
    font-weight: 600;
    cursor: pointer;
    border: none;
    border-radius: var(--radius-sm);
    transition:
      background-color 0.2s,
      transform 0.1s;

    &:hover:not(:disabled) {
      opacity: 0.9;
      transform: translateY(-1px);
    }

    &:active:not(:disabled) {
      transform: translateY(0);
    }

    &:disabled {
      background-color: var(--color-text-light);
      cursor: not-allowed;
      opacity: 0.7;
    }
  }
</style>
