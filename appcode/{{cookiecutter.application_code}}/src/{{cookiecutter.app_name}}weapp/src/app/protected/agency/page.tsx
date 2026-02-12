"use client"
import { selectedApplicationAtom } from '@/app/_nonRoutingAssets/store/atoms';
import AgencyTable from '@/app/protected/agency/AgencyComponent';
import { useAtom } from 'jotai';
import ApplicationTable from '../ApplicationComponent';
import { URL_MAINMENU } from '@/app/_nonRoutingAssets/types/const';

export default function Agency() {
  const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
  
  return (
    !selectedApplication ? (
      <ApplicationTable></ApplicationTable>
    ) : (
      <AgencyTable pNextPath={URL_MAINMENU}></AgencyTable>
    )
  ) 
 }
