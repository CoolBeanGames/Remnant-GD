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
            lines=block.splitlines()
            if len(lines)>1 and lines[0].startswith('|') and re.fullmatch(r'[| :\-]+',lines[1]):
                rows=[[cell.strip() for cell in line.strip().strip('|').split('|')] for line in lines]
                content.append('<table><thead><tr>'+''.join('<th>'+html.escape(cell)+'</th>' for cell in rows[0])+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(cell)+'</td>' for cell in row)+'</tr>' for row in rows[2:])+'</tbody></table>')
                continue
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
            row['summary']='In-world object/carry/build prompts, PC display and physical notes with modal visibility restoration.'
    feedback_id='page-ui-gameplay-feedback'
    feedback_text=(ROOT/'Data/GAMEPLAY_FEEDBACK.md').read_text(encoding='utf-8-sig')
    feedback_page='<div id="'+feedback_id+'" class="doc-page">'+prose(feedback_text)+'</div>'
    position=next((i for i,page in enumerate(pages) if 'id="'+feedback_id+'"' in page),None)
    if position is None:
        pages.append(feedback_page)
        item='<li><a class="nav-item-link" data-page="'+feedback_id+'" href="#'+feedback_id+'">Essential gameplay feedback</a></li>'
        nav,count=re.subn(r'<li>\s*<a\b[^>]*data-page="page-ui-computer".*?</li>',lambda m:m[0]+item,nav,count=1,flags=re.S)
        assert count==1,'UI category anchor missing'
        index.append({'id':feedback_id,'title':'Essential gameplay feedback','category':'UI','keywords':'crosshair prompts carrying building combo captions portal hud minimal UI','summary':'Reusable world prompt scenes, authoring markers and essential feedback with modal restoration.','text':feedback_text})
    else:
        pages[position]=feedback_page
        next(row for row in index if row['id']==feedback_id)['text']=feedback_text
    # Refresh the original prompt reference IDs, preserving incoming links.
    blocks=feedback_text.split('\n\n')
    def prompt_paragraph(prefix):
        return next(block for block in blocks if block.startswith(prefix))
    prompt_refs={
        'page-ui-prompts-overview': '# In-world gameplay prompts\n\n'+prompt_paragraph('Scenes/testing_level.tscn')+'\n\n'+prompt_paragraph('World lettering'),
        'page-ui-prompt-display': '# prompt_display.gd / Node3D\n\n'+prompt_paragraph('Scripts/UI/prompt_display.gd')+'\n\n'+prompt_paragraph('World lettering'),
        'page-ui-object-prompts': '# object_prompts.gd / Node\n\n'+prompt_paragraph('Scripts/UI/object_prompts.gd'),
        'page-ui-world-prompt-label': '# world_prompt_label.gd / Label3D\n\n'+prompt_paragraph('Scripts/UI/world_prompt_label.gd'),
    }
    for ref_id,markdown in prompt_refs.items():
        ref_page='<div id="'+ref_id+'" class="doc-page">'+prose(markdown)+'</div>'
        slot=next((i for i,page in enumerate(pages) if 'id="'+ref_id+'"' in page),None)
        if slot is None:
            pages.append(ref_page)
            item='<li><a class="nav-item-link" data-page="'+ref_id+'" href="#'+ref_id+'">world_prompt_label.gd</a></li>'
            nav,count=re.subn(r'(<li>\s*<a\b[^>]*data-page="page-ui-prompt-label".*?</li>)',lambda match:item+match[0],nav,count=1,flags=re.S)
            assert count==1,'Prompt label sidebar anchor missing'
            index.append({'id':ref_id,'title':'world_prompt_label.gd','category':'UI','keywords':'Label3D world prompts font outline reusable scene','summary':'Reusable world lettering and per-control typography.','text':markdown})
        else:
            pages[slot]=ref_page
            next(row for row in index if row['id']==ref_id)['text']=markdown
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
    # Current maintained gameplay/workflow guides keep sidebar, body and search in sync.
    maintained = [
		('page-global-settings', 'Settings / audio and mouse', 'Globals', 'Data/OPTIONS.md', None, 'Settings startup maximized fullscreen window filling render scale SFX title ambience'),
		('page-title-options', 'Title screen, controls and graphics', 'UI', 'Data/OPTIONS.md', None, 'title grinder Machine Audio optional ambience Options SFX resized display fullscreen'),
        ('page-plate-snapping', 'Steel plate edge snapping', 'Actors', 'Data/Items/PLATE_SNAPPING.md', 'page-manual-automation', 'steel_plate left right top bottom four edge snap ghost B R wheel hinge carry save collision'),
        ('page-memory-triggers', 'Memory interactions and look flavor', 'Scripts', 'Data/Dialogue/MEMORY_TRIGGERS.md', 'page-door-portal', 'memory object photo phone bills coffee TV flavor gaze E 3 5 4 completion saved dialogue'),
        ('page-mulch-followup', 'Mulch, flashlight and journal followup', 'Overview', 'Data/ISSUE_FOLLOWUP_2026-10-12.md', 'page-october-issue-pass', 'mulch automatic lever collector pellets half score flashlight T portal F9 journal click'),
        ('page-player-flashlight', 'Player flashlight and portal beam', 'Scripts', 'Data/Portal/README.md', 'page-door-portal', 'SpotLight3D T player flashlight beam portal lighting on off'),
        ('page-october-issue-pass', 'October issue pass / recorder inputs', 'Overview', 'Data/ISSUE_BATCH_2026-10-12.md', 'page-development-archive', 'F1 F7 webcam microphone camera lifetime discovery combo Mulcher pellets memory return stairs'),
        ('page-global-gameplay-recorder', 'Gameplay recorder / optional inputs', 'Globals', 'Data/RECORDING.md', None, 'F6 F7 webcam microphone recorder lossless FFmpeg aspect'),
        ('page-rail-stations', 'Rail loader and unloader', 'Actors', 'Data/Items/RAIL_STATIONS.md', 'page-manual-automation', 'rail station loader unloader endpoint cargo basket docking queue save'),
        ('page-door-portal', 'Doorway portal and memory areas', 'Scripts', 'Data/Portal/ENVIRONMENTS.md', None, 'portal memory unlock completion return closure cargo F9 preview'),
        ('page-memory-upgrades', 'Memory unlock upgrades', 'Scripts', 'Data/Computer/MEMORY_UPGRADES.md', 'page-lever-upgrades', 'memory unlock story flags score 1500 25000 50000 Self save New Game'),
        ('page-global-progression', 'Progression / computer purchases', 'Globals', 'Data/Computer/README.md', None, 'computer upgrade purchase score levels unlock_flag memory flag'),
        ('page-computer-catalog', 'Editable catalog and effects', 'Computer', 'Data/Computer/README.md', None, 'computer_entry required_purchase Store ownership prerequisite upgrade catalog effects'),
        ('page-lever-upgrades', 'Manual lever upgrades', 'Scripts', 'Data/Computer/LEVER_UPGRADES.md', 'page-scripts-actors-lever-controller', 'lever cooldown animation speed output spawn batch manual queue'),
        ('page-prestige-items', 'Prestige items permission', 'Mulch', 'Data/Mulch/PRESTIGE_ITEMS.md', 'page-mulch-scenes', 'prestige items grind additional items true ending mulch permanent pickup'),
        ('page-development-reports', 'Development reporting skill', 'Overview', 'Data/REPORTING.md', 'page-development-archive', 'reporting skill html template style GitHub Pages publication Notion'),
        ('page-global-mulch', 'Mulch / bank and permanent upgrades', 'Globals', 'Data/Mulch/README.md', None, 'mulcher pellets permanent upgrades prestige items repair profile'),
        ('page-scripts-actors-lever-controller', 'lever_controller.gd', 'Scripts', 'Data/Computer/LEVER_UPGRADES.md', None, 'lever pull reset animation cooldown output Audio'),
    ]
    for ref_id, title, category, guide_path, after_id, keywords in maintained:
        markdown=(ROOT/guide_path).read_text(encoding='utf-8-sig')
        if guide_path.endswith('SKILL.md'):
            markdown=re.sub(r'^---\n.*?\n---\n', '', markdown, count=1, flags=re.S)
        page='<div id="'+ref_id+'" class="doc-page">'+prose(markdown)+'</div>'
        slot=next((i for i,part in enumerate(pages) if 'id="'+ref_id+'"' in part),None)
        if slot is None:
            pages.append(page)
            item='<li><a class="nav-item-link" data-page="'+ref_id+'" href="#'+ref_id+'">'+html.escape(title)+'</a></li>'
            nav,count=re.subn(r'(<li>\s*<a\b[^>]*data-page="'+re.escape(after_id)+r'".*?</li>)',lambda match:match[0]+item,nav,count=1,flags=re.S)
            assert count==1, 'Missing maintained-guide sidebar anchor '+str(after_id)
            index.append({'id':ref_id,'title':title,'category':category,'keywords':keywords,'summary':markdown.split('\n\n')[1].replace('\n',' ')[:260],'text':markdown})
        else:
            pages[slot]=page
            row=next(row for row in index if row['id']==ref_id)
            row.update({'title':title,'keywords':keywords,'text':markdown})
    page_ids=[re.search(r'id="([^"]+)"',page)[1] for page in pages]

    if feedback_id not in page_ids: page_ids.append(feedback_id)
    if archive_id not in page_ids: page_ids.insert(0,archive_id)
    for ref_id in prompt_refs:
        if ref_id not in page_ids: page_ids.append(ref_id)
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

