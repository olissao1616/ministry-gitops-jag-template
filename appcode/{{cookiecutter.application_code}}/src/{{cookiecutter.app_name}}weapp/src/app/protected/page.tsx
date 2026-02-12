"use client"
import ApplicationTable from '@/app/protected/ApplicationComponent';
import { useAtom } from 'jotai';
import { selectedApplicationAtom } from '../_nonRoutingAssets/store/atoms';
import AgencyTable from './agency/AgencyComponent';
import { URL_MAINMENU } from '../_nonRoutingAssets/types/const';
import { useEffect, useState } from 'react';
import { LinearProgress } from '@mui/material';

export default function ApplicationSelection() {  
  const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    if (selectedApplication) {
      setIsLoading(false);
    } else {
      setTimeout(() => {
        setIsLoading(false);
      }, 1000);
    } 
  }, [selectedApplication])

  
  return (
    isLoading ? (
      <LinearProgress />
    ) :
    !selectedApplication ? (
      <ApplicationTable></ApplicationTable>
    ) : (
      <AgencyTable pNextPath={URL_MAINMENU}></AgencyTable>
    )
  )
}
