import Image from 'next/image';
import bcgovlogo from '../assets/images/gov_bc_logo.svg'
import UserCard from "./UserCard";
import { getServerSession } from "next-auth/next";
import { authOptions } from "../../api/auth/[...nextauth]/authOptions";
import Nav from './Nav';

export default async function Header() {
  const session = await getServerSession(authOptions);

  return (
    <>
      {session ? (
      <div className="header">
        <div className="header-top">
          <div className="flex-item header-section">
            <div className="header-img">
              <a href="https://gov.bc.ca">
                <Image src={bcgovlogo} alt="gov bc logo" width={155} height={42}/>  
              </a>
            </div>
            <span className="headerText">Ministry of Attorney General</span>
          </div>
          <UserCard user={session?.user} />
          
        </div>
        <Nav />
      </div>
      ): (
        <span></span>
      )}
    </>
  );
}

