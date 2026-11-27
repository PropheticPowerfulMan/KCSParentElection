"use client";
import{usePathname}from'next/navigation';
import{electionPwa}from'@/lib/election-pwa';
import {useEffect} from 'react';
import {Globe,Moon,Sun} from 'lucide-react';
import {useElectionLanguage,useElectionTheme,setElectionLanguage} from './election-language';
export function ElectionControls(){const {fr,tr}=useElectionLanguage(),{theme,toggle}=useElectionTheme();return <div className="ev-controls"><div aria-label={tr('Langue','Language')}><Globe size={14}/><button type="button" aria-pressed={fr} onClick={()=>setElectionLanguage('fr')}>FR</button><button type="button" aria-pressed={!fr} onClick={()=>setElectionLanguage('en')}>EN</button></div><button type="button" className="ev-theme" onClick={toggle} aria-label={theme==='dark'?tr('Mode soleil','Light mode'):tr('Mode lune','Dark mode')}>{theme==='dark'?<Sun size={17}/>:<Moon size={17}/>}</button></div>}
export function ClientSettings(){const pathname=usePathname(),platform=electionPwa(pathname),{lang}=useElectionLanguage();useEffect(()=>{document.documentElement.lang=lang},[lang]);useEffect(()=>{if(!('serviceWorker'in navigator))return;const base=process.env.GITHUB_ACTIONS==='true'&&process.env.KCS_CUSTOM_DOMAIN!=='true'?'/KCSParentElection':'';void navigator.serviceWorker.register(base+platform.script,{scope:base+platform.scope,updateViaCache:'none'}).then(reg=>reg.update()).catch(()=>{})},[platform.key]);return null}
