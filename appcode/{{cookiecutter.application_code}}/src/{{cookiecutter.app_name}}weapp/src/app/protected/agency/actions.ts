'use server'

import { handleError, axiosClient, buildErrorMessage } from "@/app/_nonRoutingAssets/lib/form.api";
import { type_agency } from "./data-types";

//------------------------------------------
// Get paticipants agency assignments APIs
//------------------------------------------
export const getAgencyData = async (): Promise< [Array<type_agency>, string | null] > => {
  let url = '/api/participants/agencyAssignments';
  console.log("Get participant agencies, url: " + axiosClient.getUri() + url);
  
  try {
    const { data } = await axiosClient.get(url);
    console.debug("Get participant agencies returns: " + data);
    return [data, null];
  }catch (error) {
    const errorDetails = "Failed fetching agency data: " + buildErrorMessage(error);
    console.error(errorDetails);
    return [[], errorDetails];
  }
}
