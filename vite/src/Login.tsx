import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/store";
import { useEffect } from "react";
import { useNavigate } from "react-router";

export default function Login() {
  const isSignedIn = useAuthStore((state) => state.isSignedIn);
  let navigate = useNavigate();

  useEffect(() => {
    if (isSignedIn) {
      // redirect
      navigate("/");
    }
  });

  return (
    <div className="w-full p-5 flex flex-col min-h-screen justify-between">
      <Button className="h-12" asChild>
        {/* Don't use a Link, this is proxied in dev */}
        <a href="/api/login">Sign in with Google</a>
      </Button>
    </div>
  );
}
