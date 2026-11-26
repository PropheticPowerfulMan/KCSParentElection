export function electionPwa(pathname:string){
 const student=/^\/student-government(?:\/|$)/.test(pathname);
 return {student,key:student?'kcs-student-election':'kcs-parent-election',
  id:student?'/student-government/':'/kcs-parent-election',
  login:student?'/student-government/login/':'/login/',
  manifest:student?'/student-government/manifest.webmanifest':'/manifest.webmanifest',
  script:student?'/student-government/sw.js':'/sw.js',scope:student?'/student-government/':'/'}
}
export type RelatedWebApp={platform?:string;id?:string;url?:string};
export function isMatchingElectionApp(app:RelatedWebApp,platform:ReturnType<typeof electionPwa>,origin:string){
 if(app.platform!=='webapp')return false;
 try{
  const manifest=new URL(platform.manifest,origin);
  if(app.url&&new URL(app.url,origin).href!==manifest.href)return false;
  if(app.id)return new URL(app.id,origin).href===new URL(platform.id,origin).href;
  return Boolean(app.url)&&new URL(app.url!,origin).href===manifest.href;
 }catch{return false}
}
