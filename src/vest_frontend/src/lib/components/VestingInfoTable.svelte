<script>
  import { onMount, onDestroy } from "svelte";

  // Props
  let { backendApi, isAuthenticated } = $props();

  // State
  let vestingInfo = $state(null);
  let isLoadingVestingInfo = $state(false);
  let vestingInfoError = $state(null);
  let expandedRows = $state({});
  let pollingInterval = $state(null);

  // Initialize on mount with polling
  onMount(() => {
    if (isAuthenticated) {
      loadVestingInfo();
      // Set up polling every 1000ms
      pollingInterval = setInterval(() => {
        if (isAuthenticated) {
          loadVestingInfo(true);
        }
      }, 1000);
    }
  });

  // Clean up     on component destroy
  onDestroy(() => {
    if (pollingInterval) {
      clearInterval(pollingInterval);
    }
  });

  // Watch for authentication changes
  $effect(() => {
    if (isAuthenticated && !pollingInterval) {
      loadVestingInfo();
      pollingInterval = setInterval(() => {
        if (isAuthenticated) {
          loadVestingInfo(true);
        }
      }, 1000);
    } else if (!isAuthenticated && pollingInterval) {
      clearInterval(pollingInterval);
      pollingInterval = null;
    }
  });

  // Load vesting information
  async function loadVestingInfo(silent = false) {
    if (!isAuthenticated || (!silent && isLoadingVestingInfo)) return;

    try {
      if (!silent) isLoadingVestingInfo = true;
      vestingInfoError = null;

      // Call the backend function to get vesting info
      const newVestingInfo = await backendApi.getVestingInfo();

      // If vestingInfo has a tokens property, use that instead (for backward compatibility)
      vestingInfo = newVestingInfo && newVestingInfo.tokens ? newVestingInfo.tokens : newVestingInfo;

      if (!silent) isLoadingVestingInfo = false;
    } catch (err) {
      if (!silent) {
        vestingInfoError = `Failed to load vesting information: ${err.message}`;
        isLoadingVestingInfo = false;
      }
    }
  }

  // Format balance with 8 decimal places
  function formatBalance(rawBalance) {
    if (!rawBalance && rawBalance !== 0) return "—";
    const num = Number(rawBalance) / 100000000;
    return new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 8,
    }).format(num);
  }

  // Truncate ID for display
  function truncateId(id) {
    if (!id) return "";
    return `${id.substring(0, 5)}...${id.substring(id.length - 5)}`;
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
    const completed = vesting.entries.length;
    const total = Number(vesting.periods);
    return total > 0 ? Math.min(100, (completed / total) * 100) : 0;
  }

  // Toggle expansion of a vesting row
  function toggleRowExpansion(index) {
    expandedRows[index] = !expandedRows[index];
    expandedRows = { ...expandedRows }; // Trigger reactivity
  }

  // Manual refresh function
  function refreshVestingInfo() {
    loadVestingInfo();
  }
</script>

<div class="widget vesting-info-widget">
  <div class="widget-header">
    <h2>Vesting Info</h2>
    <button type="button" onclick={refreshVestingInfo} disabled={isLoadingVestingInfo} class="refresh-button">
      {isLoadingVestingInfo ? "Loading..." : "Refresh"}
    </button>
  </div>

  {#if vestingInfo && vestingInfo.length > 0}
    <div class="vesting-table-container">
      <table class="vesting-table">
        <thead>
          <tr>
            <th>Token Canister</th>
            <th>Recipient</th>
            <th>Progress</th>
            <th>Amount</th>
            <th>Periods</th>
            <th>Started</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {#each vestingInfo as vesting, index}
            <tr class="vesting-row" class:expanded={expandedRows[index]} onclick={() => toggleRowExpansion(index)}>
              <td class="ellipsis" title={vesting.tokenCanisterId}>
                {truncateId(vesting.tokenCanisterId)}
              </td>
              <td class="ellipsis" title={vesting.to?.__principal__ || vesting.to?.toString()}>
                {truncateId(vesting.to?.__principal__ || vesting.to?.toString())}
              </td>
              <td>
                <div class="progress-circle-container">
                  <div class="progress-circle" style="--progress: {calculateProgress(vesting)}%">
                    <div class="progress-circle-inner">
                      <span>{calculateProgress(vesting).toFixed(0)}%</span>
                    </div>
                  </div>
                </div>
              </td>
              <td>
                <div class="amount-info">
                  <div>{formatBalance(vesting.amountSent)} / {formatBalance(vesting.amountStarted)}</div>
                  <div class="amount-remaining">Remaining: {formatBalance(calculateRemaining(vesting))}</div>
                </div>
              </td>
              <td>
                <div class="periods-info">
                  <div class="periods-fraction">{vesting.entries.length} / {getTotalPeriods(vesting)}</div>
                  <div class="periods-progress-bar">
                    <div class="periods-progress-fill" style="width: {calculatePeriodProgress(vesting)}%"></div>
                  </div>
                </div>
              </td>
              <td>{formatTimestamp(vesting.timeStarted)}</td>
              <td>
                <span class="expand-indicator">
                  {expandedRows[index] ? "▲" : "▼"}
                </span>
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
                      <h4>Payment History ({vesting.entries.length} of {getTotalPeriods(vesting)} payments)</h4>
                      {#if vesting.entries.length > 0}
                        <table class="transaction-table">
                          <thead>
                            <tr>
                              <th>#</th>
                              <th>Amount</th>
                              <th>Date</th>
                              <th>% of Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {#each vesting.entries as entry, entryIndex}
                              <tr>
                                <td>{entryIndex + 1}</td>
                                <td>{formatBalance(entry.amountSent)}</td>
                                <td>{formatTimestamp(entry.timestamp)}</td>
                                <td>
                                  {((Number(entry.amountSent) / Number(vesting.amountStarted)) * 100).toFixed(1)}%
                                </td>
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
  {:else if vestingInfo && vestingInfo.length === 0}
    <div class="no-data-message">You don't have any active vesting schedules.</div>
  {:else if !vestingInfo && !isLoadingVestingInfo}
    <div class="no-data-message">Loading your vesting schedules...</div>
  {/if}

  {#if vestingInfoError}
    <div class="error-message">
      {vestingInfoError}
    </div>
  {/if}
</div>

<style lang="scss">
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
    margin-bottom: 0;
  }

  h4 {
    margin-top: 0;
    margin-bottom: var(--space-sm);
    color: var(--color-primary);
    font-size: 1rem;
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

  .refresh-button {
    background-color: var(--color-secondary);
    color: white;
    font-size: 1rem;
    padding: var(--space-sm) var(--space-md);
    min-width: 100px;
    border-radius: var(--radius-sm);
    border: none;
    cursor: pointer;
    transition: background-color 0.2s;
    font-weight: 600;

    &:hover:not(:disabled) {
      background-color: var(--color-primary-light);
    }

    &:disabled {
      background-color: var(--color-text-light);
      cursor: not-allowed;
      opacity: 0.7;
    }
  }

  .vesting-row {
    cursor: pointer;
    transition: background-color 0.2s;

    &:hover {
      background-color: var(--color-background-hover, rgba(0, 0, 0, 0.03));
    }

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
      margin-bottom: var(--space-sm);
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

  .detail-label {
    font-size: 0.8rem;
    color: var(--color-text-light);
  }

  .detail-value {
    font-weight: 600;
  }

  .ellipsis {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 120px;
  }

  .progress-circle-container {
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .progress-circle {
    position: relative;
    width: 50px;
    height: 50px;
    border-radius: 50%;
    background: #e6e6e6;
    background-image: conic-gradient(var(--color-primary) var(--progress), transparent 0);
    display: flex;
    justify-content: center;
    align-items: center;

    &::before {
      content: "";
      position: absolute;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: white;
    }
  }

  .progress-circle-inner {
    position: relative;
    z-index: 1;
    font-weight: bold;
    font-size: 0.85rem;
    color: var(--color-primary);
  }

  .amount-info {
    display: flex;
    flex-direction: column;
    gap: 2px;

    .amount-remaining {
      font-size: 0.8rem;
      color: var(--color-text-light);
    }
  }

  .periods-info {
    display: flex;
    flex-direction: column;
    gap: 4px;

    .periods-fraction {
      font-weight: 600;
    }

    .periods-progress-bar {
      height: 6px;
      width: 100%;
      background-color: #e6e6e6;
      border-radius: 3px;
      overflow: hidden;
    }

    .periods-progress-fill {
      height: 100%;
      background-color: var(--color-secondary);
      border-radius: 3px;
    }
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

  .expand-indicator {
    color: var(--color-primary);
    font-size: 0.8rem;
    display: flex;
    justify-content: center;
  }

  .error-message {
    margin-top: var(--space-md);
    padding: var(--space-sm);
    color: var(--color-error);
    background-color: rgba(230, 57, 70, 0.1);
    border-radius: var(--radius-sm);
    font-size: 0.9rem;
  }

  .no-data-message {
    text-align: center;
    padding: var(--space-md);
    color: var(--color-text-light);
  }

  .no-transactions {
    color: var(--color-text-light);
    font-style: italic;
    padding: var(--space-sm) 0;
  }

  @media (max-width: 768px) {
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
</style>
