"use client";

import {FormEvent,useState} from "react";
import {Send,ShieldCheck,Users} from "lucide-react";
import {createSupabaseBrowserClient} from "@/lib/supabase/client";

type SubmitStatus=""|"sending"|"success"|"error";

export function CandidacyForm(){
 const [status,setStatus]=useState<SubmitStatus>("");
 const [childrenCount,setChildrenCount]=useState(1);
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();setStatus("sending");
  const form=e.currentTarget;const data=new FormData(form);
  const children=Array.from({length:childrenCount},(_,index)=>{const n=index+1;return{last_name:String(data.get("child_"+n+"_last_name")||""),middle_name:String(data.get("child_"+n+"_middle_name")||""),first_name:String(data.get("child_"+n+"_first_name")||""),student_class:String(data.get("child_"+n+"_class")||"")}});
  const positionMap:Record<string,string>={President:"PRESIDENT",Secretary:"SECRETARY",Treasurer:"TREASURER"};
  try{
   const supabase=createSupabaseBrowserClient();
   const{data:applicationId,error}=await supabase.rpc("submit_candidate_application",{p_first_name:String(data.get("first_name")||""),p_middle_name:String(data.get("middle_name")||""),p_last_name:String(data.get("last_name")||""),p_phone:String(data.get("phone")||""),p_email:String(data.get("email")||""),p_parent_seniority:Number(data.get("parent_seniority")),p_relationship:String(data.get("relationship")||""),p_position_name:positionMap[String(data.get("position")||"")]||"",p_biography:String(data.get("biography")||""),p_manifesto:String(data.get("manifesto")||""),p_children:children});
   if(error||!applicationId)throw error??new Error("Missing application identifier");
   const photo=data.get("candidate_photo");
   if(!(photo instanceof File)||!photo.size)throw new Error("Missing candidate photo");
   if(photo.size>5*1024*1024)throw new Error("Photo exceeds 5 MB");
   const extension=photo.type==="image/png"?"png":photo.type==="image/webp"?"webp":"jpg";
   const path=`${applicationId}/candidate.${extension}`;
   const upload=await supabase.storage.from("candidate-photos").upload(path,photo,{contentType:photo.type,upsert:false});
   if(upload.error)throw upload.error;
   const attached=await supabase.rpc("set_candidate_application_photo",{p_application_id:applicationId,p_path:path});
   if(attached.error)throw attached.error;
   setStatus("success");form.reset();setChildrenCount(1);
  }catch(error){console.error("Candidacy submission failed",error);setStatus("error")}
 }
 return <form className="card candidate-form" onSubmit={submit}>
  <div className="form-intro"><ShieldCheck/><div><h2>Personal information</h2><p>Fields marked * are required. No information is sent to an intermediary.</p></div></div>
  <div className="form-grid">
   <label>First name *<input className="field" name="first_name" required maxLength={80}/></label><label>Middle name *<input className="field" name="middle_name" required maxLength={80}/></label><label>Last name *<input className="field" name="last_name" required maxLength={80}/></label><label>Phone number *<input className="field" name="phone" type="tel" required maxLength={30}/></label><label>Email address *<input className="field" name="email" type="email" required maxLength={120}/></label><label>Number of children at KCS *<input className="field" name="children_count" type="number" inputMode="numeric" required min={1} max={10} value={childrenCount} onChange={event=>setChildrenCount(Math.min(10,Math.max(1,Number(event.target.value)||1)))}/></label><label>Years as a KCS parent *<input className="field" name="parent_seniority" type="number" inputMode="numeric" required min={0} max={50}/></label><label>Relationship *<select className="field" name="relationship" required defaultValue=""><option value="" disabled>Select</option><option>Father</option><option>Mother</option><option>Guardian</option></select></label><label>Position sought *<select className="field" name="position" required defaultValue=""><option value="" disabled>Select</option><option>President</option><option>Secretary</option><option>Treasurer</option></select></label>
  </div>
  <section className="children-section"><div className="children-heading"><Users/><div><h2>Children enrolled at KCS</h2><p>Provide the official details for each child.</p></div></div>{Array.from({length:childrenCount},(_,index)=>{const n=index+1;return <fieldset className="child-card" key={n}><legend>Child {n}</legend><div className="form-grid"><label>Last name *<input className="field" name={"child_"+n+"_last_name"} required maxLength={80}/></label><label>Middle name *<input className="field" name={"child_"+n+"_middle_name"} required maxLength={80}/></label><label>First name *<input className="field" name={"child_"+n+"_first_name"} required maxLength={80}/></label><label>Class *<input className="field" name={"child_"+n+"_class"} required maxLength={50}/></label></div></fieldset>})}</section>
  <label>Biography *<textarea className="field" name="biography" required rows={5} minLength={20} maxLength={1500}/></label><label>Manifesto / program *<textarea className="field" name="manifesto" required rows={7} minLength={20} maxLength={3000}/></label>
  <label className="photo-note"><b>Candidate photo *</b><span>JPEG, PNG or WebP, maximum 5 MB. The photo remains private until KCS approves the application.</span><input className="field" name="candidate_photo" type="file" accept="image/jpeg,image/png,image/webp" required/></label>
  <label className="consent"><input type="checkbox" required name="privacy_consent"/><span>I authorize KCS to use this information solely to review and administer my election candidacy.</span></label>
  <button className="btn btn-primary" type="submit" disabled={status==="sending"}><Send size={18}/>{status==="sending"?"Submitting application...":"Submit my candidacy"}</button>
  {status&&<p className={status==="error"?"status-message error":"status-message"}>{status==="sending"?"Submitting application...":status==="success"?"Your candidacy has been registered and is awaiting KCS review.":"The application could not be submitted. Check your information or try again."}</p>}
  <p className="privacy-note">Your application is stored securely and remains private until reviewed by KCS.</p>
 </form>
}
