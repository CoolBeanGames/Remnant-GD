"""Retain wiki pages, navigation and search; inline the common report design."""
from pathlib import Path
from html.parser import HTMLParser
import re, json, html
ROOT=Path(__file__).resolve().parents[1]

class Sections(HTMLParser):
    def __init__(self,source):
        super().__init__(convert_charrefs=False)
        self.source=source; self.lines=[0]; self.depth=0; self.open=[]; self.sections=[]
        for match in re.finditer('\n',source): self.lines.append(match.end())
        self.feed(source)
    def current_offset(self):
        line,column=self.getpos(); return self.lines[line-1]+column
    def handle_starttag(self,tag,attrs):
        if tag not in ('div','nav'): return
        attrs=dict(attrs); classes=attrs.get('class','').split()
        if 'doc-page' in classes or 'sidebar-nav' in classes:
            self.open.append((self.depth,self.current_offset(),attrs.get('id'),classes))
        self.depth+=1
    def handle_endtag(self,tag):
        if tag not in ('div','nav'): return
        self.depth-=1
        if self.open and self.open[-1][0]==self.depth:
            _,start,id,classes=self.open.pop(); end=self.source.index('>',self.current_offset())+1
            self.sections.append((id,classes,self.source[start:end]))

def build():
    path=ROOT/'.wiki/index.html'; source=path.read_text(encoding='utf-8-sig')
    parts=Sections(source).sections
    pages=[part for id,classes,part in parts if 'doc-page' in classes]
    nav=next(part for id,classes,part in parts if 'sidebar-nav' in classes)
    nav=re.sub(r'(<a\b[^>]*data-page="([^"]+)"[^>]*)(>)',lambda m:m[1]+('' if 'href=' in m[1] else ' href="#'+m[2]+'"')+m[3],nav)
    # Current authoring notes render as prose, with source metadata kept searchable.
    def prose(markdown):
        content=[]
        for block in markdown.strip().split('\n\n'):
            if block.startswith('#'):
                depth=len(block)-len(block.lstrip('#')); tag='h'+str(min(depth,3))
                content.append('<'+tag+'>'+html.escape(block[depth:].strip())+'</'+tag+'>')
            else: content.append('<p>'+html.escape(' '.join(block.splitlines()))+'</p>')
        return ''.join(content)
    for number,(id,classes,part) in enumerate([row for row in parts if 'doc-page' in row[1]]):
        if id=='page-world-interfaces':
            pages[number]='<div id="page-world-interfaces" class="doc-page">'+prose((ROOT/'Data/WORLD_INTERFACES.md').read_text(encoding='utf8'))+'</div>'
    marker=re.search(r'const searchIndex\s*=\s*',source)
    if not marker: raise ValueError('Missing embedded search index')
    index,_=json.JSONDecoder().raw_decode(source[marker.end():])
    for row in index:
        if row['id']=='page-world-interfaces':
            row['text']=(ROOT/'Data/WORLD_INTERFACES.md').read_text(encoding='utf-8-sig')
            row['summary']='PC display, physical notes and essential gameplay HUD with modal visibility restoration.'
    feedback_id='page-ui-gameplay-feedback'
    feedback_text=(ROOT/'Data/GAMEPLAY_FEEDBACK.md').read_text(encoding='utf-8-sig')
    feedback_page='<div id="'+feedback_id+'" class="doc-page">'+prose(feedback_text)+'</div>'
    position=next((i for i,page in enumerate(pages) if 'id="'+feedback_id+'"' in page),None)
    if position is None:
        pages.append(feedback_page)
        item='<li><a class="nav-item-link" data-page="'+feedback_id+'" href="#'+feedback_id+'">Essential gameplay feedback</a></li>'
        nav,count=re.subn(r'<li>\s*<a\b[^>]*data-page="page-ui-computer".*?</li>',lambda m:m[0]+item,nav,count=1,flags=re.S)
        assert count==1,'UI category anchor missing'
        index.append({'id':feedback_id,'title':'Essential gameplay feedback','category':'UI','keywords':'crosshair prompts carrying building combo captions portal hud minimal UI','summary':'Restored gameplay feedback and temporary hiding for PC/physical notes.','text':feedback_text})
    else:
        pages[position]=feedback_page
        next(row for row in index if row['id']==feedback_id)['text']=feedback_text
    archive_id='page-development-archive'
    archive_text=(ROOT/'Data/DOCUMENTATION.md').read_text(encoding='utf-8-sig')
    archive_page='<div id="'+archive_id+'" class="doc-page">'+prose(archive_text)+'</div>'
    existing=next((i for i,page in enumerate(pages) if 'id="'+archive_id+'"' in page),None)
    if existing is None:
        pages.insert(0,archive_page)
        nav=nav.replace('<ul class="nav-items">','<ul class="nav-items"><li><a class="nav-item-link" data-page="'+archive_id+'" href="#'+archive_id+'">Development archive / documentation</a></li>',1)
        index.insert(0,{'id':archive_id,'title':'Development archive / documentation','category':'Overview','keywords':'html summary index wiki history theme phone publication','summary':'Shared archive style, offline search, history and local/phone navigation.','text':archive_text})
    else:
        pages[existing]=archive_page
        next(row for row in index if row['id']==archive_id)['text']=archive_text
    page_ids=[id for id,classes,part in parts if 'doc-page' in classes]
    if feedback_id not in page_ids: page_ids.append(feedback_id)
    if archive_id not in page_ids: page_ids.insert(0,archive_id)
    assert len(page_ids)==len(set(page_ids)) and len(index)==len(page_ids)
    assert {row['id'] for row in index}==set(page_ids)
    theme=(ROOT/'Reports/report_theme.css').read_text(encoding='utf-8-sig')
    theme+='\n'+(ROOT/'Tools/wiki_theme.css').read_text(encoding='utf-8-sig')
    behavior=(ROOT/'Tools/wiki_behavior.js').read_text(encoding='utf-8-sig')
    header='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / System wiki</title><style>THEME</style></head><body>
<header><div class="wrap"><a class="brand" data-local="../Reports/index.html" data-online="../Archive/index.html" href="../Reports/index.html">REMNANT / DEVELOPMENT</a><span class="stamp">SYSTEMS / REFERENCE</span></div></header>
<div class="wrap"><nav aria-label="Project archive"><a data-local="../Reports/index.html" data-online="../Archive/index.html" href="../Reports/index.html">INDEX</a><a data-local="../Reports/development_summary.html" data-online="../index.html" href="../Reports/development_summary.html">SUMMARY</a><a href="#page-overview" aria-current="page">SYSTEM WIKI</a><a href="https://github.com/CoolBeanGames/Remnant-GD">SOURCE</a></nav><button id="systems-menu" class="menu-toggle" aria-controls="sidebar" aria-expanded="false">SYSTEMS / SEARCH</button></div>
<div class="reference-layout"><aside id="sidebar" class="reference-sidebar"><label class="eyebrow" for="wiki-filter">FIND A SYSTEM</label><input id="wiki-filter" type="search" placeholder="Notes, audio, portal…" autocomplete="off"><button id="clear-search" type="button">CLEAR SEARCH</button>NAV</aside>
<main id="reference-main" class="reference-main"><section id="search-results" hidden><p class="eyebrow">REFERENCE / SEARCH</p><h1 id="search-count" aria-live="polite"></h1><div id="search-list"></div></section>PAGES</main></div>
<footer><div class="wrap footer-row"><span>REMNANT / SYSTEM REFERENCE / COUNT PAGES</span><span>Current authoring guides take precedence over dated development history.</span></div></footer><script>const searchIndex = INDEX;
BEHAVIOR</script></body></html>'''
    output=header.replace('THEME',theme).replace('NAV',nav).replace('PAGES</main>','\n'.join(pages)+'</main>').replace('COUNT PAGES',str(len(pages))+' PAGES').replace('INDEX;\nBEHAVIOR',json.dumps(index,ensure_ascii=False).replace('</','<\\/')+';\n'+behavior)
    path.write_text(output,encoding='utf-8')
    print('Wiki rebuilt:',len(pages),'preserved pages and search entries')

if __name__=='__main__': build()

