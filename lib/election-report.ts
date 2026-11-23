import type {Electorate} from './orbit-api';
import {NEXUS_API} from './orbit-api';

/** Aggregate report only: individual selections and voter identities never enter this document. */
export async function downloadElectionReport(data:any,audience:Electorate,fr:boolean){
 const [{jsPDF},qr]=await Promise.all([import('jspdf'),import('qrcode')]);
 const pdf=new jsPDF(),tr=(f:string,e:string)=>fr?f:e,ink=[23,61,57] as const,accent=[19,120,107] as const;
 const reference='KCS-ELECTION-'+data.election.id.toUpperCase(),verification=NEXUS_API+'/elections/'+audience+'/results?electionId='+encodeURIComponent(data.election.id);
 const code=await qr.toDataURL(verification,{width:360,margin:2,errorCorrectionLevel:'M'});
 let logo='';try{const base=process.env.GITHUB_ACTIONS==='true'&&process.env.KCS_CUSTOM_DOMAIN!=='true'?'/KCSParentElection':'';const blob=await(await fetch(base+'/kcs.jpg')).blob();logo=await new Promise<string>((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(String(r.result));r.onerror=reject;r.readAsDataURL(blob)})}catch{}
 let y=44;
 function header(){
  pdf.setFillColor(241,246,242);pdf.rect(0,0,210,34,'F');if(logo)pdf.addImage(logo,'JPEG',15,8,20,20);
  pdf.setTextColor(...ink);pdf.setFont('helvetica','bold');pdf.setFontSize(13);pdf.text('KINSHASA CHRISTIAN SCHOOL',logo?41:16,15);
  pdf.setFontSize(8);pdf.setFont('helvetica','normal');pdf.text('KCS ORBIT · '+tr('COMMISSION ÉLECTORALE','ELECTION COMMISSION'),logo?41:16,21);
  pdf.setDrawColor(...accent);pdf.setLineWidth(.6);pdf.line(15,34,195,34);y=44;
  if(logo){pdf.saveGraphicsState();pdf.setGState(pdf.GState({opacity:.035}));pdf.addImage(logo,'JPEG',49,110,112,112);pdf.restoreGraphicsState()}
 }
 function room(height:number){if(y+height>268){pdf.addPage();header()}}
 function text(value:string,size=10,bold=false){const lines=pdf.splitTextToSize(value,180);room(lines.length*size*.43+5);pdf.setTextColor(...ink);pdf.setFont('helvetica',bold?'bold':'normal');pdf.setFontSize(size);pdf.text(lines,15,y);y+=lines.length*size*.43+5}
 header();text(tr('RAPPORT OFFICIEL DU SCRUTIN','OFFICIAL ELECTION REPORT'),19,true);text(data.election.title,13,true);
 text(data.election.academicYear+' · '+data.election.status+' · '+(audience==='PARENT'?tr('Comité des parents','Parent committee'):tr('Gouvernement des élèves','Student government')),9);
 const stats=[[tr('Électeurs éligibles','Eligible voters'),data.eligibleCount],[tr('Participations confirmées','Confirmed participants'),data.participation],[tr('Bulletins enregistrés','Recorded ballots'),data.ballots],[tr('Participation','Turnout'),data.turnout===null?'—':data.turnout+'%']];
 room(26);for(let i=0;i<stats.length;i++){const x=15+i*46;pdf.setFillColor(231,239,233);pdf.roundedRect(x,y,43,23,2,2,'F');pdf.setTextColor(...ink);pdf.setFontSize(7);pdf.text(String(stats[i][0]),x+3,y+7);pdf.setFontSize(16);pdf.setFont('helvetica','bold');pdf.text(String(stats[i][1]),x+3,y+17);pdf.setFont('helvetica','normal')}y+=33;
 text(tr('Contrôle : participations et bulletins doivent être égaux.','Integrity check: participation and ballot totals must match.'),9);
 if(!data.talliesVisible)text(tr('Les résultats intermédiaires sont protégés. Aucun choix individuel n’est publié.','Interim tallies are protected. No individual selections are published.'),10);
 else for(const office of data.offices){
  room(30);text(office.name+(office.scope==='CLASS'?' · '+[office.grade,office.section].filter(Boolean).join(' '):''),12,true);
  const candidates=[...office.candidates].sort((a:any,b:any)=>(b.votes||0)-(a.votes||0)),total=candidates.reduce((n:number,c:any)=>n+(c.votes||0),0)+(office.abstentions||0);
  for(const candidate of candidates){room(20);const percent=total?(candidate.votes||0)/total*100:0;text(candidate.name+' · '+(candidate.votes||0)+' · '+percent.toFixed(1)+'%',9);pdf.setFillColor(224,234,226);pdf.roundedRect(15,y-2,180,3,1,1,'F');if(percent){pdf.setFillColor(...accent);pdf.roundedRect(15,y-2,180*percent/100,3,1,1,'F')}y+=8}
  text(tr('Abstentions : ','Abstentions: ')+(office.abstentions||0),8);
  const top=candidates[0]?.votes||0;if(top&&candidates.filter((c:any)=>c.votes===top).length>1)text(tr('Égalité : décision officielle de la commission requise.','Tie: an official commission decision is required.'),9,true);
 }
 room(43);pdf.addImage(code,'PNG',15,y,27,27);pdf.setTextColor(...ink);pdf.setFontSize(8);pdf.text(pdf.splitTextToSize(tr('Vérification : résultats publiés dans le registre Nexus. Ce QR ne constitue pas une signature cryptographique.','Verification: published results in the Nexus register. This QR is not a cryptographic signature.'),145),47,y+6);pdf.text(reference,47,y+23);
 const pages=pdf.getNumberOfPages();for(let i=1;i<=pages;i++){pdf.setPage(i);pdf.setDrawColor(193,210,200);pdf.line(15,277,195,277);pdf.setTextColor(...ink);pdf.setFont('helvetica','normal');pdf.setFontSize(7);pdf.text('kinshasachristianschool.org · kinshasachristianschool@gmail.com',15,283);pdf.text(i+' / '+pages,195,283,{align:'right'});pdf.text(tr('Émis le ','Issued ')+new Date().toLocaleString(fr?'fr-FR':'en-GB',{timeZone:'Africa/Kinshasa'})+' · Kinshasa',15,288)}
 pdf.save(('Election - '+audience+' - '+data.election.academicYear+' - '+data.election.title).replace(/[<>:"/\\|?*\u0000-\u001f]/g,'-')+'.pdf');
}
