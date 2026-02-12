import { redirect } from 'next/navigation';
import { URL_APPLICATION_SELECT } from './_nonRoutingAssets/types/const';

export default function Home({}) {
   redirect(URL_APPLICATION_SELECT);
}