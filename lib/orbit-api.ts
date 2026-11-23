export type Electorate='PARENT'|'STUDENT'
export type ElectionSession='PARENT'|'STUDENT'|'ADMIN'
export const NEXUS_API=(process.env.NEXT_PUBLIC_NEXUS_API_URL||'https://api-nexus.kinshasachristianschool.org/api').replace(/\/+$/,'')
const key=(kind:ElectionSession)=>'kcs-election:orbit:'+kind
export const getElectionToken=(kind:ElectionSession)=>typeof window==='undefined'?'':sessionStorage.getItem(key(kind))||''
export function saveElectionToken(kind:ElectionSession,token:string){sessionStorage.setItem(key(kind),token)}
export function clearElectionToken(kind:ElectionSession){sessionStorage.removeItem(key(kind));sessionStorage.removeItem(key(kind)+':name')}
export class ElectionApiError extends Error{constructor(public code:string,public status:number){super(code)}}
export async function electionRequest(path:string,options:{method?:string;body?:unknown;session?:ElectionSession;token?:string;signal?:AbortSignal}={}){
 const token=options.token||options.session&&getElectionToken(options.session),form=typeof FormData!=='undefined'&&options.body instanceof FormData
 const response=await fetch(NEXUS_API+path,{method:options.method||'GET',headers:{...(options.body&&!form?{'content-type':'application/json'}:{}),...(token?{authorization:'Bearer '+token}:{})},body:form?options.body as FormData:options.body?JSON.stringify(options.body):undefined,cache:'no-store',credentials:'omit',signal:options.signal})
 const data=await response.json().catch(()=>null)
 if(!response.ok||!data?.success){if(response.status===401&&options.session)clearElectionToken(options.session);throw new ElectionApiError(data?.message||'ELECTION_SERVICE_UNAVAILABLE',response.status)}
 return data.data
}
export function electionPath(kind:Electorate){return kind==='STUDENT'?'/student-government':''}
export function electionError(error:unknown,fr:boolean){
 const code=error instanceof Error?error.message:''
 const messages:Array<[string,string,string]>=[
 ['INVALID_PHOTO','Choisissez une photo JPEG, PNG ou WebP valide.','Choose a valid JPEG, PNG or WebP photo.'],
 ['PHOTO_LIMIT','La photo ne peut pas dépasser 5 Mo.','The photo must not exceed 5 MB.'],
 ['WRONG_ELECTORATE','Ce compte institutionnel n’appartient pas à cet électorat.','This institutional account does not belong to this electorate.'],
 ['NOT_ELIGIBLE','Votre compte est reconnu, mais ce scrutin ne vous est pas ouvert.','Your account is recognized, but this election is not open to you.'],
 ['ACCOUNT_INACTIVE','Ce compte est inactif ou bloqué. Contactez l’école.','This account is inactive or blocked. Contact the school.'],
 ['ADMIN_ACCESS','La direction doit vous accorder le droit d’administrer ou d’observer les élections.','School administration must grant election management or observer access.'],
 ['OBSERVER_READ_ONLY','Votre accès permet la consultation uniquement.','Your access is read-only.'],
 ['INVALID_BALLOT','Complétez chaque poste avec un choix autorisé.','Complete every office with an eligible selection.'],
 ['VOTING_CLOSED','La période officielle de vote est fermée. Aucun nouveau vote n’a été enregistré.','The official voting window is closed. No new vote was recorded.'],
 ['CANDIDATES_FROZEN','Les candidatures sont protégées après l’ouverture du scrutin.','Candidacies are protected after voting has opened.'],
 ['APPLICATIONS_CLOSED','La période de candidature est fermée.','Applications are closed.'],
 ['APPLICATION_ALREADY_EXISTS','Une candidature existe déjà pour ce poste.','You already have an application for this office.'],
 ['OUTSIDE_CONSTITUENCY','Ce poste ne correspond pas à votre classe ou à votre électorat.','This office is outside your class or electorate.'],
 ['SETTINGS_FROZEN','La configuration est protégée après l’ouverture du scrutin.','Settings are protected after the election opens.'],
 ['APPROVED_CANDIDATES_REQUIRED','Chaque poste doit avoir une candidature approuvée avant l’ouverture.','Each office requires an approved candidate before opening.'],
 ['ANOTHER_OPEN','Un scrutin de cet électorat est déjà ouvert. Fermez-le d’abord.','An election for this electorate is already open. Close it first.'],
 ['INVALID_TRANSITION','Cette transition n’est pas autorisée. Vérifiez le statut actuel.','This status transition is not allowed. Check the current status.'],
 ['WINDOW_ENDED','L’heure officielle de clôture est déjà dépassée.','The official closing time has already passed.'],
 ['PUBLISHED_SCHOOL_YEAR','Les dates et l’année doivent correspondre au calendrier officiel publié dans Nexus.','Dates and school year must match the official calendar published in Nexus.'],
 ['ACCESS_CHANGED','Ce dossier a changé. Actualisez avant de confirmer de nouveaux droits.','This record changed. Refresh before confirming new access rights.'],
 ['SELECT_VOTERS','Choisissez au moins une personne pour cet électorat ciblé.','Select at least one person for this targeted electorate.'],
 ]
 for(const [match,f,e]of messages)if(code.includes(match))return fr?f:e
 if(code.toLowerCase().includes('factor')||code.includes('2FA'))return fr?'Saisissez aussi votre code de vérification de connexion.':'Enter your sign-in verification code as well.'
 if(error instanceof ElectionApiError&&error.status===401)return fr?'Identifiant ou mot de passe institutionnel incorrect, ou session expirée.':'Incorrect institutional credentials or expired session.'
 if(error instanceof ElectionApiError&&error.status===429)return fr?'Trop de tentatives. Patientez quelques minutes avant de réessayer.':'Too many attempts. Wait a few minutes before retrying.'
 return fr?'Le serveur n’a pas confirmé cette opération. Vérifiez la connexion puis réessayez.':'The server has not confirmed this operation. Check the connection and retry.'
}

export function electionImageUrl(value:string){return value.startsWith('/')?new URL(value,NEXUS_API).href:value}
