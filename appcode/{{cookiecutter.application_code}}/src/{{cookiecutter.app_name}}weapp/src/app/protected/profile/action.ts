'use server'

import { handleError, axiosClient, buildErrorMessage } from "@/app/_nonRoutingAssets/lib/form.api";
import { UserResponse } from "./data-types";

//------------------------------------------
// Get user profile APIs
//------------------------------------------
export const fetchUserData = async (): Promise<UserResponse | null>  => {
  let url = '/api/me';
  console.log("Get profile, url: " + axiosClient.getUri() + url);
  
  try {
    const { data } = await axiosClient.get(url);
    console.debug("Get profile returns: " + data);
    return data;
  }catch (error) {
    const errorDetails = "Failed profile data: " + buildErrorMessage(error);
    console.error(errorDetails);
    return null
  }
}