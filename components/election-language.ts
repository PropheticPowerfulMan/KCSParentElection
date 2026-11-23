"use client";
import {useSyncExternalStore} from 'react';
const event='kcs-election-settings';
const subscribe=(callback:()=>void)=>{window.addEventListener(event,callback);return()=>window.removeEventListener(event,callback)};
function language(){try{return sessionStorage.getItem('kcs-lang-session')==='en'?'en':'fr'}catch{return'fr'}}
function theme(){return document.documentElement.dataset.theme==='dark'?'dark':'light'}
export function setElectionLanguage(value:'fr'|'en'){try{sessionStorage.setItem('kcs-lang-session',value)}catch{}document.documentElement.lang=value;window.dispatchEvent(new Event(event));window.dispatchEvent(new CustomEvent('kcs-language-change',{detail:value}))}
export function useElectionLanguage(){const lang=useSyncExternalStore(subscribe,language,()=> 'fr');return{lang,fr:lang==='fr',tr:(f:string,e:string)=>lang==='fr'?f:e}}
export function useElectionTheme(){const value=useSyncExternalStore(subscribe,theme,()=> 'light');return{theme:value,toggle:()=>{const next=value==='dark'?'light':'dark';document.documentElement.dataset.theme=next;try{localStorage.setItem('kcs-theme',next)}catch{}window.dispatchEvent(new Event(event))}}}
