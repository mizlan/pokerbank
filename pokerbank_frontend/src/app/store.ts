import { create } from "zustand";

interface AuthStore {
  isSignedIn: boolean;
  setIsSignedIn: (isSignedIn: boolean) => void;
}

const useAuthStore = create<AuthStore>((set) => ({
  /* the client's best guess as to whether we are signed in:
   * if we ever attempt to call backend API and it reports that
   * we are unauthenticated, we set this to false and redirect
   * to `/login` */
  isSignedIn: false,
  setIsSignedIn: (isSignedIn: boolean) => set({ isSignedIn }),
}));

/* state about the session information should not be managed by
 * zustand, it is *server state* not client state and should
 * be managed by swr or TanStack Query etc. */

export { useAuthStore };
