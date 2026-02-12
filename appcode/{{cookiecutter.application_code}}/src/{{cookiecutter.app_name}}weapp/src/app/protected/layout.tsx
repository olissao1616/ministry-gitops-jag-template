import { getServerSession } from "next-auth";
import Header from "../_nonRoutingAssets/components/HeaderComponent"
import { authOptions } from "../api/auth/[...nextauth]/authOptions";
import BCrumbs from "../_nonRoutingAssets/components/BCrumbs";
import { redirect } from "next/navigation";

export default async function protectedLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const session = await getServerSession(authOptions);
  
  if (session && !session?.error) {
    return (
      <>
        <Header></Header>
        <div className="page">
          <BCrumbs />
          {children}
        </div>
      </>
    )
  } else {
    redirect('/signin');
  }
}