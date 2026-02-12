import type { Metadata } from 'next'
import AuthProviders from './_nonRoutingAssets/authProviders/Providers';
import StoreProvider from './_nonRoutingAssets/store/StoreProvider';
import ThemeRegistry from './_nonRoutingAssets/themeRegistry/ThemeRegistry';
import QueryClientProviders from './_nonRoutingAssets/queryClientProvider/Providers';
import ToastProvider from './_nonRoutingAssets/toastProvider/ToastProvider';

export const metadata: Metadata = {
  title: 'LEA app',
  description: 'LEA app desc',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <AuthProviders>
          <StoreProvider>
            <ThemeRegistry>
              <QueryClientProviders>
                <ToastProvider>
                  {children}
                </ToastProvider>
              </QueryClientProviders>
            </ThemeRegistry>
          </StoreProvider> 
        </AuthProviders>
      </body>
    </html>
  )
}
