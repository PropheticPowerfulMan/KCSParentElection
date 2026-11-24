import {describe,it,expect} from 'vitest';
import {electionNext,electionLogin,electionHome,nexusReturn} from '../lib/election-navigation';
describe('electoral routes and safe returns',()=>{
 it('preserves the selected historical election after institutional login',()=>{
  expect(electionNext('PARENT','/results/?election=past')).toBe('/results/?election=past');
  expect(electionNext('ADMIN','/student-government/admin/?section=history&election=past')).toContain('section=history');
  expect(electionNext('STUDENT','candidacy')).toBe('/student-government/candidacy/');
 });
 it('rejects external, cross-electorate and sign-in loops',()=>{
  for(const audience of ['PARENT','STUDENT','ADMIN'] as const)for(const value of ['//outside.invalid','https://outside.invalid','/admin/login/','/admin/sso/','javascript:alert(1)','/admin\\evil'])expect(electionNext(audience,value)).toBe(electionHome(audience));
  expect(electionNext('PARENT','/student-government/vote/')).toBe('/');
  expect(electionLogin('STUDENT')).toBe('/student-government/login/');
 });
 it('server rendering never reads browser session storage',()=>expect(nexusReturn('ADMIN')).toBe('https://kinshasachristianschool.org/'));
});
