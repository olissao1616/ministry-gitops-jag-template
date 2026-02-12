'use server'

import { handleError, axiosClient, buildErrorMessage } from "@/app/_nonRoutingAssets/lib/form.api";
import { type_application } from "./data-types";

//------------------------------------------
// Get participant's application assignments
//------------------------------------------
export const getApplicationData = async (): Promise< [Array<type_application>, string | null] > => {
  let url = '/api/participants/applications';
  console.log("Get participant applications, url: " + axiosClient.getUri() + url);
  try {
    const {data} = await axiosClient.get(url);
    console.debug("Get participant applications returns: " + data);
    return [data, null];
  } catch (error) {
    //handleError(error as object);
    const errorDetails = "Failed fetching application data: " + buildErrorMessage(error);
    console.error(errorDetails);
    return [[], errorDetails];
  }
}