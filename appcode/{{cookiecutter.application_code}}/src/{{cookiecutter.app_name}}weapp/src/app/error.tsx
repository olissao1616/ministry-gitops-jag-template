'use client'
 
import { signIn, signOut, useSession } from "next-auth/react";
import { useEffect } from "react";
import { toast } from "react-toastify";
import { ToastError } from "./_nonRoutingAssets/toastProvider/ToastProvider";


export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
    console.log("error: " + error.stack + "; error.name: " + error.name + "; error.digest: " + error.digest
    + "; error.message: " + error.message + "; error.cause: " + error.cause);
    const { data: session } = useSession();
    
    useEffect(() => {
      console.log("Caught in error page");
      ToastError(`${error}`);  
    }, []);

  return (
    <div>
      <h4>Something went wrong!</h4>
    </div>
  )
}