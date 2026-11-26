"use client";
import {usePathname} from 'next/navigation';
import {createContext,useContext,useEffect,useRef,useState,type ReactNode} from 'react';
import {Download,ExternalLink,Loader2,MonitorSmartphone,Share2} from 'lucide-react';
import {electionPwa,isMatchingElectionApp,type RelatedWebApp} from '@/lib/election-pwa';
import {useElectionLanguage} from './election-language';
import {ElectionDialog} from './election-dialog';
type InstallPrompt=Event&{prompt:()=>Promise<void>;userChoice:Promise<{outcome:"accepted"|"dismissed"}>};
type Controller={installed:boolean;busy:boolean;install:()=>void;help:()=>void};
const InstallContext=createContext<Controller|null>(null);
export function ElectionInstallProvider({children}:{children:ReactNode}){
 const path=usePathname(),platform=electionPwa(path),{fr,tr}=useElectionLanguage();
 const [installed,setInstalled]=useState(false),[busy,setBusy]=useState(false),[help,setHelp]=useState(false);
 const prompt=useRef<InstallPrompt|null>(null),lock=useRef(false),generation=useRef(0);
 useEffect(()=>{
  const current=++generation.current;let active=true;
  prompt.current=null;lock.current=false;setBusy(false);setInstalled(false);setHelp(false);
  const nav=navigator as Navigator&{getInstalledRelatedApps?:()=>Promise<RelatedWebApp[]>};
  // A standalone window can belong to Nexus or the other election app.
  // Only a matching installed identity (or appinstalled) confirms this app.
  nav.getInstalledRelatedApps?.().then(apps=>{
   if(active&&apps.some(app=>isMatchingElectionApp(app,platform,location.origin)))setInstalled(true);
  }).catch(()=>undefined);
  const before=(event:Event)=>{event.preventDefault();prompt.current=event as InstallPrompt;setInstalled(false)};
  const done=()=>{if(current===generation.current){prompt.current=null;setInstalled(true);setBusy(false)}};
  addEventListener('beforeinstallprompt',before);addEventListener('appinstalled',done);
  return()=>{active=false;prompt.current=null;removeEventListener('beforeinstallprompt',before);removeEventListener('appinstalled',done)};
 },[platform.key]);
 async function install(){
  if(lock.current)return;
  const pending=prompt.current;if(!pending){setHelp(true);return}
  const current=generation.current;lock.current=true;prompt.current=null;setBusy(true);
  try{await pending.prompt();await pending.userChoice}
  catch{if(current===generation.current)setHelp(true)}
  finally{if(current===generation.current){lock.current=false;setBusy(false)}}
 }
 const appName=platform.student?tr('KCS Élections Élèves','KCS Student Election'):tr('KCS Élections Parents','KCS Parent Election');
 return <InstallContext.Provider value={{installed,busy,install,help:()=>setHelp(true)}}>{children}{help&&<ElectionDialog title={appName} onClose={()=>setHelp(false)}><div className="ev-install-help" data-no-translate>
  <p>{tr('Installez cette application électorale séparément de Nexus et de l’autre plateforme électorale.','Install this election app separately from Nexus and the other election platform.')}</p>
  <p><b>Android · Chrome</b><br/>{tr('Ouvrez le menu ⋮, puis « Installer l’application » ou « Ajouter à l’écran d’accueil ».','Open the ⋮ menu, then “Install app” or “Add to Home screen”.')}</p>
  <p><b>iPhone / iPad · Safari</b><br/><Share2 size={15}/>{tr(' Partager → Sur l’écran d’accueil → Ouvrir comme app, si proposé.',' Share → Add to Home Screen → Open as Web App, if offered.')}</p>
  <p><b>{tr('Ordinateur · Chrome / Edge','Computer · Chrome / Edge')}</b><br/>{tr('Utilisez l’icône d’installation de la barre d’adresse ou le menu du navigateur.','Use the installation icon in the address bar or the browser menu.')}</p>
  <div className="ev-install-link-help"><h3>{tr('Déjà installée, mais le lien ouvre le navigateur ?','Already installed, but links open in the browser?')}</h3><p>{tr('Ouvrez l’application électorale depuis son icône. Dans ses paramètres Chrome / Edge, autorisez l’ouverture des liens dans l’application si cette option est disponible. Sur Android, vérifiez aussi « Ouvrir par défaut » dans les paramètres de l’application.','Open the election app from its icon. In its Chrome / Edge settings, allow links to open in the app if that option is available. On Android, also check “Open by default” in the app settings.')}</p><small>{tr('Le navigateur et l’appareil décident de l’ouverture dans une application installée. Sur iPhone / iPad, utilisez l’icône de l’écran d’accueil.','Your browser and device control opening installed apps. On iPhone / iPad, use the Home Screen icon.')}</small></div>
  <a className="ev-button" href={platform.login} target="_blank" rel="noopener noreferrer"><ExternalLink size={16}/>{tr('Ouvrir la plateforme électorale','Open the election platform')}</a>
 </div></ElectionDialog>}</InstallContext.Provider>
}
export function InstallApp({placement='floating'}:{placement?:'floating'|'inline'}){
 const state=useContext(InstallContext),path=usePathname(),platform=electionPwa(path),{tr}=useElectionLanguage();
 if(!state)return null;
 const login=/\/(?:login|sso)\/?$/.test(path);
 if(placement==='floating'&&(login||state.installed))return null;
 const name=platform.student?tr('KCS Élections Élèves','KCS Student Election'):tr('KCS Élections Parents','KCS Parent Election');
 if(placement==='floating')return <button type="button" className="install-app-button" onClick={state.install} disabled={state.busy} data-no-translate><Download size={18}/>{tr('Installer l’application','Install app')}</button>;
 return <section className="ev-install-panel" data-election-install={platform.key} data-no-translate aria-label={tr('Installation de l’application','App installation')}>
  <div className="ev-install-icon"><MonitorSmartphone size={23}/></div><div className="ev-install-copy"><strong>{name}</strong><small>{state.installed?tr('Application installée sur cet appareil.','App installed on this device.'):tr('Votre application électorale, avec sa propre icône.','Your election app, with its own icon.')}</small></div>
  <div className="ev-install-actions">{state.installed?<a className="ev-button" href={platform.login} target="_blank" rel="noopener noreferrer"><ExternalLink size={16}/>{tr('Ouvrir l’application','Open the app')}</a>:<button type="button" className="ev-button" disabled={state.busy} onClick={state.install}>{state.busy?<Loader2 className="ev-spin" size={16}/>:<Download size={16}/>} {tr('Installer l’application','Install app')}</button>}
  <button type="button" className="ev-install-guide" onClick={state.help}>{tr('Installation et ouverture des liens','Installation & opening links')}</button></div>
 </section>
}
