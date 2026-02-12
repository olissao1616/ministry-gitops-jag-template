import { NextAuthOptions } from "next-auth";
import KeycloakProvider from "next-auth/providers/keycloak";
import { JWT } from "next-auth/jwt";
//import { type TokenSet } from "next-auth/core/types";

// this performs the final handshake for the keycloak provider
async function signoutKeycloakSession(jwt: JWT) {
    const { id_token } = jwt;    
    try {
        // Add the id_token_hint to the query string
        const params = new URLSearchParams();
        params.append('id_token_hint', id_token as string);
        const { status, statusText } = await fetch(`${process.env.KEYCLOAK_URL}${process.env.KEYCLOAK_REALM}/protocol/openid-connect/logout?${params.toString()}`, 
            {
                method: "get",
            }         
        );
        console.log("signout results, status: , statusText: ", status, statusText);
        // The response body should contain a confirmation that the user has been logged out
        //console.log("Completed post-logout handshake", status, statusText);
    }
    catch (e: any) {
        console.error("Unable to perform post-logout handshake", (e )?.code || e)
    }

}

export const authOptions: NextAuthOptions = {
    // Configure keycloak provider
    // sample issuer: https://my-keycloak-domain.com/realms/My_Realm
    providers: [
        KeycloakProvider({
            clientId: `${process.env.KEYCLOAK_CLIENT_ID}`,
            clientSecret: '',
            issuer: `${process.env.KEYCLOAK_URL}${process.env.KEYCLOAK_REALM}`, 
        })
    ],
    session: {
        strategy: "jwt",
        // Seconds - How long until an idle session expires and is no longer valid.
        // maxAge: 30 * 24 * 60 * 60, // 30 days

        // Seconds - Throttle how frequently to write to database to extend a session.
        // Use it to limit write operations. Set to 0 to always update the database.
        // Note: This option is ignored if using JSON Web Tokens
        // updateAge: 24 * 60 * 60, // 24 hours
    },
    callbacks: {
        async jwt({ token, account }) {
            // Persist the OAuth access_token to the token right after signin
            if (account) {
                //console.log("keycloak signed in: ", account);

                let expiresAt = 0;
                if (account?.expires_at) {
                    expiresAt = account?.expires_at;
                }
                
                token.access_token = account.access_token;
                token.id_token = account.id_token;
                token.expires_at = expiresAt * 1000;
                token.refresh_token = account.refresh_token;
                return token;
                
            } else if (Date.now() < token.expires_at) {
                //console.log("keycloak signin not expired: ");
                // If the access token has not expired yet, return it
                return token
            } else {
                // If the access token has expired, try to refresh it
                //console.log("keycloak signin expired: ");
                try {
                    const response = await fetch(`${process.env.KEYCLOAK_URL}${process.env.KEYCLOAK_REALM}/protocol/openid-connect/token`, {
                        headers: { 
                            "Content-Type": "application/x-www-form-urlencoded" 
                        },
                        body: new URLSearchParams({
                            client_id: `${process.env.KEYCLOAK_CLIENT_ID}`,
                            grant_type: 'refresh_token',
                            refresh_token: token?.refresh_token ?? '',
                        }),
                        method: "POST",
                    })
                    const newToken = await response.json();
                    if (!response.ok) throw newToken;
                    
                    //console.log("new token: ", newToken);
                    //console.log("new token: ", newToken.expires_in, newToken.expires_in * 1000 + Date.now());
                    return {
                        ...token, // Keep the previous token properties
                        access_token: newToken.access_token,
                        id_token: newToken.id_token,
                        expires_at: newToken.expires_in * 1000 + Date.now(),  //expires_at (seconds)
                        // Fall back to old refresh token, but note that
                        refresh_token: newToken.refresh_token ?? token.refresh_token,
                    }
                } catch (error) {
                    console.debug("Access token refresh failed since the token's been idled for too long, force user to re-login.")
                    // The error property will be used client-side to handle the refresh token error
                    return { ...token, error: "RefreshAccessTokenError" }
                }
            }
        },
        async session({ session, token, user }) {
            // Send properties (e.g., the access_token from keycloak provider) to the client
            // Make sure you extend the Session object to include the custom properties. 
            session.access_token = token.access_token as string;
            session.id_token = token.id_token as string;
            session.error = token.error;
            return session;
        },
    },
    events: {
        signOut: ({ session, token }) => signoutKeycloakSession(token)
    },
    // Enable debug messages in the console if you are having problems
    debug: false,
}