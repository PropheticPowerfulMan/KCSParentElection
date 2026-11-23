"use client";
import {useEffect,useRef,type ReactNode} from 'react';
import {X} from 'lucide-react';
import {useElectionLanguage} from './election-language';
export function ElectionDialog({title,children,onClose}:{title:string;children:ReactNode;onClose:()=>void}){
 const ref=useRef<HTMLDialogElement>(null),{tr}=useElectionLanguage();
 useEffect(()=>{const el=ref.current;if(el&&!el.open)el.showModal();return()=>{if(el?.open)el.close()}},[]);
 return <dialog className="ev-dialog" ref={ref} onCancel={e=>{e.preventDefault();onClose()}} aria-label={title} onClick={e=>{if(e.target===ref.current)onClose()}}><header><h2>{title}</h2><button type="button" aria-label={tr('Fermer','Close')} onClick={onClose}><X size={20}/></button></header><div className="ev-dialog-body">{children}</div></dialog>
}
