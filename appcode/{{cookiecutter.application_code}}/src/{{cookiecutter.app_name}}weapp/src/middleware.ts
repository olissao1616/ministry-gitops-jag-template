//export { default } from "next-auth/middleware"
//export const config = { matcher: ['/', '/about'] }

import { withAuth } from "next-auth/middleware";
import { redirect } from "next/navigation";

export default withAuth({
    callbacks: {
      authorized: async ({ req, token }) => {
        const pathname = req.url;
        // console.log("pathname: ", pathname);
        // console.log("token?.error: ", token?.error);
        
        // make routes starting with '/api/public/* ' unprotected
        if (pathname.indexOf('/api/public') > 0) return true;
        if (token && !token?.error) return true;
        if (pathname === `${process.env.NEXT_PUBLIC_SITE_URL}/signin`) return true;
        
        return false;
      },
    },
    pages: {
      signIn: "/signin",
    },
  });