import{useEffect,useRef,useState}from'react';
const valid=image=>typeof image==='string'&&image.length<=1500000&&/^data:image\/(jpeg|png|webp);base64,/.test(image);
/** Private account-bound session cache; never an official registry portrait. */
export function useDashboardPortrait(identity,load){
 const latest=useRef(load);latest.current=load;const[state,setState]=useState({identity:null,image:null});
 useEffect(()=>{if(!identity)return;let active=true,busy=false,key=null,received=false;
 const scope=['/kitchen/','/sentinel/','/jury/','/lesson-plan/','/student-government/'].find(prefix=>location.pathname.startsWith(prefix))||'/';
 const cacheReady=(async()=>{try{if(!globalThis.crypto?.subtle)return;const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(location.origin+'|'+scope+'|'+String(identity)));key='kcs:personal-portrait:v1:'+Array.from(new Uint8Array(hash)).map(n=>n.toString(16).padStart(2,'0')).join('');const cached=JSON.parse(sessionStorage.getItem(key)||'null');if(active&&!received&&valid(cached?.image)&&Date.now()-cached.at<604800000)setState({identity,image:cached.image})}catch{/* Optional private storage must not block the dashboard. */}})();
 const refresh=async()=>{if(busy||!navigator.onLine||document.visibilityState==='hidden')return;busy=true;try{const value=await latest.current();if(active){received=true;const image=valid(value?.image)?value.image:null;setState({identity,image});await cacheReady;if(active&&key)try{if(image)sessionStorage.setItem(key,JSON.stringify({image,at:Date.now()}));else sessionStorage.removeItem(key)}catch{}}}catch{/* Retain this account's last personal portrait during a weak connection. */}finally{busy=false}};
 void refresh();const timer=setInterval(()=>void refresh(),60000),resume=()=>void refresh();addEventListener('kcs:personal-portrait-changed',resume);addEventListener('focus',resume);addEventListener('online',resume);document.addEventListener('visibilitychange',resume);
 return()=>{active=false;clearInterval(timer);removeEventListener('kcs:personal-portrait-changed',resume);removeEventListener('focus',resume);removeEventListener('online',resume);document.removeEventListener('visibilitychange',resume)}
 },[identity]);return state.identity===identity?state.image:null
}
