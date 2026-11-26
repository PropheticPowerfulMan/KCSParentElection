"use client";
import {createContext,useContext,useEffect,useRef,useState,type ReactNode} from 'react';
import {usePathname,useRouter} from 'next/navigation';
import {Loader2,LogIn,RefreshCw,ShieldCheck} from 'lucide-react';
import {clearElectionSessions,electionRequest,ElectionApiError,getElectionToken,type ElectionSession} from '@/lib/orbit-api';
import {electionLogin} from '@/lib/election-navigation';
import {useElectionLanguage} from './election-language';
type Access={audience:ElectionSession|null;readOnly:boolean;name:string};
const empty:Access={audience:null,readOnly:false,name:''},AccessContext=createContext<Access>(empty);
export const useElectionAccess=()=>useContext(AccessContext);
export function ElectionAccessGate({children}:{children:ReactNode}){
 const path=usePathname(),router=useRouter(),{tr}=useElectionLanguage(),[revision,setRevision]=useState(0),[state,setState]=useState<{path:string;status:string;access:Access;token?:string}>({path:'',status:'checking',access:empty}),sequence=useRef(0);
 const redirecting=useRef<string|null>(null);
 const entry=/(?:^|\/)(?:login|sso)\/?$/.test(path),admin=/^\/(?:admin|student-government\/admin)(?:\/|$)/.test(path),student=path.startsWith('/student-government'),privateVoter=/\/(?:vote|candidacy)\/?$/.test(path),kind:ElectionSession=admin?'ADMIN':student?'STUDENT':'PARENT';
 useEffect(()=>{const changed=()=>setRevision(v=>v+1),restore=(e:PageTransitionEvent)=>{if(e.persisted)changed()},hide=()=>{if(!entry)document.documentElement.dataset.electionLocked='true'};window.addEventListener('kcs-election-auth-changed',changed);window.addEventListener('pageshow',restore);window.addEventListener('pagehide',hide);return()=>{window.removeEventListener('kcs-election-auth-changed',changed);window.removeEventListener('pageshow',restore);window.removeEventListener('pagehide',hide)}},[entry]);
 useEffect(()=>{
  if(entry){redirecting.current=null;delete document.documentElement.dataset.electionLocked;return}
  const serial=++sequence.current,allowed:ElectionSession[]=kind==='ADMIN'||privateVoter?[kind]:[kind,'ADMIN'],retained=state.access.audience&&allowed.includes(state.access.audience)&&state.token===getElectionToken(state.access.audience);
  if(!retained)setState({path,status:'checking',access:empty});
  const redirect=()=>{if(redirecting.current===path)return;redirecting.current=path;clearElectionSessions();router.replace(electionLogin(kind)+'?next='+encodeURIComponent(path+location.search))};
  const check=async()=>{
   const candidates:ElectionSession[]=kind==='ADMIN'||privateVoter?[kind]:[kind,'ADMIN'];
   for(const audience of candidates){
    if(!getElectionToken(audience))continue;
    try{const result=await electionRequest(audience==='ADMIN'?'/elections/admin/access':'/elections/'+audience+'/session',{session:audience});if(sequence.current!==serial)return;delete document.documentElement.dataset.electionLocked;setState({path,status:'ready',token:getElectionToken(audience),access:{audience,readOnly:audience==='ADMIN'&&!result.canManage,name:result.voter?.name||sessionStorage.getItem('kcs-election:orbit:'+audience+':name')||''}});return}
    catch(e){if(sequence.current!==serial)return;if(e instanceof ElectionApiError&&[401,403].includes(e.status))continue;if(!retained)setState({path,status:'unavailable',access:empty});return}
   }
   if(sequence.current===serial)redirect();
  };void check();return()=>{sequence.current++}
 },[path,entry,revision]);
 if(entry)return <AccessContext.Provider value={empty}>{children}</AccessContext.Provider>;
 const allowed:ElectionSession[]=kind==='ADMIN'||privateVoter?[kind]:[kind,'ADMIN'];
 if(state.status!=='ready'||!state.access.audience||!allowed.includes(state.access.audience)||state.token!==getElectionToken(state.access.audience))return <main className="ev-app ev-auth-gate"><section className="ev-card ev-auth-check"><ShieldCheck size={34}/><span className="ev-kicker">KCS ORBIT</span><h1>{state.status==='unavailable'?tr('Vérifions votre connexion.','Let’s check your connection.'):tr('Votre espace électoral sécurisé.','Your secure election workspace.')}</h1><p>{state.status==='unavailable'?tr('Le serveur n’a pas confirmé votre session. Aucune donnée électorale n’est affichée.','The server has not confirmed your session. Electoral data is kept hidden.'):tr('Vérification de votre identité institutionnelle…','Verifying your institutional identity…')}</p>{state.status==='unavailable'?<div className="ev-hero-actions"><button className="ev-button" onClick={()=>setRevision(v=>v+1)}><RefreshCw size={16}/>{tr('Réessayer','Retry')}</button><button className="ev-button secondary" onClick={()=>{clearElectionSessions();location.replace(electionLogin(kind))}}><LogIn size={16}/>{tr('Se connecter','Sign in')}</button></div>:<Loader2 className="ev-spin"/>}</section></main>;
 return <AccessContext.Provider value={state.access}><div className="ev-protected-content">{children}</div></AccessContext.Provider>;
}
