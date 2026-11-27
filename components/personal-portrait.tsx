"use client";
import{useElectionAccess}from'./election-auth';
import{useDashboardPortrait}from'./useDashboardPortrait';
import{electionRequest,getElectionToken}from'@/lib/orbit-api';
export function ElectionPersonalPortrait(){const access=useElectionAccess(),audience=access.audience,token=audience?getElectionToken(audience):null;const image=useDashboardPortrait(token,()=>electionRequest('/elections/personal-portrait',{session:audience!}));if(!audience)return null;return <span className="ev-personal-portrait" title={access.name}>{image?<img src={image} alt={access.name}/>:access.name.slice(0,1).toLocaleUpperCase()}</span>}
