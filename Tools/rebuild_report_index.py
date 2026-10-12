"""Rebuild the offline/phone history index without removing earlier reports."""
from pathlib import Path
import re, json, html
ROOT = Path(__file__).resolve().parents[1]

def text(value):
 return html.unescape(re.sub(r"<[^>]+>", " ", value)).strip()

def build():
 summary=(ROOT/"Reports/development_summary.html").read_text(encoding="utf8")
 theme=(ROOT/"Reports/report_theme.css").read_text(encoding="utf8")
 records=[{"title":"Architecture and system wiki","kind":"Reference","local":"../.wiki/index.html","online":"../Wiki/index.html","description":"Searchable current systems, authoring guides, API and scene dependencies."}]
 for match in re.finditer(r'<section[^>]*id="([^"]+)"',summary):
  part=summary[match.end():];end=part.find("</section>");part=part[:end] if end>=0 else part
  heading=re.search(r"<h2[^>]*>(.*?)</h2>",part,re.S)
  if not heading: continue
  lead=re.search(r'<p[^>]*class="lead"[^>]*>(.*?)</p>',part,re.S)
  records.append({"title":text(heading.group(1)),"kind":"Development history","local":"development_summary.html#"+match.group(1),"online":"../index.html#"+match.group(1),"description":text(lead.group(1)) if lead else "Preserved development chapter and verification."})
 for folder,title in [("MemoryTriggers","Memory objects: required E interactions and look flavor"),("MulchFollowup","Mulch followup: repair, flashlight and physical journal"),("IssueBatch","October issue pass: engine checks and revised art"),("RailStations","Rail stations, lever upgrades and prestige permission"),("WorldPrompts","In-world look, carry and ghost controls"),("HUDFeedback","Restored crosshair, carry and build prompts"),("WorldInterfaces","PC screen and physical notes"),("PortalEnvironments","Playable apartment, warehouse and hospital"),("Hospital","Hospital architecture and props"),("Warehouse","Warehouse architecture and machines"),("StudioFurniture","Furnished apartment and separate items"),("StudioApartment","Original unfurnished studio")]:
  if (ROOT/"Reports"/folder/"index.html").is_file():
   records.append({"title":title,"kind":"Rendered gallery","local":folder+"/index.html","online":"../"+folder+"/index.html","description":"Reviewed actual renders and authored assets. Earlier work retained as history."})
 cards=""
 for index,row in enumerate(records):
  esc=html.escape
  cards+='<article class="archive-card" data-search="'+esc(' '.join(row.values()),quote=True)+'"><p class="eyebrow">'+esc(row['kind'])+'</p><h3><a data-local="'+esc(row['local'])+'" data-online="'+esc(row['online'])+'" href="'+esc(row['local'])+'">'+esc(row['title'])+'</a></h3><p>'+esc(row['description'])+'</p><span class="number">'+str(index+1).zfill(2)+'</span></article>'
 extra=".archive-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:0;border-left:1px solid var(--line);border-top:1px solid var(--line)}.archive-card{border-right:1px solid var(--line);border-bottom:1px solid var(--line);padding:24px;min-width:0}.archive-card h3{font-size:26px;overflow-wrap:anywhere}.archive-card p{color:var(--muted)}.archive-card .eyebrow{color:var(--rust)}.archive-search{width:100%;padding:16px;border:1px solid var(--ink);background:transparent;font:16px Consolas,monospace;color:var(--ink);margin-bottom:16px}[hidden]{display:none!important}@media(max-width:800px){.archive-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:480px){.archive-grid{grid-template-columns:1fr}}"
 doc='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Development index</title><style>'+theme+extra+'</style></head><body><header><div class="wrap"><a class="brand" href="index.html">REMNANT / DEVELOPMENT</a><span class="stamp">THE PROJECT ARCHIVE</span></div></header><main class="wrap"><nav><a href="index.html" aria-current="page">INDEX</a><a data-local="development_summary.html" data-online="../index.html" href="development_summary.html">SUMMARY</a><a data-local="../.wiki/index.html" data-online="../Wiki/index.html" href="../.wiki/index.html">SYSTEM WIKI</a><a href="https://github.com/CoolBeanGames/Remnant-GD">SOURCE</a></nav><section class="hero"><div><p class="eyebrow">HISTORY / REFERENCES / ACTUAL RENDERS</p><h1>Field<br>notes.</h1></div><p class="intro">One index for every development chapter, environment gallery and current system guide. Earlier work stays accessible.</p></section><label class="eyebrow" for="archive-filter">FIND A CHANGE OR ASSET</label><input id="archive-filter" class="archive-search" type="search" placeholder="Notes, portal, fan, warehouse…"><p id="archive-count" class="fine" aria-live="polite"></p><div class="archive-grid">'+cards+'</div><footer>Offline self-contained pages and hosted phone archives. Historical descriptions reflect their date; current guides take precedence.</footer></main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);const cards=[...document.querySelectorAll(".archive-card")],filter=document.getElementById("archive-filter"),count=document.getElementById("archive-count");function applyFilter(){const terms=filter.value.toLowerCase().trim().split(/\\s+/).filter(Boolean);let visible=0;cards.forEach(card=>{card.hidden=!terms.every(term=>card.dataset.search.toLowerCase().includes(term));if(!card.hidden)visible++});count.textContent=visible+" / "+cards.length+" entries"}filter.addEventListener("input",applyFilter);applyFilter();</script></body></html>'
 (ROOT/"Reports/index.html").write_text(doc,encoding="utf8")
 (ROOT/"Reports/index.json").write_text(json.dumps(records,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
 print("Development index rebuilt:",len(records),"preserved entries")

if __name__=="__main__": build()
