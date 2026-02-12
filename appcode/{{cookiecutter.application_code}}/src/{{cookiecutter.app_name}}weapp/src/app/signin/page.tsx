"use client"
import { signIn, useSession } from "next-auth/react";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { URL_APPLICATION_SELECT } from "../_nonRoutingAssets/types/const";

export default function Signin() {
  const router = useRouter();
  const { data, status } = useSession();

  useEffect(() => {
    // console.log("status: ", status);
    // console.log("data: ", data);
    if (status === "unauthenticated" || data?.error) {
      void signIn("keycloak");
    } else if (status === "authenticated") {
      void router.push(URL_APPLICATION_SELECT);
    }
  }, [status]);

  return <div></div>;
}