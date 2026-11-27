const CACHE="kcs-student-election-shell-20261126-install-panel";
const CORE=["/student-government/","/student-government/login/","/student-government/manifest.webmanifest","/kcs.jpg","/kcs-election-192.png","/kcs-election-512.png"];
self.addEventListener("install",event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE))));
self.addEventListener("message",event=>{if(event.data?.type==="SKIP_WAITING")self.skipWaiting()});
self.addEventListener("activate",event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith("kcs-student-election-")&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener("fetch",event=>{
 const request=event.request,url=new URL(request.url);
  if(url.pathname.endsWith('/app-version.json'))return;
 if(request.method!=="GET"||url.origin!==self.location.origin||url.pathname.startsWith("/api/")||request.headers.has("authorization"))return;
 if(request.mode==="navigate"&&!url.pathname.startsWith("/student-government/"))return;
 if(request.mode==="navigate"){event.respondWith(fetch(request).then(response=>{if(response.ok){const copy=response.clone();event.waitUntil(caches.open(CACHE).then(cache=>cache.put(request,copy)))}return response}).catch(async()=>await caches.match(request)||await caches.match("/student-government/")||new Response("Connect to load this page.",{status:503})));return}
 if(["script","style","image","font"].includes(request.destination))event.respondWith(caches.match(request).then(cached=>cached||fetch(request).then(response=>{if(response.ok){const copy=response.clone();event.waitUntil(caches.open(CACHE).then(cache=>cache.put(request,copy)))}return response})));
});
