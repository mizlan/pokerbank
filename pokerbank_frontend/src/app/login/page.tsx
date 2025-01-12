"use client";

import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/app/store";
import Link from "next/link";
import { useEffect } from "react";

export default function Login() {
  const isSignedIn = useAuthStore((state) => state.isSignedIn);

  useEffect(() => {
    if (isSignedIn) {
    }
  })

  return (
    <div className="w-full p-5 flex flex-col min-h-screen justify-between">
      <Button className="h-12" asChild>
        <Link href="http://localhost:6868/api/login">Sign in with Google</Link>
      </Button>
    </div>
  );
}
