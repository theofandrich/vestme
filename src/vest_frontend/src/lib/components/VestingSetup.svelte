<script>
  import { onMount } from "svelte";
  import { backend } from "$lib/utils/canisters";
  import { auth } from "$lib/state/auth.state.svelte";

  // Form inputs
  let recipient = "";
  let amount = "";
  let tokenCanisterId = "";
  let periods = "";
  let durationDays = "";

  // Status handling
  let isSubmitting = false;
  let error = null;
  let success = false;

  // Duration in days is more user-friendly than milliseconds
  $: durationMS = durationDays ? parseInt(durationDays) * 24 * 60 * 60 * 1000 : 0;

  // Validate form
  $: isValid = recipient && amount && !isNaN(Number(amount)) && tokenCanisterId && periods && !isNaN(Number(periods)) && durationDays && !isNaN(Number(durationDays));

  async function handleSubmit() {
    if (!isValid) {
      error = "Please fill all fields with valid values";
      return;
    }

    if (!auth.isAuthenticated) {
      error = "You must be authenticated to set up vesting";
      return;
    }

    try {
      error = null;
      success = false;
      isSubmitting = true;

      // Convert string inputs to appropriate types
      const amountNum = BigInt(amount);
      const periodsNum = Number(periods);

      await backend.receiveTokens(recipient, amountNum, tokenCanisterId, periodsNum, durationMS);

      success = true;
      // Reset form
      recipient = "";
      amount = "";
      tokenCanisterId = "";
      periods = "";
      durationDays = "";
    } catch (err) {
      error = `Failed to setup vesting: ${err.message}`;
    } finally {
      isSubmitting = false;
    }
  }
</script>

<div class="vesting-setup-widget">
  <h2>Setup Token Vesting</h2>

  <form on:submit|preventDefault={handleSubmit}>
    <div class="form-group">
      <label for="recipient">Recipient Principal ID</label>
      <input type="text" id="recipient" bind:value={recipient} placeholder="Enter recipient's principal ID" disabled={isSubmitting || !auth.isAuthenticated} />
    </div>

    <div class="form-group">
      <label for="amount">Total Amount</label>
      <input type="number" id="amount" bind:value={amount} placeholder="Enter total token amount" min="1" disabled={isSubmitting || !auth.isAuthenticated} />
    </div>

    <div class="form-group">
      <label for="tokenCanisterId">Token Canister ID</label>
      <input type="text" id="tokenCanisterId" bind:value={tokenCanisterId} placeholder="Enter token canister ID" disabled={isSubmitting || !auth.isAuthenticated} />
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="periods">Number of Periods</label>
        <input type="number" id="periods" bind:value={periods} placeholder="Enter number of periods" min="1" disabled={isSubmitting || !auth.isAuthenticated} />
      </div>

      <div class="form-group">
        <label for="durationDays">Duration (days)</label>
        <input type="number" id="durationDays" bind:value={durationDays} placeholder="Enter duration in days" min="1" disabled={isSubmitting || !auth.isAuthenticated} />
      </div>
    </div>

    {#if durationMS > 0 && periods > 0 && amount > 0}
      <div class="vesting-summary">
        <p>Each period will release <strong>{amount / periods}</strong> tokens</p>
        <p>Every <strong>{durationDays / periods}</strong> days for <strong>{durationDays}</strong> days total</p>
      </div>
    {/if}

    <div class="button-container">
      <button type="submit" class="vesting-submit-button" disabled={isSubmitting || !isValid || !auth.isAuthenticated}>
        {#if isSubmitting}
          Setting up...
        {:else}
          Setup Vesting
        {/if}
      </button>
    </div>
  </form>

  {#if success}
    <div class="success-message">Vesting successfully set up!</div>
  {/if}

  {#if error}
    <div class="error-message">
      {error}
    </div>
  {/if}

  {#if !auth.isAuthenticated}
    <div class="auth-message">Please log in to set up token vesting.</div>
  {/if}
</div>

<style lang="scss">
  .vesting-setup-widget {
    max-width: 600px;
    margin: var(--space-xl) auto;
    padding: var(--space-lg);
    background-color: var(--color-surface);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
  }

  h2 {
    color: var(--color-primary);
    margin-bottom: var(--space-lg);
    text-align: center;
  }

  .form-group {
    margin-bottom: var(--space-md);
    width: 100%;

    label {
      display: block;
      margin-bottom: var(--space-xs);
      font-weight: 600;
      color: var(--color-text);
      font-size: 0.9rem;
    }

    input {
      width: 100%;
      padding: var(--space-sm) var(--space-md);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-md);
      font-family: var(--font-primary);

      &:focus {
        outline: none;
        border-color: var(--color-secondary);
        box-shadow: 0 0 0 2px var(--color-secondary-light);
      }

      &:disabled {
        background-color: var(--color-background);
        cursor: not-allowed;
        opacity: 0.7;
      }
    }
  }

  .form-row {
    display: flex;
    gap: var(--space-md);
    margin-bottom: var(--space-md);
  }

  .vesting-summary {
    margin: var(--space-md) 0;
    padding: var(--space-md);
    background-color: var(--color-background);
    border-radius: var(--radius-md);

    p {
      margin: var(--space-xs) 0;
      font-size: 0.9rem;
      color: var(--color-text);
    }

    strong {
      color: var(--color-primary);
    }
  }

  .button-container {
    display: flex;
    justify-content: center;
    margin-top: var(--space-lg);
  }

  .vesting-submit-button {
    background-color: var(--color-accent);
    min-width: 200px;

    &:hover:not(:disabled) {
      background-color: var(--color-accent-light);
    }

    &:active:not(:disabled) {
      background-color: var(--color-accent-dark);
    }
  }

  .success-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: var(--color-success);
    background-color: rgba(45, 198, 83, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
    text-align: center;
  }

  .error-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: var(--color-error);
    background-color: rgba(230, 57, 70, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
    text-align: center;
  }

  .auth-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: var(--color-warning-dark);
    background-color: rgba(255, 180, 0, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
    text-align: center;
  }
</style>
