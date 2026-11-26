export function electionGreeting(name:string,language:'fr'|'en',now=new Date()){
 const hour=Number(new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Kinshasa',hour:'numeric',hourCycle:'h23'}).format(now));
 const salutation=language==='fr'?(hour>=18||hour<5?'Bonsoir':hour>=12?'Bon après-midi':'Bonjour'):(hour>=18||hour<5?'Good evening':hour>=12?'Good afternoon':'Good morning');
 return salutation+(name.trim()?', '+name.trim():'');
}
