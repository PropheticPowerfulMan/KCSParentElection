'use strict';
(()=>{const p=new URLSearchParams(location.hash.slice(1)),requestId=p.get('request'),fr=p.get('lang')==='fr',origin=location.origin;
 history.replaceState(null,'',location.pathname);document.documentElement.lang=fr?'fr':'en';document.documentElement.dataset.theme=p.get('theme')==='light'?'light':'dark';
 const title=document.getElementById('title'),note=document.getElementById('note'),name=location.hostname.startsWith('academy.')?'KCS Nexus Academy':fr?'Élections KCS':'KCS Elections';
 title.textContent=fr?'Ouverture de votre espace…':'Opening your workspace…';document.getElementById('workspace').textContent=name;note.textContent=fr?'Votre connexion Nexus est en cours de vérification.':'Your Nexus connection is being verified.';
 const parents=new Set(['https://kinshasachristianschool.org','https://www.kinshasachristianschool.org']);let complete=false,source=null;
 const fail=()=>{if(complete)return;title.textContent=fr?'Rouvrez cet espace depuis Nexus.':'Reopen this workspace from Nexus.';note.textContent=fr?'Ce lien est temporaire. Retournez dans Nexus et réessayez.':'This link is temporary. Return to Nexus and try again.';document.querySelector('.ring').hidden=true};
 if(!requestId||!/^[-a-f0-9]{36}$/i.test(requestId)){fail();return}
 addEventListener('message',event=>{const d=event.data;if(complete||!parents.has(event.origin)||!event.source||d?.requestId!==requestId)return;
  if(d.type==='KCS_WORKSPACE_PING'){if(source&&source!==event.source)return;source=event.source;event.source.postMessage({type:'KCS_WORKSPACE_READY',requestId},event.origin);return}
  if(d.type!=='KCS_WORKSPACE_COMMIT'||event.source!==source||typeof d.url!=='string')return;
  try{const url=new URL(d.url),path=location.hostname.startsWith('academy.')?/^\/api\/auth\/callback\/?$/:/^\/(?:admin\/|student-government\/)?sso\/$/;
   if(url.origin!==origin||url.username||url.password||!path.test(url.pathname))return;
   complete=true;event.source.postMessage({type:'KCS_WORKSPACE_COMMITTED',requestId},event.origin);location.replace(url.href)
  }catch{}
 });setTimeout(fail,95000)
})();
