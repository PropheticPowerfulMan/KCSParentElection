import {describe,it,expect}from 'vitest';
import {adminSection,adminSections,adminViewState}from '../lib/admin-section';
describe('distinct election administration sections',()=>{
 it('never replaces unrelated sections with the creation form, including before the first election',()=>{
  for(const section of adminSections.filter(s=>s!=='election'))for(const selected of[false,true])expect(adminViewState(section,selected,true,true)).not.toBe('create');
 });
 it('keeps history and access settings usable without an election',()=>{
  expect(adminViewState('history',false,true,true)).toBe('history');expect(adminViewState('settings',false,true,true)).toBe('settings');
 });
 it('allows explicit creation only to managers on the configuration section',()=>{
  expect(adminViewState('election',false,false,true)).toBe('create');expect(adminViewState('election',true,true,true)).toBe('create');expect(adminViewState('election',false,true,false)).toBe('empty');expect(adminViewState('candidates',true,false,true)).toBe('content');
 });
 it('preserves legacy section aliases and safely handles unknown sections',()=>{
  expect(adminSection('import')).toBe('voters');expect(adminSection('election-day')).toBe('monitoring');expect(adminSection('unrecognized')).toBe('dashboard');
 });
});
