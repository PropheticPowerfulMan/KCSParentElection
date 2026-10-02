import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const allowedOrigins = new Set(['https://kcsparentelection.kinshasachristianschool.org','https://kinshasachristianschool.org','http://localhost:3000'])
const cors = (origin: string) => ({ 'Access-Control-Allow-Origin': allowedOrigins.has(origin) ? origin : 'https://kcsparentelection.kinshasachristianschool.org', 'Access-Control-Allow-Headers': 'content-type', 'Access-Control-Allow-Methods': 'POST,OPTIONS', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
Deno.serve(async (request) => {
 const origin=request.headers.get('origin')??''; const headers=cors(origin)
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers})
 if(request.method!=='POST'||!allowedOrigins.has(origin))return new Response(JSON.stringify({error:'NOT_ALLOWED'}),{status:403,headers})
 try{
  const body=await request.json(); const identifier=String(body.identifier??'').trim(); const password=String(body.password??''); const audience=String(body.audience??'PARENT').toUpperCase()
  if(!identifier||password.length<8||!['PARENT','STUDENT'].includes(audience))throw new Error('INVALID_REQUEST')
  const nexusBase=Deno.env.get('NEXUS_API_URL')??'https://kinshasachristianschool.org/nexus/api'
  const login=await fetch(`${nexusBase}/auth/login`,{method:'POST',headers:{'content-type':'application/json','x-kcs-local-auth-only':'true'},body:JSON.stringify({identifier,password})})
  const payload=await login.json().catch(()=>null); if(!login.ok||!payload?.data?.user)throw new Error('INVALID_CREDENTIALS')
  const user=payload.data.user; const role=String(user.role??'').toUpperCase(); if(role!==audience)throw new Error('WRONG_ELECTORATE')
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}})
  const {data,error}=await supabase.rpc('issue_orbit_voter_session',{p_orbit_user_id:String(user.id),p_email:String(user.email??''),p_access_code:String(user.accessCode??''),p_first_name:String(user.firstName??''),p_last_name:String(user.lastName??''),p_role:role,p_grade:String(user.studentProfile?.grade??user.grade??''),p_section:String(user.studentProfile?.section??user.section??'')})
  if(error||!data?.[0])throw new Error(error?.message??'VOTER_NOT_ELIGIBLE')
  return new Response(JSON.stringify({session_token:data[0].session_token,display_name:data[0].display_name,election_kind:data[0].election_kind,expires_at:data[0].expires_at}),{status:200,headers})
 }catch(error){const message=error instanceof Error?error.message:'LOGIN_FAILED';const status=message.includes('INVALID_CREDENTIALS')?401:message.includes('WRONG_ELECTORATE')?403:400;return new Response(JSON.stringify({error:message}),{status,headers})}
})