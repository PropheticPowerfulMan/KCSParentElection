export const adminSections=['dashboard','election','candidates','voters','monitoring','results','reports','history','audit','settings'] as const;
export type AdminSection=typeof adminSections[number];
export function adminSection(value:string):AdminSection{
 const alias=value==='import'?'voters':value==='election-day'?'monitoring':value;
 return (adminSections as readonly string[]).includes(alias)?alias as AdminSection:'dashboard';
}
export function adminViewState(section:string,hasElection:boolean,creating:boolean,canManage:boolean){
 const current=adminSection(section);
 if(current==='history'||current==='settings')return current;
 if(current==='election'&&canManage&&(creating||!hasElection))return 'create';
 return hasElection?'content':'empty';
}
