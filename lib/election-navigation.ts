import type {ElectionSession} from './orbit-api';
export const electionHome=(audience:ElectionSession)=>audience==='ADMIN'?'/admin/':audience==='STUDENT'?'/student-government/':'/';
export const electionLogin=(audience:ElectionSession)=>audience==='ADMIN'?'/admin/login/':audience==='STUDENT'?'/student-government/login/':'/login/';
export function electionNext(audience:ElectionSession,value:unknown){
 const home=electionHome(audience);if(value==='candidacy'&&audience!=='ADMIN')return home+'candidacy/';
 if(typeof value!=='string'||!value.startsWith('/')||value.startsWith('//')||/[\u0000-\u0020\\]/.test(value))return home;
 try{const u=new URL(value,'https://election.invalid');if(u.origin!=='https://election.invalid')return home;
  const allowed=audience==='ADMIN'?/^\/(?:admin|student-government\/admin)\/(?!login(?:\/|$)|sso(?:\/|$))/:new RegExp('^'+(audience==='STUDENT'?'/student-government/':'/')+'(?:(?:vote|candidacy|results|history|election-information|simulation)/)?$');
  return allowed.test(u.pathname)?u.pathname+u.search:home;
 }catch{return home}
}
export function saveNexusReturn(audience:ElectionSession,value:string){
 const allowed=audience==='ADMIN'?/^\/(?:admin|portal\/(?:senior|teacher|staff))(?:\/|$)/:new RegExp('^/portal/'+audience.toLowerCase()+'(?:/|$)');
 if(allowed.test(value)&&!/[\u0000-\u0020\\]/.test(value))sessionStorage.setItem('kcs-election:nexus-return:'+audience,value);
}
export function nexusReturn(audience:ElectionSession|null){
 const value=audience&&typeof window!=='undefined'?sessionStorage.getItem('kcs-election:nexus-return:'+audience):null;
 return value&&/^\/(?:admin|portal\/(?:parent|student|teacher|senior|staff))(?:\/|$)/.test(value)&&!/[\u0000-\u0020\\]/.test(value)?'https://kinshasachristianschool.org'+value:'https://kinshasachristianschool.org/';
}
