/* Data is embedded by rebuild_wiki.py; no network is required to search. */
const pages=[...document.querySelectorAll('.doc-page')];
const links=[...document.querySelectorAll('.nav-item-link')];
const searchInput=document.getElementById('wiki-filter');
const results=document.getElementById('search-results');
const resultList=document.getElementById('search-list');
const sidebar=document.getElementById('sidebar');
let activePage='page-overview';
document.querySelectorAll('[data-local]').forEach(a=>a.href=location.protocol==='file:'?a.dataset.local:a.dataset.online);
function normalize(value){return String(value||'').toLowerCase().normalize('NFKC');}
const indexed=searchIndex.map(item=>({...item, searchable:normalize([item.title,item.category,item.keywords,item.summary,item.text].join(' '))}));
function navigateToPage(id,writeHash=true){
 if(!document.getElementById(id)||!pages.some(p=>p.id===id))id='page-overview';
 activePage=id;searchInput.value='';results.hidden=true;
 pages.forEach(p=>p.classList.toggle('active',p.id===id));
 links.forEach(a=>{const selected=a.dataset.page===id;a.classList.toggle('active',selected);if(selected)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});
 sidebar.classList.remove('open');document.getElementById('systems-menu').setAttribute('aria-expanded','false');
 if(writeHash&&location.hash!=='#'+id)history.pushState(null,'','#'+id);
 if(writeHash)document.getElementById('reference-main').scrollIntoView({block:'start',behavior:'instant'});
}
function route(){let id;try{id=decodeURIComponent(location.hash.slice(1));}catch{id='page-overview';}if(id&&!id.startsWith('page-'))id='page-'+id;navigateToPage(id||'page-overview',false);}
links.forEach(a=>a.addEventListener('click',e=>{e.preventDefault();navigateToPage(a.dataset.page);}));
function search(){
 const query=normalize(searchInput.value.trim());
 if(!query){results.hidden=true;pages.forEach(p=>p.classList.toggle('active',p.id===activePage));return;}
 const terms=query.split(/\s+/).filter(Boolean);
 const matches=indexed.filter(item=>terms.every(term=>item.searchable.includes(term)));
 pages.forEach(p=>p.classList.remove('active'));results.hidden=false;resultList.replaceChildren();
 document.getElementById('search-count').textContent=matches.length+' results for '+searchInput.value.trim();
 matches.forEach(item=>{
  const button=document.createElement('button');button.type='button';button.className='search-result';
  for(const [name,value] of [['category',item.category],['title',item.title],['snippet',item.summary]]){const span=document.createElement('span');span.className='result-'+name;span.textContent=value||'';button.append(span);}
  button.addEventListener('click',()=>navigateToPage(item.id));resultList.append(button);
 });
 if(!matches.length){const p=document.createElement('p');p.textContent='No matching system. Try audio, notes, portal, player or save.';resultList.append(p);}
}
searchInput.addEventListener('input',search);
document.getElementById('clear-search').addEventListener('click',()=>{searchInput.value='';search();searchInput.focus();});
document.getElementById('systems-menu').addEventListener('click',e=>{const open=sidebar.classList.toggle('open');e.currentTarget.setAttribute('aria-expanded',String(open));if(open)searchInput.focus();});
window.addEventListener('hashchange',route);window.addEventListener('popstate',route);
window.addEventListener('keydown',e=>{if(e.key==='/'&&!['INPUT','TEXTAREA'].includes(document.activeElement.tagName)&&!document.activeElement.isContentEditable){e.preventDefault();sidebar.classList.add('open');document.getElementById('systems-menu').setAttribute('aria-expanded','true');searchInput.focus();searchInput.select();}});
async function copyCode(btn){const code=btn.closest('.code-block-wrapper')?.querySelector('pre');if(!code)return;try{await navigator.clipboard.writeText(code.innerText);const old=btn.innerText;btn.innerText='COPIED';setTimeout(()=>btn.innerText=old,1500);}catch{const range=document.createRange();range.selectNodeContents(code);const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range);btn.innerText='SELECTED / COPY';}}
route();
