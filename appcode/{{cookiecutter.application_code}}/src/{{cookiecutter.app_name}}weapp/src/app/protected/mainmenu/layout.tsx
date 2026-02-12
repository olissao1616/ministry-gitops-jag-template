"use client"

import { useAtom } from "jotai";
import ApplicationTable from "../ApplicationComponent";
import AgencyTable from "../agency/AgencyComponent";
import { selectedAgencyAtom, selectedApplicationAtom } from "@/app/_nonRoutingAssets/store/atoms";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { LinearProgress } from "@mui/material";

export default function protectedLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
  const [selectedAgency, setSelectedAgency] = useAtom(selectedAgencyAtom);
  const [isLoading, setIsLoading] = useState(true);
  const pathname = usePathname();
  
  useEffect(() => {
    if (selectedApplication || selectedAgency) {
      setIsLoading(false);
    } else {
      setTimeout(() => {
        setIsLoading(false);
      }, 1000);
    }   
  }, [selectedApplication, selectedAgency])

  return (
    isLoading ? (
      <LinearProgress />
    ) :
    !selectedApplication ? (
      <ApplicationTable></ApplicationTable>
    ) : 
    !selectedAgency ? (
      <AgencyTable pNextPath={pathname}></AgencyTable>
    ) : <>{children}</>
  )
}