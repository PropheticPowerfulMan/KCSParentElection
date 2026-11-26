"use client";
import{usePathname}from'next/navigation';
import{electionPwa}from'@/lib/election-pwa';
import {useEffect,useRef,useState} from 'react';
import {ArrowUpCircle,Globe,Loader2,Moon,Sun} from 'lucide-react';
import {useElectionLanguage,useElectionTheme,setElectionLanguage} from './election-language';
import {ElectionDialog} from './election-dialog';
export function ElectionControls(){const {fr,tr}=useElectionLanguage(),{theme,toggle}=useElectionTheme();return <div className="ev-controls"><div aria-label={tr('Langue','Language')}><Globe size={14}/><button type="button" aria-pressed={fr} onClick={()=>setElectionLanguage('fr')}>FR</button><button type="button" aria-pressed={!fr} onClick={()=>setElectionLanguage('en')}>EN</button></div><button type="button" className="ev-theme" onClick={toggle} aria-label={theme==='dark'?tr('Mode soleil','Light mode'):tr('Mode lune','Dark mode')}>{theme==='dark'?<Sun size={17}/>:<Moon size={17}/>}</button></div>}
export function ClientSettings(){
 const pathname=usePathname(),platform=electionPwa(pathname);
 const {lang,tr}=useElectionLanguage(),[waiting,setWaiting]=useState<ServiceWorker|null>(null),[confirm,setConfirm]=useState(false),[reloading,setReloading]=useState(false),requested=useRef(false);
 useEffect(()=>{document.documentElement.lang=lang},[lang]);
 useEffect(()=>{if(!('serviceWorker'in navigator))return;let active=true;const base=process.env.GITHUB_ACTIONS==='true'&&process.env.KCS_CUSTOM_DOMAIN!=='true'?'/KCSParentElection':'';
 const changed=()=>{if(requested.current)location.reload()};navigator.serviceWorker.addEventListener('controllerchange',changed);
 navigator.serviceWorker.register(base+platform.script,{scope:base+platform.scope,updateViaCache:'none'}).then(reg=>{if(!active)return;if(reg.waiting&&navigator.serviceWorker.controller)setWaiting(reg.waiting);reg.addEventListener('updatefound',()=>{const worker=reg.installing;worker?.addEventListener('statechange',()=>{if(worker.state==='installed'&&navigator.serviceWorker.controller&&active)setWaiting(worker)})});void reg.update().catch(()=>undefined)}).catch(()=>undefined);
 return()=>{active=false;navigator.serviceWorker.removeEventListener('controllerchange',changed)}},[platform.key]);
 // A deferred update remains pending and must be offered again.
 useEffect(()=>{if(waiting)setConfirm(true)},[waiting]);
 useEffect(()=>{
  if(!waiting||confirm||reloading)return;
  const remind=()=>{if(document.visibilityState==='visible')setConfirm(true)};
  const timer=window.setTimeout(()=>setConfirm(true),60000);
  window.addEventListener('focus',remind);document.addEventListener('visibilitychange',remind);
  return()=>{clearTimeout(timer);window.removeEventListener('focus',remind);document.removeEventListener('visibilitychange',remind)};
 },[waiting,confirm,reloading]);
 if(!waiting)return null;
 return <><button className="ev-update" onClick={()=>setConfirm(true)}><ArrowUpCircle size={17}/>{tr('Nouvelle version disponible','New version available')}</button>{confirm&&<ElectionDialog title={tr('Actualiser l’application ?','Update the application?')} onClose={()=>{if(!reloading)setConfirm(false)}}><p>{tr('Un choix de vote non soumis devra être saisi à nouveau. Un vote déjà confirmé par le serveur reste enregistré.','Unsubmitted ballot selections will need to be entered again. Votes already confirmed by the server remain recorded.')}</p><footer className="ev-dialog-actions"><button className="ev-button secondary" disabled={reloading} onClick={()=>setConfirm(false)}>{tr('Plus tard · rappel dans 1 min','Later · remind me in 1 min')}</button><button className="ev-button" disabled={reloading} onClick={()=>{requested.current=true;setReloading(true);waiting.postMessage({type:'SKIP_WAITING'})}}>{reloading?<Loader2 className="ev-spin" size={16}/>:<ArrowUpCircle size={16}/>} {tr('Actualiser','Update')}</button></footer></ElectionDialog>}</>
}
