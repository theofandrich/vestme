<script>
  import "../index.scss";
  import { onMount } from "svelte";
  import { init, auth } from "$lib/state/auth.state.svelte";
  import AuthButtons from "../lib/components/AuthButtons.svelte";
  import { Actor } from "@dfinity/agent";
  import { idlFactory } from "../../../declarations/vest_backend/vest_backend.did.js";
  import VestingCreationForm from "$lib/components/VestingCreationForm.svelte";
  import VestingInfoTable from "$lib/components/VestingInfoTable.svelte";

  // Network configuration
  let backendCanisterId = $state(process.env.CANISTER_ID_VEST_BACKEND);

  // Authentication and user state
  let agent = $derived(auth.agent);
  let pid = $derived(auth.identity?.getPrincipal() || null);
  let isAuthenticated = $derived(auth.isAuthenticated);

  // Backend API
  let backendApi = $state(null);

  // Toggle state for showing either creation form or info table
  let activeView = $state("info"); // Either "create" or "info"

  // Initialize on mount
  onMount(async () => {
    await init();
  });

  // Initialize backend API when authenticated
  $effect(() => {
    if (isAuthenticated) {
      backendApi = Actor.createActor(idlFactory, {
        agent,
        canisterId: backendCanisterId,
      });
    } else {
      backendApi = null;
    }
  });

  // Handle vesting creation to refresh vesting info
  function handleVestingCreated() {
    // Switch to info view after successful creation
    activeView = "info";
  }

  // Copy principal ID to clipboard using a fallback method
  function copyPrincipal() {
    if (pid) {
      const textToCopy = pid.toString();
      const textArea = document.createElement("textarea");
      textArea.value = textToCopy;
      textArea.style.position = "fixed"; // Avoid scrolling to bottom
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        const successful = document.execCommand("copy");
        const msg = successful ? "Copied!" : "Failed to copy";
        const originalText = document.getElementById("principal-display").innerText;
        document.getElementById("principal-display").innerText = msg;
        setTimeout(() => {
          document.getElementById("principal-display").innerText = originalText;
        }, 2000);
      } catch (err) {
        console.error("Fallback: Oops, unable to copy", err);
      }

      document.body.removeChild(textArea);
    }
  }

  // Helper to truncate principal ID
  function truncatePrincipal(principal) {
    if (!principal) return "";
    const text = principal.toString();
    return `${text.substring(0, 5)}...${text.substring(text.length - 5)}`;
  }

  // Toggle between views
  function setActiveView(view) {
    activeView = view;
  }
</script>

<main>
  <header>
    <div class="app-title">Token Vesting App</div>

    <div class="header-right">
      {#if isAuthenticated}
        <div id="principal-display" class="principal-display" title={pid?.toString() || ""} onclick={copyPrincipal}>
          {pid ? truncatePrincipal(pid) : ""}
        </div>
      {/if}
      <AuthButtons />
    </div>
  </header>

  <div class="content">
    {#if isAuthenticated}
      <div class="widget-container">
        <div class="widget">
          <div class="view-toggles">
            <button class="view-toggle-button" class:active={activeView === "info"} onclick={() => setActiveView("info")}> View Vesting Schedules </button>
            <button class="view-toggle-button" class:active={activeView === "create"} onclick={() => setActiveView("create")}> Create New Vesting </button>
          </div>

          <div class="widget-content">
            {#if activeView === "create"}
              <!-- Vesting Creation Form -->
              <VestingCreationForm {backendApi} {backendCanisterId} onVestingCreated={handleVestingCreated} />
            {:else}
              <!-- Vesting Info Table with automatic polling -->
              <VestingInfoTable {backendApi} {isAuthenticated} />
            {/if}
          </div>
        </div>
      </div>
    {:else}
      <!-- Simple login prompt, much more compact -->
      <div class="login-prompt">
        <p>Please sign in to access the vesting application</p>
      </div>
    {/if}
  </div>
</main>

<style>
  main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 16px 32px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  header {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 4px 0;
    margin-bottom: 16px;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .app-title {
    font-size: 1.3rem;
    font-weight: 700;
    color: #0070f3;
  }

  .principal-display {
    padding: 4px 8px;
    background-color: #f0f0f0;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.85rem;
    color: #0070f3;
    font-weight: 600;
  }

  .principal-display:hover {
    background-color: #e0e0e0;
  }

  .content {
    width: 100%;
  }

  .widget-container {
    width: 100%;
  }

  .widget {
    background-color: #ffffff;
    border-radius: 4px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    overflow: hidden;
  }

  .view-toggles {
    display: flex;
    width: 100%;
    border-bottom: 1px solid #cccccc;
  }

  .view-toggle-button {
    padding: 8px 16px;
    border: none;
    border-radius: 0;
    background-color: transparent;
    color: #333333;
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    transition: background-color 0.2s;
    flex: 1;
    max-width: none;
    border-bottom: 2px solid transparent;
  }

  .view-toggle-button:hover {
    background-color: #f0f0f0;
  }

  .view-toggle-button.active {
    color: #0070f3;
    background-color: #f0f0f0;
    border-bottom: 2px solid #0070f3;
  }

  .widget-content {
    padding: 16px;
    animation: fadeIn 0.3s ease;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(5px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .login-prompt {
    text-align: center;
    padding: 8px;
    color: #999999;
    font-size: 0.9rem;
  }

  @media (max-width: 768px) {
    .view-toggles {
      flex-direction: row;
    }

    .view-toggle-button {
      padding: 4px 8px;
      font-size: 0.85rem;
    }
  }
</style>
