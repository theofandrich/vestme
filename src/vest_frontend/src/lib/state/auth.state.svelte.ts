import { AuthClient } from "@dfinity/auth-client";

export const auth = $state({
  authClient: null,
  isAuthenticated: false,
  identity: null,
});


let isLocal = process.env.DFX_NETWORK === "local";

const getIdentityProvider = () => {
    let idpProvider;
    // Safeguard against server rendering
    if (typeof window !== "undefined") {

      // Safari does not support localhost subdomains
      const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
      if (isLocal && isSafari) {
        idpProvider = `http://localhost:4943/?canisterId=${process.env.CANISTER_ID_INTERNET_IDENTITY}`;
      } else if (isLocal) {
        idpProvider = `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943`;
      }
    }
    return idpProvider;
  };

const defaultOptions = {
    /**
     *  @type {import("@dfinity/auth-client").AuthClientCreateOptions}
     */
    createOptions: {
        idleOptions: {
        // Set to true if you do not want idle functionality
        disableIdle: true,
        },
    },
    /**
     * @type {import("@dfinity/auth-client").AuthClientLoginOptions}
    */

    loginOptions: {
        identityProvider: getIdentityProvider(),
        derivationOrigin : isLocal ? "http://localhost:3000" : "https://vestme.xyz",
        maxTimeToLive: BigInt(4) * BigInt (7) * BigInt(24) * BigInt(3_600_000_000_000), // 4 weeks
    },
};

export const init = async () => {
  const authClient = await AuthClient.create(defaultOptions.createOptions);
  const isAuthenticated: boolean = await authClient.isAuthenticated();
      
  auth.authClient = authClient;
  auth.isAuthenticated = isAuthenticated;
  auth.identity = isAuthenticated ? authClient.getIdentity() : null

}

export const login = async () => {
  await auth.authClient.login({
      ...defaultOptions.loginOptions,
      onSuccess: async () => {
          auth.identity = auth.authClient?.getIdentity()
          auth.isAuthenticated = true;
      },
      onError: (error: any) => {
          console.error(error)
      }
  });
}

export const logout = async () => {
  const authClient = auth.authClient ?? (AuthClient.create(defaultOptions.createOptions));

  await authClient.logout();

  auth.isAuthenticated = false;
  auth.authClient = null;
  auth.identity = null;

  auth.authClient = await AuthClient.create(defaultOptions.createOptions);
}