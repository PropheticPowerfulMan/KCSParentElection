
import type {Electorate} from './orbit-api';

type ReportMode='overview'|'participation'|'results';
/** Aggregate snapshot: voter identities and individual ballot choices never enter a report. */
export async function downloadElectionReport(data:any,audience:Electorate,fr:boolean,mode:ReportMode='overview'){
 const [{jsPDF},qr]=await Promise.all([import('jspdf'),import('qrcode')]);
 const pdf=new jsPDF({unit:'mm',format:'a4',compress:true}),tr=(f:string,e:string)=>fr?f:e;
 const navy=[23,49,73] as const,ink=[30,54,74] as const,blue=[40,90,123] as const,gold=[159,125,65] as const,muted=[81,101,116] as const,pale=[233,238,241] as const,line=[192,206,215] as const;
 const reference='KCS-EL-'+data.election.id.toUpperCase(),verification='https://kcsparentelection.kinshasachristianschool.org'+(audience==='STUDENT'?'/student-government':'')+'/results/?election='+encodeURIComponent(data.election.id);
 const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify({election:data.election,eligible:data.eligibleCount,participation:data.participation,ballots:data.ballots,offices:data.offices,mode}))))).map(n=>n.toString(16).padStart(2,'0')).join('');
 const issued=new Date(),date=(v:string)=>new Date(v).toLocaleString(fr?'fr-FR':'en-GB',{timeZone:'Africa/Kinshasa',day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'});
 const clean=(v:unknown)=>String(v??'').replace(/[–—]/g,'-').replace(/[‘’]/g,"'").replace(/[“”]/g,'"').replace(/œ/g,'oe').replace(/Œ/g,'OE').replace(/→/g,'>');
 const title=mode==='participation'?tr('Participation et intégrité','Participation & integrity'):mode==='results'?tr('Résultats officiels par poste','Official results by office'):tr('Rapport officiel du scrutin','Official election report');
 const kind=audience==='PARENT'?tr('Comité des parents','Parent committee'):tr('Gouvernement des élèves','Student government');
 const state=({DRAFT:tr('Brouillon','Draft'),OPEN:tr('Vote ouvert / programmé','Open / scheduled'),CLOSED:tr('Clôturé','Closed'),PUBLISHED:tr('Résultats publiés','Published results'),ARCHIVED:tr('Archivé','Archived')} as Record<string,string>)[data.election.status]||data.election.status;
 const code=await qr.toDataURL(verification,{width:720,margin:4,errorCorrectionLevel:'Q'});
 let logo='';try{const base=process.env.GITHUB_ACTIONS==='true'&&process.env.KCS_CUSTOM_DOMAIN!=='true'?'/KCSParentElection':'';const r=await fetch(base+'/kcs.jpg');if(!r.ok)throw Error('logo');const blob=await r.blob();logo=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=reject;reader.readAsDataURL(blob)})}catch{}
 pdf.setProperties({title:clean(title+' - '+data.election.title),subject:clean(kind+' - '+data.election.academicYear),author:'Kinshasa Christian School',creator:'KCS Orbit - Election administration',keywords:'KCS, election, official, aggregate report'});
 let y=0;
 function font(size:number,bold=false,color:readonly[number,number,number]=ink){pdf.setFont('helvetica',bold?'bold':'normal');pdf.setFontSize(size);pdf.setTextColor(...color)}
 function header(){
  pdf.setFillColor(...navy);pdf.rect(0,0,210,36,'F');pdf.setFillColor(36,65,90);pdf.triangle(172,0,210,0,210,36,'F');pdf.setFillColor(...gold);pdf.triangle(201,0,210,0,210,9,'F');pdf.rect(0,36,210,.65,'F');pdf.setDrawColor(...gold);pdf.setLineWidth(.2);pdf.line(15,38,195,38);
  if(logo){pdf.setFillColor(255,255,255);pdf.roundedRect(14,6,25,25,3,3,'F');pdf.addImage(logo,'JPEG',15.5,7.5,22,22)}
  const x=logo?45:15;font(8,true,[205,222,235]);pdf.text('KCS ORBIT ECOSYSTEM',x,11);
  font(14,true,[255,255,255]);pdf.text('KINSHASA CHRISTIAN SCHOOL',x,19);
  font(7.3,false,[205,222,235]);pdf.text(clean(tr('COMMISSION ÉLECTORALE','ELECTION COMMISSION')+'  /  '+kind),x,26);font(6.5,true,[225,200,152]);pdf.text(data.election.academicYear,195,32,{align:'right'});
  if(logo){pdf.saveGraphicsState();pdf.setGState(pdf.GState({opacity:.035}));pdf.addImage(logo,'JPEG',49,111,112,112);pdf.restoreGraphicsState()}
  y=47;
 }
 function room(height:number){if(y+height>260){pdf.addPage();header();font(8,true,muted);pdf.text(clean(title+' / '+data.election.academicYear),15,y);y+=9}}
 function paragraph(value:string,size=9,bold=false,color:readonly[number,number,number]=ink){font(size,bold,color);const lines=pdf.splitTextToSize(clean(value),180);for(const l of lines){room(size*.45+2);font(size,bold,color);pdf.text(l,15,y);y+=size*.45+1}y+=4}
 function section(value:string,following=0){room(17+following);pdf.setDrawColor(...line);pdf.line(15,y,195,y);y+=8;font(10,true,blue);pdf.text(clean(value),15,y);y+=7}

 header();font(7.2,true,gold);pdf.text(clean(tr('GOUVERNANCE SCOLAIRE / ÉDITION INSTITUTIONNELLE','SCHOOL GOVERNANCE / INSTITUTIONAL EDITION')),15,y);y+=9;paragraph(title,22,true);paragraph(data.election.title,13,true);paragraph(kind+'  /  '+data.election.academicYear+'  /  '+state,9,false,muted);
 const details=[[tr('DÉBUT DU VOTE','VOTING START'),date(data.election.startAt)],[tr('CLÔTURE PRÉVUE','VOTING DEADLINE'),date(data.election.endAt)]];
 room(23);for(let i=0;i<2;i++){const x=15+i*92;font(7,true,blue);pdf.text(details[i][0],x,y);font(8);pdf.text(clean(details[i][1]+' - Kinshasa (UTC+1)'),x,y+6)}y+=17;
 room(72);const panel=y-2;pdf.setFillColor(...navy);pdf.roundedRect(15,panel,180,65,3,3,'F');pdf.setFillColor(36,65,90);pdf.roundedRect(16,panel+1,68,63,3,3,'F');
 const cx=49,cy=panel+29,radius=19,turn=typeof data.turnout==='number'?Math.max(0,Math.min(100,data.turnout)):0;
 pdf.setDrawColor(70,93,112);pdf.setLineWidth(4);pdf.circle(cx,cy,radius,'S');pdf.setDrawColor(217,187,128);pdf.setLineWidth(4);
 for(let angle=-90;angle<-90+turn*3.6;angle+=2){const next=Math.min(angle+2,-90+turn*3.6),rad=angle*Math.PI/180,rad2=next*Math.PI/180;pdf.line(cx+Math.cos(rad)*radius,cy+Math.sin(rad)*radius,cx+Math.cos(rad2)*radius,cy+Math.sin(rad2)*radius)}
 font(19,true,[255,255,255]);pdf.text(data.turnout===null?'N/A':data.turnout+'%',cx,cy+2,{align:'center'});font(6.2,true,[210,224,236]);pdf.text(clean(tr('PARTICIPATION','TURNOUT')),cx,cy+9,{align:'center'});
 font(6.8,false,[210,224,236]);pdf.text(clean(tr('Une identité. Une participation.','One identity. One participation.')),cx,panel+57,{align:'center'});
 const metrics=[[tr('ÉLECTEURS ÉLIGIBLES','ELIGIBLE VOTERS'),data.eligibleCount],[tr('PARTICIPATIONS','PARTICIPANTS'),data.participation],[tr('BULLETINS CONFIRMÉS','CONFIRMED BALLOTS'),data.ballots],[tr('POSTES À POURVOIR','OFFICES'),data.offices.length]];
 for(let i=0;i<4;i++){const x=93+(i%2)*51,top=panel+11+Math.floor(i/2)*28;font(6.2,true,[185,207,224]);pdf.text(clean(metrics[i][0]),x,top);font(19,true,[255,255,255]);pdf.text(String(metrics[i][1]),x,top+12)}
 pdf.setDrawColor(63,88,109);pdf.setLineWidth(.2);pdf.line(93,panel+32,185,panel+32);pdf.line(138,panel+9,138,panel+55);y=panel+74;
 section(tr('01  /  Fiabilité et lecture des données','01  /  Integrity & interpretation'));
 paragraph(tr('Taux = participations confirmées / électeurs éligibles × 100.','Turnout = confirmed participants / eligible voters × 100.'),8,false,muted);
 paragraph(data.participation===data.ballots?tr('CONCORDANCE VÉRIFIÉE : chaque participation correspond à un bulletin enregistré.','TOTALS VERIFIED: every participation matches one recorded ballot.'):tr('ÉCART À EXAMINER : vérifier les totaux avant toute proclamation.','DISCREPANCY TO REVIEW: verify the totals before publication.'),9,true);
 if(mode!=='results'&&(data.participationByClass||[]).length){
  section(tr('02  /  Participation par classe','02  /  Participation by class'));
  for(const row of data.participationByClass){room(15);const label=[row.grade,row.section].filter(Boolean).join(' ')||tr('Parents - ensemble de l’école','Parents - school-wide'),part=data.participation?row.count/data.participation*100:0;font(8,true);pdf.text(clean(label),15,y);font(8);pdf.text(row.count+'  /  '+part.toFixed(1)+'%',195,y,{align:'right'});y+=4;pdf.setFillColor(...pale);pdf.rect(15,y,180,2,'F');if(part){pdf.setFillColor(...gold);pdf.rect(15,y,180*part/100,2,'F')}y+=9}
  paragraph(tr('Pourcentage de la participation totale, et non taux de présence de chaque classe.','Share of total participation, rather than an individual class turnout rate.'),8,false,muted);
 }
 if(mode!=='participation'){
  section(tr('03  /  Décompte détaillé des responsabilités','03  /  Detailed office tallies'),65);
  if(!data.talliesVisible)paragraph(tr('Les résultats intermédiaires sont protégés. Seules les données de participation sont disponibles à ce stade.','Interim tallies are protected. Only participation figures are available at this stage.'),10);
  else for(const [index,office]of data.offices.entries()){
   room(39);pdf.setFillColor(...pale);pdf.roundedRect(15,y-5,180,17,2,2,'F');pdf.setFillColor(...gold);pdf.rect(15,y-5,1.2,17,'F');font(11,true,blue);const name=pdf.splitTextToSize(clean(String(index+1).padStart(2,'0')+'  '+office.name),176);pdf.text(name,20,y+2);y+=Math.max(16,name.length*5+7);paragraph(office.scope==='CLASS'?[office.grade,office.section].filter(Boolean).join(' '):tr('Responsabilité pour toute l’école','School-wide office'),8,false,muted);
   const candidates=[...office.candidates].filter((c:any)=>c.status===undefined||c.status==='APPROVED'||c.votes>0).sort((a:any,b:any)=>(b.votes||0)-(a.votes||0)),total=candidates.reduce((sum:number,c:any)=>sum+(c.votes||0),0)+(office.abstentions||0);
   function tableHead(){room(11);pdf.setFillColor(...navy);pdf.roundedRect(15,y-4,180,9,1,1,'F');font(7,true,[255,255,255]);pdf.text('#',19,y+1);pdf.text(clean(tr('CANDIDAT / CANDIDATE','CANDIDATE')),30,y+1);pdf.text(clean(tr('VOIX','VOTES')),153,y+1,{align:'right'});pdf.text('%',190,y+1,{align:'right'});y+=12}
   tableHead();
   for(const [rank,candidate]of candidates.entries()){
    font(9);const lines=pdf.splitTextToSize(clean(candidate.name),110),height=Math.max(16,lines.length*4.2+10);if(y+height>260){room(height);font(9,true,blue);pdf.text(clean(office.name+' - '+tr('suite','continued')),15,y);y+=7;tableHead()}
    const percent=total?(candidate.votes||0)/total*100:0;if(rank%2===0){pdf.setFillColor(243,246,248);pdf.rect(15,y-4,180,height,'F')}font(8,false,muted);pdf.setFillColor(rank===0?gold[0]:blue[0],rank===0?gold[1]:blue[1],rank===0?gold[2]:blue[2]);pdf.circle(21,y-1,3.1,'F');font(7,true,[255,255,255]);pdf.text(String(rank+1),21,y,{align:'center'});font(9,true);pdf.text(lines,30,y);pdf.text(String(candidate.votes||0),153,y,{align:'right'});pdf.text(percent.toFixed(1)+'%',190,y,{align:'right'});const barY=y+lines.length*4.2+1;pdf.setFillColor(...pale);pdf.rect(30,barY,110,2,'F');if(percent){pdf.setFillColor(rank===0?gold[0]:blue[0],rank===0?gold[1]:blue[1],rank===0?gold[2]:blue[2]);pdf.rect(30,barY,110*percent/100,2,'F')}y+=height;
   }
   paragraph(tr('Total des suffrages et abstentions : ','Total selections and abstentions: ')+total+'  /  '+tr('Abstentions : ','Abstentions: ')+(office.abstentions||0),8,false,muted);
   const top=candidates[0]?.votes||0;if(top&&candidates.filter((c:any)=>c.votes===top).length>1)paragraph(tr('ÉGALITÉ : une décision officielle de la commission est requise.','TIE: an official commission decision is required.'),9,true);
   if(!total)paragraph(tr('Aucun suffrage enregistré pour ce poste.','No selections recorded for this office.'),8);
   paragraph(tr('Pourcentage = voix du candidat / total de ce poste, abstentions comprises.','Percentage = candidate votes / office total, including abstentions.'),7,false,muted);y+=3;
  }
 }
 section(tr('04  /  Référence et vérification institutionnelle','04  /  Institutional reference & verification'),62);
 room(62);const top=y;pdf.setDrawColor(...line);pdf.setFillColor(...pale);pdf.roundedRect(15,top-3,180,57,2,2,'FD');pdf.addImage(code,'PNG',18,top+1,32,32);font(8,true,blue);pdf.text(clean(tr('REGISTRE NUMÉRIQUE KCS ORBIT','KCS ORBIT DIGITAL REGISTER')),55,top+4);font(7.3);pdf.text(reference,55,top+11);
 const note=tr('Ce QR identifie le scrutin dans le registre Nexus. Connexion institutionnelle requise. Les résultats deviennent consultables après publication. Ce document est un instantané des données et ne constitue pas une signature cryptographique.','This QR identifies the election in the Nexus register. Institutional sign-in is required. Results become available after publication. This document is a data snapshot and does not constitute a cryptographic signature.');
 font(7.5,false,muted);pdf.text(pdf.splitTextToSize(clean(note),118),55,top+18);font(7.5,true);pdf.text(clean(tr('Émis le ','Issued ')+date(issued.toISOString())+' - Kinshasa'),55,top+40);font(6,false,muted);pdf.text('SHA-256: '+digest,18,top+50);y=top+62;
 const pages=pdf.getNumberOfPages();for(let n=1;n<=pages;n++){pdf.setPage(n);pdf.setDrawColor(...gold);pdf.setLineWidth(.45);pdf.line(15,270,195,270);font(7,true,blue);pdf.text('KINSHASA CHRISTIAN SCHOOL',15,276);pdf.text(n+' / '+pages,195,276,{align:'right'});font(6.5,false,muted);pdf.text('Avenue de la République n° 1 - Macampagne, Ngaliema - Kinshasa - Réf. 80 jours',15,281);pdf.text('+243 895 326 011  |  +243 994 645 735',15,285);pdf.text(reference,195,285,{align:'right'});pdf.text('kinshasachristianschool.org  |  kinshasachristianschool@gmail.com',15,290)}
 const filename=('KCS Election - '+mode+' - '+audience+' - '+data.election.academicYear+' - '+data.election.title).replace(/[<>:"/\\|?*\u0000-\u001f]/g,'-');pdf.save(filename+'.pdf');
}
