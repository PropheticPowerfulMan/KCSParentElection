"use client";
import Image from 'next/image';
import Link from 'next/link';
import {useState} from 'react';
import {ArrowUpRight,Menu,Vote,X} from 'lucide-react';
import kcsLogo from '@/public/kcs.jpg';
import {ElectionControls} from './client-settings';
import {useElectionLanguage} from './election-language';
export function Brand({label='Parent Election',href='/'}:{label?:string;href?:string}){return <Link className="ev-brand" href={href}><Image src={kcsLogo} alt="KCS" width={48} height={48} priority/><span><b>KCS <i>ORBIT</i></b><small>{label}</small></span></Link>}
export function Header({studentGovernment=false}:{studentGovernment?:boolean}){
 const {tr}=useElectionLanguage(),[open,setOpen]=useState(false),base=studentGovernment?'/student-government':'';
 const links=[[base+'/',tr('Accueil','Home')],[base+'/login/',tr('Voter','Vote')],[base+'/candidacy/',tr('Candidature','Apply')],[base+'/results/',tr('Résultats','Results')]];
 return <header className="ev-header"><div className="ev-header-inner"><Brand href={base+'/'} label={studentGovernment?tr('Gouvernement des élèves','Student government'):tr('Comité des parents','Parent committee')}/><nav className={open?'ev-primary-nav open':'ev-primary-nav'} aria-label={tr('Navigation des élections','Election navigation')}>{links.map(([href,label])=><Link key={href} href={href} onClick={()=>setOpen(false)}>{label}</Link>)}<Link href={studentGovernment?'/':'/student-government/'} onClick={()=>setOpen(false)}><Vote size={14}/>{studentGovernment?tr('Élections parents','Parent elections'):tr('Élections élèves','Student elections')}</Link><Link href="https://kinshasachristianschool.org/" target="_blank" rel="noreferrer">Nexus <ArrowUpRight size={13}/></Link></nav><ElectionControls/><button className="ev-menu-toggle" aria-expanded={open} aria-label={tr('Menu','Menu')} onClick={()=>setOpen(v=>!v)}>{open?<X/>:<Menu/>}</button></div></header>
}
