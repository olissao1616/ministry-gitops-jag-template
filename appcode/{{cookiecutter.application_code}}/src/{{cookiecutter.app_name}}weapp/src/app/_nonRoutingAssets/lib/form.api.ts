import axios, { AxiosError } from 'axios';
import { getServerSession } from 'next-auth/next';
import { authOptions } from '../../api/auth/[...nextauth]/authOptions';
import { v4 as uuid } from 'uuid';

export const axiosClient = axios.create({
  baseURL: `${process.env.LEA_API_ENDPOINT}`,
  timeout: parseInt(`${process.env.KEEP_ALIVE_TIMEOUT}`),
});


// Request interceptor
axiosClient.interceptors.request.use(
  async (config) => {
    const session = await getServerSession(authOptions);
    if (session?.access_token && !session?.error) {
      config.headers["Application-Code"] = 'LEA';
      config.headers["Transaction-Id"] = uuid();
      config.headers["Authorization"] = 'Bearer ' + session?.access_token;
    }
    return config;
  }
);

//Response interceptor
axiosClient.interceptors.response.use(
  function (response) {
    // Any status code that lie within the range of 2xx cause this function to trigger
    // Do something with response data
    return response;
  }, 
  function (error) {
    // Any status codes that falls outside the range of 2xx cause this function to trigger
    // Do something with response error
    handleError(error);
    // keep propagating the error
    return Promise.reject(error);
    // Stop the error
    //Promise.resolve(error);
  }
);

export function handleError(error: object) {
  console.log("Axios call failed with this error: " + error);
}


export function buildErrorMessage(error: unknown) {
  let message = ''
  if (error instanceof AxiosError) {
    if (error.response && error.response.data) {
        message = error.response.data.errorMessage || error.message;
    } else {
      message = error.message;
    }
  } else {
    message = error as string;
  }
  return message;
}