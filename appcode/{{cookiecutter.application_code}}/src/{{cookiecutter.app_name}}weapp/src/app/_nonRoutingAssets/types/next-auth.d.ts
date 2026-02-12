import { Session, JWT } from "next-auth"

/** Extend the built-in session types */
declare module "next-auth" {
  interface Session extends Session {
    access_token: string;
    id_token: string;
    refresh_token: string;
    expires_at: number;
    error?: "RefreshAccessTokenError";
  }
}

declare module 'next-auth/jwt' {
  interface JWT extends DefaultJWT {
    access_token: string | undefined;
    id_token: string | undefined;
    refresh_token: string | undefined;
    expires_at: number;
    error?: "RefreshAccessTokenError";
  }
}