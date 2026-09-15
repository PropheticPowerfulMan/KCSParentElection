import json,re,sys,zipfile,xml.etree.ElementTree as ET
NS={"m":"http://schemas.openxmlformats.org/spreadsheetml/2006/main","r":"http://schemas.openxmlformats.org/officeDocument/2006/relationships"};RNS={"p":"http://schemas.openxmlformats.org/package/2006/relationships"}
def col(ref):
 s=re.match("[A-Z]+",ref).group();n=0
 for c in s:n=n*26+ord(c)-64
 return n-1
def norm(value):
 s=str(value or "").strip();bad=chr(0xfffd);chars=[]
 for i,ch in enumerate(s):
  if ch==bad:
   prev=s[i-1] if i else "";nxt=s[i+1] if i+1<len(s) else ""
   if prev.isalpha() and nxt.isalpha():chars.append("s")
  else:chars.append(ch)
 return " ".join("".join(chars).split())
def keyname(s):return "".join(c for c in norm(s).upper() if c.isalnum())
def phone(s):
 d="".join(c for c in norm(s) if c.isdigit())
 return "+243"+d[-9:] if len(d)>=9 else d
def email(s):
 e=norm(s).lower().replace("gmail,com","gmail.com").replace("yahoo,fr","yahoo.fr").replace(" ","")
 return e if "@" in e and "." in e.split("@")[-1] and not e.endswith("@ourkcs.org") else ""
def val(c,shared):
 t=c.get("t")
 if t=="inlineStr":return "".join(x.text or "" for x in c.findall(".//m:t",NS))
 v=c.find("m:v",NS)
 if v is None:return ""
 raw=v.text or "";return shared[int(raw)] if t=="s" else raw
with zipfile.ZipFile(sys.argv[1]) as z:
 shared=[]
 if "xl/sharedStrings.xml" in z.namelist():
  root=ET.fromstring(z.read("xl/sharedStrings.xml"));shared=["".join(t.text or "" for t in si.findall(".//m:t",NS)) for si in root.findall("m:si",NS)]
 wb=ET.fromstring(z.read("xl/workbook.xml"));rels=ET.fromstring(z.read("xl/_rels/workbook.xml.rels"));targets={r.get("Id"):r.get("Target") for r in rels.findall("p:Relationship",RNS)};students=[]
 for sh in wb.findall("m:sheets/m:sheet",NS):
  sn=sh.get("name");target=targets[sh.get("{%s}id"%NS["r"])];sp=target if target.startswith("xl/") else "xl/"+target.lstrip("/");root=ET.fromstring(z.read(sp));rows=[]
  for row in root.findall("m:sheetData/m:row",NS):rows.append({col(c.get("r")):norm(val(c,shared)) for c in row.findall("m:c",NS)})
  hi=next((i for i,r in enumerate(rows) if "NOMTUTEUR" in [keyname(v) for v in r.values()]),None)
  if hi is None:continue
  headers={keyname(v):k for k,v in rows[hi].items()}
  def idx(*names):
   for name in names:
    if name in headers:return headers[name]
  for row in rows[hi+1:]:
   ni=idx("N","NO");num=norm(row.get(ni if ni is not None else 0,""));sl=norm(row.get(idx("NOM"),""));gl=norm(row.get(idx("NOMTUTEUR"),""))
   if not sl or not gl or not num.isdigit():continue
   students.append({"sheet":sn,"student_number":num,"student_last_name":sl,"student_middle_name":norm(row.get(idx("POSTNOM"),"")),"student_first_name":norm(row.get(idx("PRENOM"),"")),"guardian_last_name":gl,"guardian_first_name":norm(row.get(idx("PRENOMTUTEUR"),"")),"phone":phone(row.get(idx("TELEPHONE"),"")),"email":email(row.get(idx("EMAIL"),"")),"ourkcs":norm(row.get(idx("OURKCS"),"")),"student_id":norm(row.get(idx("IDNUMBER"),""))})
 parent=list(range(len(students)))
 def find(x):
  while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
  return x
 def union(a,b):
  a=find(a);b=find(b)
  if a!=b:parent[b]=a
 tokens={}
 for i,s in enumerate(students):
  identity=[("name",keyname(s["guardian_last_name"]+" "+s["guardian_first_name"]))]
  if s["email"]:identity.append(("email",s["email"]))
  if len(s["phone"])>=9:identity.append(("phone",s["phone"]))
  for token in identity:
   if token in tokens:union(i,tokens[token])
   else:tokens[token]=i
 groups={}
 for i,s in enumerate(students):groups.setdefault(find(i),[]).append(s)
 ordered=[]
 for records in groups.values():
  best=max(records,key=lambda x:(bool(x["email"]),len(x["phone"])))
  children=[{"last_name":s["student_last_name"],"middle_name":s["student_middle_name"],"first_name":s["student_first_name"],"class":s["sheet"],"student_id":s["sheet"]+"-"+s["student_number"]} for s in records]
  ordered.append({"last_name":best["guardian_last_name"],"first_name":best["guardian_first_name"],"phone":best["phone"],"email":best["email"],"children":children})
 ordered.sort(key=lambda p:(keyname(p["last_name"]),keyname(p["first_name"])))
 for i,p in enumerate(ordered,1):p["parent_ref"]="KCS-PARENT-"+str(i).zfill(4)
 with open(sys.argv[2],"w",encoding="utf-8") as f:json.dump({"parents":ordered},f,ensure_ascii=False,indent=2)
 print(json.dumps({"students":len(students),"parents":len(ordered),"multi_child":sum(len(p["children"])>1 for p in ordered),"missing_email":sum(not p["email"] for p in ordered),"short_phone":sum(len(p["phone"])<9 for p in ordered)},ensure_ascii=False))
