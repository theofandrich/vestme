<script>
  import "../index.scss";
  import { backend } from "$lib/utils/canisters";
  import { onMount } from "svelte";
  import { init } from "$lib/state/auth.state.svelte";
  import AuthButtons from "../lib/components/AuthButtons.svelte";

  let greeting = $state("");

  onMount(async () => {
    init();
  });

  const onSubmit = async (event) => {
    event.preventDefault();
    const name = event.target.name.value;
    backend.greet(name).then((response) => {
      greeting = response;
    });
    return false;
  };
</script>

<main>
  <br />
  <br />

  <AuthButtons />

  <form action="#" onsubmit={onSubmit}>
    <label for="name">Enter your name: &nbsp;</label>
    <input id="name" alt="Name" type="text" />
    <button type="submit">Click Me!</button>
  </form>
  <section id="greeting">{greeting}</section>
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
</style>
