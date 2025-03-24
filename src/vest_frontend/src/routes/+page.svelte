<script>
  import "../index.scss";
  import { onMount } from "svelte";
  import { init, auth } from "$lib/state/auth.state.svelte";
  import AuthButtons from "../lib/components/AuthButtons.svelte";
  import { Actor } from "@dfinity/agent";
  import { idlFactory } from "$lib/candid/icrc.did.js";
  import { idlFactory as backendIdlFactory } from "../../../declarations/vest_backend/vest_backend.did.js";
  import { Principal } from "@dfinity/principal";
  import { checkAllowance } from "$lib/services/services";

  // Network configuration
  let backendCanisterId = $state(process.env.CANISTER_ID_VEST_BACKEND);

  // Authentication and user state
  let agent = $derived(auth.agent);
  let pid = $derived(auth.identity?.getPrincipal() || null);
  let isAuthenticated = $derived(auth.isAuthenticated);

  // Token balance state
  let tokenApi = $state(null);
  let backendApi = $state(null);

  let canisterId = $state("");
  let balance = $state(null);
  let isLoading = $state(false);
  let error = $state(null);

  // Vesting form state
  let recipientPrincipal = $state("");
  let vestingAmount = $state(0);
  let vestingPeriods = $state(1);
  let vestingDurationSeconds = $state(60); // Default: 60 seconds
  let vestingDurationMS = $derived(vestingDurationSeconds * 1000); // Convert to ms
  let isVestingLoading = $state(false);
  let vestingError = $state(null);
  let vestingSuccess = $state(false);

  // Vesting information state
  let vestingInfo = $state(null);
  let isLoadingVestingInfo = $state(false);
  let vestingInfoError = $state(null);

  // Add new state for tracking expanded rows
  let expandedRows = $state({});

  // Effects
  $effect(() => {
    if (isAuthenticated && !vestingInfo) {
      loadVestingInfo();
    }
  });

  // Initialize on mount
  onMount(async () => {
    await init();
    if (auth.isAuthenticated) {
      await loadVestingInfo();
    }
  });

  $effect(() => {
    if (isAuthenticated) {
      backendApi = Actor.createActor(backendIdlFactory, {
        agent,
        canisterId: backendCanisterId,
      });
    }
  });

  // Format balance with 8 decimal places
  function formatBalance(rawBalance) {
    if (!rawBalance && rawBalance !== 0) return "—";

    // Convert to number and divide by 10^8 (assuming 8 decimal places)
    const num = Number(rawBalance) / 100000000;

    // Format with commas for thousands and fixed decimal places
    return new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 8,
    }).format(num);
  }

  // Copy principal ID to clipboard
  function copyPrincipal() {
    if (pid) {
      navigator.clipboard.writeText(pid.toString());
      const originalText = document.getElementById("principal-display").innerText;
      document.getElementById("principal-display").innerText = "Copied!";
      setTimeout(() => {
        document.getElementById("principal-display").innerText = originalText;
      }, 2000);
    }
  }

  // Get token balance
  async function handleTokenAction() {
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

      console.log("balance: ", balance);

      if (balance > 0n) {
        let allowance = await checkAllowance(tokenApi, backendCanisterId, pid);
        console.log("allowance: ", allowance);
      }

      isLoading = false;
    } catch (err) {
      error = `Failed to get balance: ${err.message}`;
      isLoading = false;
      balance = null;
    }
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

    try {
      vestingError = null;
      isVestingLoading = true;
      vestingSuccess = false;

      // Convert amount to e8s (assuming 8 decimal places)
      const amountE8s = Math.floor(vestingAmount * 100000000);

      // Call the backend receiveTokens function
      console.log(backendApi);
      await backendApi.receiveTokens(Principal.fromText(recipientPrincipal), BigInt(amountE8s), canisterId, BigInt(vestingPeriods), BigInt(vestingDurationMS));

      vestingSuccess = true;

      // Reset form values
      recipientPrincipal = "";
      vestingAmount = 0;
      vestingPeriods = 1;
      vestingDurationSeconds = 60; // Reset to 60 seconds

      // Refresh vesting info
      await loadVestingInfo();

      isVestingLoading = false;
    } catch (err) {
      vestingError = `Failed to create vesting: ${err.message}`;
      isVestingLoading = false;
    }
  }

  // Load vesting information
  async function loadVestingInfo() {
    if (!isAuthenticated) return;

    try {
      isLoadingVestingInfo = true;
      vestingInfoError = null;

      console.log("backendApi: ", backendApi);
      // Call the backend function to get vesting info
      vestingInfo = await backendApi.getVestingInfo();

      console.log("vestingInfo: ", vestingInfo);

      isLoadingVestingInfo = false;
    } catch (err) {
      vestingInfoError = `Failed to load vesting information: ${err.message}`;
      isLoadingVestingInfo = false;
    }
  }

  // Calculate remaining amount for a vesting entry
  function calculateRemaining(vesting) {
    return Number(vesting.amountStarted) - Number(vesting.amountSent);
  }

  // Calculate vesting progress percentage
  function calculateProgress(vesting) {
    if (Number(vesting.amountStarted) === 0) return 0;
    return Math.min(100, (Number(vesting.amountSent) / Number(vesting.amountStarted)) * 100);
  }

  // Format time duration from nanoseconds to readable form
  function formatDuration(nanoseconds) {
    const milliseconds = Number(nanoseconds) / 1_000_000;
    const seconds = Math.floor(milliseconds / 1000);

    if (seconds < 60) {
      return `${seconds} second${seconds !== 1 ? "s" : ""}`;
    } else if (seconds < 3600) {
      const minutes = Math.floor(seconds / 60);
      const remainingSeconds = seconds % 60;
      return `${minutes} minute${minutes !== 1 ? "s" : ""}${remainingSeconds > 0 ? `, ${remainingSeconds} second${remainingSeconds !== 1 ? "s" : ""}` : ""}`;
    } else {
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      return `${hours} hour${hours !== 1 ? "s" : ""}${minutes > 0 ? `, ${minutes} minute${minutes !== 1 ? "s" : ""}` : ""}`;
    }
  }

  // Reset token API state
  function resetTokenApi() {
    tokenApi = null;
    canisterId = "";
    balance = null;
    error = null;
  }

  // Refresh token balance
  async function refreshBalance() {
    if (!tokenApi || !canisterId) return;

    try {
      error = null;
      isLoading = true;

      // Get the updated balance
      balance = await tokenApi.icrc1_balance_of({
        owner: auth.identity?.getPrincipal(),
        subaccount: [],
      });

      isLoading = false;
    } catch (err) {
      error = `Failed to refresh balance: ${err.message}`;
      isLoading = false;
    }
  }

  // Toggle expansion of a vesting row
  function toggleRowExpansion(index) {
    expandedRows[index] = !expandedRows[index];
    expandedRows = { ...expandedRows }; // Trigger reactivity
  }

  // Format timestamp to human-readable date
  function formatTimestamp(timestamp) {
    return new Date(Number(timestamp) / 1_000_000).toLocaleString();
  }

  // Calculate completed periods
  function calculateCompletedPeriods(vesting) {
    return vesting.entries.length;
  }

  // Calculate total periods
  function getTotalPeriods(vesting) {
    return Number(vesting.periods);
  }

  // Calculate progress for periods
  function calculatePeriodProgress(vesting) {
    const completed = calculateCompletedPeriods(vesting);
    const total = getTotalPeriods(vesting);
    return total > 0 ? Math.min(100, (completed / total) * 100) : 0;
  }
</script>

<main>
  <header>
    <div class="app-title">Token Vesting App</div>

    <div class="header-right">
      {#if isAuthenticated}
        <div id="principal-display" class="principal-display" title={pid?.toString() || ""} onclick={copyPrincipal}>
          {pid ? `${pid.toString().substring(0, 5)}...${pid.toString().substring(pid.toString().length - 5)}` : ""}
        </div>
      {/if}
      <AuthButtons />
    </div>
  </header>

  <div class="content">
    {#if isAuthenticated}
      <div class="widget-container">
        <!-- Token Balance Widget -->
        <div class="widget token-balance-widget">
          <h2>Token Balance</h2>

          {#if !tokenApi || !canisterId}
            <div class="canister-form">
              <input type="text" bind:value={canisterId} placeholder="Enter token canister ID" aria-label="Canister ID" />

              <button type="button" onclick={handleTokenAction} disabled={isLoading} class="token-action-button">
                {isLoading ? "Loading..." : "Get Balance"}
              </button>
            </div>
          {:else}
            <div class="token-info">
              <div class="token-canister-display">
                <span class="token-canister-label">Token Canister:</span>
                <span class="token-canister-value ellipsis" title={canisterId}>
                  {canisterId.length > 15 ? `${canisterId.substring(0, 10)}...${canisterId.substring(canisterId.length - 5)}` : canisterId}
                </span>
              </div>

              <div class="token-actions">
                <button type="button" onclick={refreshBalance} disabled={isLoading} class="refresh-button" title="Refresh balance">
                  {isLoading ? "Loading..." : "↻"}
                </button>

                <button type="button" onclick={resetTokenApi} class="delete-button" title="Change token canister"> ✕ </button>
              </div>
            </div>
          {/if}

          {#if balance !== null}
            <div class="balance-display">
              <span class="balance-label">Your Balance:</span>
              <span class="balance-value">{formatBalance(balance)}</span>
            </div>
          {/if}

          {#if error}
            <div class="error-message">
              {error}
            </div>
          {/if}
        </div>

        <!-- Vesting Creation Widget -->
        <div class="widget vesting-widget">
          <h2>Create Vesting Schedule</h2>

          <div class="vesting-form">
            <div class="form-group">
              <label for="recipientPrincipal">Recipient Principal ID</label>
              <input type="text" id="recipientPrincipal" bind:value={recipientPrincipal} placeholder="Principal ID of recipient" />
            </div>

            <div class="form-group">
              <label for="vestingAmount">Amount to Vest</label>
              <input type="number" id="vestingAmount" bind:value={vestingAmount} min="0" step="0.00000001" />
            </div>

            <div class="form-group">
              <label for="vestingPeriods">Number of Payments</label>
              <input type="number" id="vestingPeriods" bind:value={vestingPeriods} min="1" step="1" />
            </div>

            <div class="form-group">
              <label for="vestingDuration">Payment Interval (seconds)</label>
              <input type="number" id="vestingDuration" bind:value={vestingDurationSeconds} min="1" step="1" placeholder="Enter seconds (e.g. 60 for 1 minute)" />
            </div>

            <button type="button" onclick={handleCreateVesting} disabled={isVestingLoading} class="vesting-action-button">
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
        </div>

        <!-- Vesting Information Widget -->
        <div class="widget vesting-info-widget">
          <div class="widget-header">
            <h2>Your Vesting Information</h2>

            <button type="button" onclick={loadVestingInfo} disabled={isLoadingVestingInfo} class="refresh-button">
              {isLoadingVestingInfo ? "Loading..." : "Refresh"}
            </button>
          </div>

          {#if vestingInfo && vestingInfo.tokens && vestingInfo.tokens.length > 0}
            <div class="vesting-table-container">
              <table class="vesting-table">
                <thead>
                  <tr>
                    <th>Token Canister</th>
                    <th>Recipient</th>
                    <th>Total Amount</th>
                    <th>Progress</th>
                    <th>Periods</th>
                    <th>Started</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {#each vestingInfo.tokens as vesting, index}
                    <tr class="vesting-row" class:expanded={expandedRows[index]}>
                      <td class="ellipsis" title={vesting.tokenCanisterId}>
                        {vesting.tokenCanisterId.substring(0, 10)}...
                      </td>
                      <td class="ellipsis" title={vesting.to.toString()}>
                        {vesting.to.toString().substring(0, 10)}...
                      </td>
                      <td>{formatBalance(vesting.amountStarted)}</td>
                      <td>
                        <div class="progress-container compact">
                          <div class="progress-bar">
                            <div class="progress-fill" style="width: {calculateProgress(vesting)}%"></div>
                          </div>
                          <span class="progress-text">{calculateProgress(vesting).toFixed(1)}%</span>
                        </div>
                      </td>
                      <td>
                        {calculateCompletedPeriods(vesting)}/{getTotalPeriods(vesting)}
                      </td>
                      <td>{formatTimestamp(vesting.timeStarted)}</td>
                      <td>
                        <button class="expand-button" onclick={() => toggleRowExpansion(index)} aria-label={expandedRows[index] ? "Collapse details" : "Expand details"}>
                          {expandedRows[index] ? "▲" : "▼"}
                        </button>
                      </td>
                    </tr>
                    {#if expandedRows[index]}
                      <tr class="details-row">
                        <td colspan="7">
                          <div class="vesting-details-expanded">
                            <div class="details-section">
                              <h4>Vesting Details</h4>
                              <div class="details-grid">
                                <div class="detail-item">
                                  <span class="detail-label">Total Amount:</span>
                                  <span class="detail-value">{formatBalance(vesting.amountStarted)}</span>
                                </div>
                                <div class="detail-item">
                                  <span class="detail-label">Amount Sent:</span>
                                  <span class="detail-value">{formatBalance(vesting.amountSent)}</span>
                                </div>
                                <div class="detail-item">
                                  <span class="detail-label">Remaining:</span>
                                  <span class="detail-value">{formatBalance(calculateRemaining(vesting))}</span>
                                </div>
                                <div class="detail-item">
                                  <span class="detail-label">Period Duration:</span>
                                  <span class="detail-value">{formatDuration(vesting.periodDuration)}</span>
                                </div>
                              </div>
                            </div>

                            <div class="details-section">
                              <h4>Transaction History ({vesting.entries.length} payments)</h4>
                              {#if vesting.entries.length > 0}
                                <table class="transaction-table">
                                  <thead>
                                    <tr>
                                      <th>#</th>
                                      <th>Amount</th>
                                      <th>Date</th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    {#each vesting.entries as entry, entryIndex}
                                      <tr>
                                        <td>{entryIndex + 1}</td>
                                        <td>{formatBalance(entry.amountSent)}</td>
                                        <td>{formatTimestamp(entry.timestamp)}</td>
                                      </tr>
                                    {/each}
                                  </tbody>
                                </table>
                              {:else}
                                <div class="no-transactions">No payments have been made yet</div>
                              {/if}
                            </div>
                          </div>
                        </td>
                      </tr>
                    {/if}
                  {/each}
                </tbody>
              </table>
            </div>
          {:else if vestingInfo && (!vestingInfo.tokens || vestingInfo.tokens.length === 0)}
            <div class="no-data-message">You don't have any active vesting schedules.</div>
          {:else if !vestingInfo && !isLoadingVestingInfo}
            <div class="no-data-message">Click Refresh to load your vesting schedules.</div>
          {/if}

          {#if vestingInfoError}
            <div class="error-message">
              {vestingInfoError}
            </div>
          {/if}
        </div>
      </div>
    {:else}
      <div class="auth-prompt">
        <h2>Welcome to Token Vesting</h2>
        <p>Please sign in to create and manage token vesting schedules.</p>
      </div>
    {/if}
  </div>
</main>

<style lang="scss">
  main {
    max-width: 1200px;
    margin: 0 auto;
    padding: var(--space-lg);
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  header {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-md) 0;
    margin-bottom: var(--space-xl);
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: var(--space-md);
  }

  .app-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .principal-display {
    padding: var(--space-sm) var(--space-md);
    background-color: var(--color-background);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-size: 0.9rem;
    color: var(--color-primary);
    font-weight: 600;

    &:hover {
      background-color: var(--color-secondary-light);
    }
  }

  .content {
    width: 100%;
  }

  .widget-container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: var(--space-lg);
    width: 100%;
  }

  .widget {
    background-color: var(--color-surface);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: var(--space-lg);
    height: fit-content;
  }

  .widget-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--space-md);
  }

  h2 {
    color: var(--color-primary);
    margin-bottom: var(--space-md);
  }

  .canister-form {
    display: flex;
    gap: var(--space-md);
    margin-bottom: var(--space-lg);
    align-items: center;
  }

  input[type="text"],
  input[type="number"] {
    flex: 1;
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

  .token-action-button {
    background-color: var(--color-secondary);
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

  label {
    font-weight: 600;
    color: var(--color-text);
    font-size: 0.9rem;
  }

  button {
    padding: var(--space-sm) var(--space-md);
    border: none;
    border-radius: var(--radius-sm);
    font-weight: 600;
    cursor: pointer;
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

  .vesting-action-button {
    background-color: var(--color-primary);
    color: white;
    padding: var(--space-md);
    margin-top: var(--space-sm);
  }

  .refresh-button {
    background-color: var(--color-text-light);
    color: white;
    font-size: 0.9rem;
    padding: var(--space-xs) var(--space-md);
  }

  .balance-display {
    padding: var(--space-md);
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
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--color-primary);
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

  .vesting-table-container {
    overflow-x: auto;
    margin-top: var(--space-md);
  }

  .vesting-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;

    th,
    td {
      padding: var(--space-sm);
      text-align: left;
      border-bottom: 1px solid var(--color-border);
    }

    th {
      font-weight: 600;
      color: var(--color-text-light);
      background-color: var(--color-background);
    }

    tbody tr:hover {
      background-color: var(--color-background);
    }
  }

  .vesting-row {
    cursor: pointer;
    transition: background-color 0.2s;

    &.expanded {
      background-color: var(--color-background) !important;
      border-bottom: none;
    }
  }

  .details-row {
    background-color: var(--color-background);

    td {
      padding: var(--space-md);
    }
  }

  .vesting-details-expanded {
    display: flex;
    flex-direction: column;
    gap: var(--space-lg);
  }

  .details-section {
    h4 {
      margin-top: 0;
      margin-bottom: var(--space-sm);
      color: var(--color-primary);
      font-size: 1rem;
    }
  }

  .details-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: var(--space-md);
  }

  .detail-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .transaction-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;

    th,
    td {
      padding: var(--space-xs) var(--space-sm);
      text-align: left;
      border-bottom: 1px solid var(--color-border-light);
    }

    th {
      font-weight: 600;
      color: var(--color-text-light);
    }

    tbody tr:nth-child(odd) {
      background-color: rgba(0, 0, 0, 0.02);
    }
  }

  .expand-button {
    background: none;
    border: none;
    color: var(--color-primary);
    cursor: pointer;
    font-size: 0.8rem;
    padding: var(--space-xs);

    &:hover {
      background-color: var(--color-secondary-light);
      border-radius: var(--radius-sm);
    }
  }

  .progress-container.compact {
    display: flex;
    align-items: center;
    gap: var(--space-xs);

    .progress-bar {
      width: 80px;
      height: 6px;
    }

    .progress-text {
      font-size: 0.8rem;
      min-width: 40px;
    }
  }

  .no-transactions {
    color: var(--color-text-light);
    font-style: italic;
    padding: var(--space-sm) 0;
  }

  .no-data-message {
    text-align: center;
    padding: var(--space-md);
    color: var(--color-text-light);
  }

  .auth-prompt {
    text-align: center;
    padding: var(--space-xl);

    h2 {
      margin-bottom: var(--space-md);
    }

    p {
      color: var(--color-text-light);
    }
  }

  @media (max-width: 768px) {
    .widget-container {
      grid-template-columns: 1fr;
    }

    .vesting-table {
      font-size: 0.8rem;

      th,
      td {
        padding: var(--space-xs);
      }
    }

    .details-grid {
      grid-template-columns: 1fr;
    }
  }

  .token-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--space-lg);
    background-color: var(--color-background);
    border-radius: var(--radius-md);
    padding: var(--space-sm) var(--space-md);
  }

  .token-canister-display {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .token-canister-label {
    font-size: 0.8rem;
    color: var(--color-text-light);
  }

  .token-canister-value {
    font-weight: 600;
    color: var(--color-primary);
  }

  .token-actions {
    display: flex;
    gap: var(--space-xs);
  }

  .refresh-button,
  .delete-button {
    width: 32px;
    height: 32px;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.1rem;
  }

  .refresh-button {
    background-color: var(--color-secondary);
    color: white;
  }

  .delete-button {
    background-color: var(--color-error);
    color: white;
  }

  .ellipsis {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
  }
</style>
