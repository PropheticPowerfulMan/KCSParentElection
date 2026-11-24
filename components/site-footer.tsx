"use client";
import {usePathname} from 'next/navigation';
import Link from 'next/link';
import {ArrowUpRight,Mail,ShieldCheck} from 'lucide-react';
import {useElectionLanguage} from './election-language';
export function SiteFooter(){const path=usePathname(),{tr}=useElectionLanguage();if(/\/(admin|login|vote|candidacy)(\/|$)/.test(path))return null;return <footer className="ev-footer"><div><b>KINSHASA CHRISTIAN SCHOOL</b><p>{tr('Une communauté. Des voix qui comptent.','One community. Every voice matters.')}</p><span><ShieldCheck size={14}/>KCS Orbit Ecosystem</span></div><nav><Link href={path.startsWith('/student-government')?'/student-government/election-information/':'/election-information/'}>{tr('Comprendre le scrutin','How voting works')}</Link><Link href="/admin/login/">{tr('Administration','Administration')}</Link><a href="mailto:kinshasachristianschool@gmail.com"><Mail size={14}/>{tr('Contacter l’école','Contact the school')}</a><a href="https://kinshasachristianschool.org/" target="_blank" rel="noreferrer">{tr('Site de l’école','School website')}<ArrowUpRight size={14}/></a></nav><small>© {new Date().getFullYear()} Kinshasa Christian School · KCS Orbit</small></footer>}
