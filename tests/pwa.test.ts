import{describe,it,expect}from'vitest';import{readFileSync}from'node:fs';import{electionPwa,isMatchingElectionApp}from'../lib/election-pwa';
describe('independent election PWAs',()=>{it('uses distinct install identity, worker and scope for pupils and parents',()=>{const parent=electionPwa('/admin/'),student=electionPwa('/student-government/admin/');expect(parent.key).not.toBe(student.key);expect(parent.manifest).not.toBe(student.manifest);expect(student.scope).toBe('/student-government/');expect(parent.script).toBe('/sw.js')});it('keeps all student entry points in its own manifest scope',()=>{const manifest=JSON.parse(readFileSync('public/student-government/manifest.webmanifest','utf8'));for(const path of['/student-government/sso/','/student-government/login/','/student-government/admin/'])expect(path.startsWith(manifest.scope)).toBe(true);expect(manifest.launch_handler.client_mode).toBe('navigate-existing');expect(manifest.id).not.toBe(JSON.parse(readFileSync('public/manifest.webmanifest','utf8')).id)});it('worker activation cannot remove the other platform cache',()=>{const script=readFileSync('public/student-government/sw.js','utf8');expect(script).toContain('key.startsWith("kcs-student-election-")');expect(script).not.toContain('key.startsWith("kcs-parent-election-")')})});

describe('install discovery does not confuse electoral apps or Nexus',()=>{
 const origin='https://kcsparentelection.kinshasachristianschool.org';
 const parent=electionPwa('/login/'),student=electionPwa('/student-government/login/');
 it('accepts only the matching webapp identity and manifest',()=>{
  expect(isMatchingElectionApp({platform:'webapp',id:origin+parent.id,url:origin+parent.manifest},parent,origin)).toBe(true);
  expect(isMatchingElectionApp({platform:'webapp',id:origin+student.id,url:origin+student.manifest},student,origin)).toBe(true);
  expect(isMatchingElectionApp({platform:'webapp',id:origin+student.id,url:origin+student.manifest},parent,origin)).toBe(false);
  expect(isMatchingElectionApp({platform:'webapp',id:'https://kinshasachristianschool.org/',url:'https://kinshasachristianschool.org/manifest.webmanifest'},parent,origin)).toBe(false);
  expect(isMatchingElectionApp({platform:'webapp',id:origin+parent.id+'-fake'},parent,origin)).toBe(false);
  expect(isMatchingElectionApp({platform:'play',id:origin+parent.id},parent,origin)).toBe(false);
  expect(isMatchingElectionApp({platform:'webapp',url:parent.manifest},parent,origin)).toBe(true);
 });
 it('keeps stable IDs, starts at login and declares self for installed-app discovery',()=>{
  for(const [file,platform,id] of [['public/manifest.webmanifest',parent,'kcs-parent-election'],['public/student-government/manifest.webmanifest',student,'/student-government/']] as const){
   const manifest=JSON.parse(readFileSync(file,'utf8'));
   expect(manifest.id).toBe(id);expect(manifest.start_url).toBe(platform.login);
   expect(manifest.prefer_related_applications).toBe(false);
   expect(isMatchingElectionApp(manifest.related_applications[0],platform,origin)).toBe(true);
  }
 });
});
