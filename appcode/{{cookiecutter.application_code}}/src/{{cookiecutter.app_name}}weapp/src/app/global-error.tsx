'use client'

import { useEffect } from "react";
import { toast } from "react-toastify";
import { ToastError } from "./_nonRoutingAssets/toastProvider/ToastProvider";

 
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {

  useEffect(() => {
    console.log("Caught in global error page");
    ToastError(`${error}`);  
  }, []);


  return (
    <html>
      <body>
        <h2>Something went wrong!</h2>
        <button onClick={() => reset()}>Try again</button>
      </body>
    </html>
  )
}