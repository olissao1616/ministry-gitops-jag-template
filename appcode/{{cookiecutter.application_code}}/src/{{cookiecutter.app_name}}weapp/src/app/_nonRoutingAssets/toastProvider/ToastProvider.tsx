'use client';
import { ReactNode } from 'react';
import { Slide, ToastContainer, toast } from 'react-toastify';
import "react-toastify/dist/ReactToastify.css";

export default function ToastProvider({ children }: { children: ReactNode }) {
        return (
                <>
                        {children}
                        <ToastContainer 
                        position="bottom-right"
                        autoClose={5000}
                        hideProgressBar={false}
                        newestOnTop={false}                
                        rtl={false}
                        pauseOnFocusLoss
                        closeOnClick
                        draggable
                        pauseOnHover
                        theme="light" 
                        /> 
                </>
        );
}

export function ToastError (error: string | null) {
  return toast.error(error);
}