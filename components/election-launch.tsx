"use client";
import {useEffect,useRef,useState} from 'react';
import {ArrowLeft,Loader2,ShieldCheck} from 'lucide-react';
import {clearElectionSessions,electionError,electionRequest,saveElectionToken,type ElectionSession} from '@/lib/orbit-api';
import {electionHome,electionLogin,saveNexusReturn} from '@/lib/election-navigation';
import {setElectionLanguage,useElectionLanguage} from './election-language';
export function ElectionLaunch({audience}:{audience:ElectionSession}){
 const {fr,tr}=useElectionLanguage(),[error,setError]=useState(''),flow=useRef<Promise<any>|null>(null);
 useEffect(()=>{
  let active=true;
  if(!flow.current){const ticket=new URLSearchParams(location.hash.slice(1)).get('launch');history.replaceState(null,'',location.pathname);clearElectionSessions();flow.current=ticket?electionRequest('/elections/exchange',{method:'POST',body:{ticket,audience}}):Promise.reject(new Error('ELECTION_LAUNCH_EXPIRED_OR_USED'))}
  flow.current.then(result=>{if(!active)return;if(result.audience!==audience||!result.token)throw Error('ELECTION_INVALID_SESSION');setElectionLanguage(result.language==='en'?'en':'fr');const theme=result.theme==='dark'?'dark':'light';localStorage.setItem('kcs-theme',theme);document.documentElement.dataset.theme=theme;saveNexusReturn(audience,result.returnPath);saveElectionToken(audience,result.token);location.replace(electionHome(audience))}).catch(e=>{if(active)setError(electionError(e,fr))});
  return()=>{active=false}
 },[audience]);
 return <main className="ev-app ev-auth-gate"><section className="ev-card ev-auth-check"><ShieldCheck size={36}/><span className="ev-kicker">KCS ORBIT · NEXUS AI</span><h1>{error?tr('Rouvrez votre accès depuis Nexus.','Reopen access from Nexus.'):tr('Bienvenue dans votre espace électoral.','Welcome to your election workspace.')}</h1><p>{error||tr('Votre session Nexus est vérifiée. Aucun mot de passe supplémentaire n’est demandé.','Your Nexus session is being verified. No additional password is requested.')}</p>{error?<div className="ev-hero-actions"><a className="ev-button" href="https://kinshasachristianschool.org/"><ArrowLeft size={16}/>{tr('Revenir à Nexus AI','Return to Nexus AI')}</a><a className="ev-button secondary" href={electionLogin(audience)}>{tr('Connexion institutionnelle','Institutional sign-in')}</a></div>:<Loader2 className="ev-spin"/>}</section></main>;
}
