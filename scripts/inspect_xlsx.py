import json,sys,zipfile,xml.etree.ElementTree as ET
NS={"m":"http://schemas.openxmlformats.org/spreadsheetml/2006/main","r":"http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
RNS={"p":"http://schemas.openxmlformats.org/package/2006/relationships"}
def val(c,shared):
 t=c.get("t")
 if t=="inlineStr": return "".join(x.text or "" for x in c.findall(".//m:t",NS))
 v=c.find("m:v",NS)
 if v is None:return ""
 raw=v.text or ""
 return shared[int(raw)] if t=="s" else raw
with zipfile.ZipFile(sys.argv[1]) as z:
 shared=[]
 if "xl/sharedStrings.xml" in z.namelist():
  root=ET.fromstring(z.read("xl/sharedStrings.xml"));shared=["".join(t.text or "" for t in si.findall(".//m:t",NS)) for si in root.findall("m:si",NS)]
 wb=ET.fromstring(z.read("xl/workbook.xml"));rels=ET.fromstring(z.read("xl/_rels/workbook.xml.rels"));targets={r.get("Id"):r.get("Target") for r in rels.findall("p:Relationship",RNS)};out=[]
 for sh in wb.findall("m:sheets/m:sheet",NS):
  target=targets[sh.get("{%s}id"%NS["r"])];sp=target.lstrip("/") if target.lstrip("/").startswith("xl/") else "xl/"+target.lstrip("/");root=ET.fromstring(z.read(sp));rows=root.findall("m:sheetData/m:row",NS);preview=[]
  for row in rows[:8]:preview.append([val(c,shared) for c in row.findall("m:c",NS)])
  out.append({"sheet":sh.get("name"),"row_count":len(rows),"preview":preview})
 print(json.dumps(out,ensure_ascii=True,indent=2))
