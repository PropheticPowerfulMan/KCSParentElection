"use client";
import type {ReactNode} from 'react';
import {usePathname} from 'next/navigation';
import {ElectionAdmin} from '@/components/election-admin';
export default function AdminLayout({children}:{children:ReactNode}){
 const path=usePathname(),section=path.split('/').filter(Boolean)[1]||'dashboard';
 return ['login','sso'].includes(section)?children:<ElectionAdmin audience="PARENT" section={section}/>;
}
