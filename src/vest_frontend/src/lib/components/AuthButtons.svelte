<script>
  import { login, logout } from "$lib/state/auth.state.svelte";

  // We're using the auth state from the auth.state.svelte file
  import { auth } from "$lib/state/auth.state.svelte";
</script>

<div class="auth-controls">
  {#if auth.isAuthenticated}
    <button class="auth-button logout" onclick={logout}>
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
        <polyline points="16 17 21 12 16 7" />
        <line x1="21" y1="12" x2="9" y2="12" />
      </svg>
      Logout
    </button>
  {:else}
    <button class="auth-button login" onclick={login}>
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" />
        <polyline points="10 17 15 12 10 7" />
        <line x1="15" y1="12" x2="3" y2="12" />
      </svg>
      Login with Internet Identity
    </button>
  {/if}
</div>

<style>
  /* Additional component-specific styles can go here */
  .auth-controls {
    margin-bottom: var(--space-xl);
  }

  .auth-button svg {
    margin-right: var(--space-xs);
  }
</style>
