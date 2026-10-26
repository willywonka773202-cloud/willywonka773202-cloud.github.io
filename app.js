(() => {
 const search=document.querySelector('#search'),stage=document.querySelector('#stage'),sort=document.querySelector('#sort'),media=document.querySelector('#media'),list=document.querySelector('#project-list');
 if(!search||!stage||!list)return;
 const groups=[...list.querySelectorAll('.project-group')],rows=[...list.querySelectorAll('.project-row')],filters=[...document.querySelectorAll('[data-filter]')],views=[...document.querySelectorAll('[data-view]')];
 const defaultView=list.dataset.defaultView||'grid';
 let category='All projects',view=defaultView;
 function readURL(){const q=new URLSearchParams(location.search);search.value=q.get('q')||'';stage.value=[...stage.options].some(o=>o.value===q.get('stage'))?q.get('stage'):'all';category=filters.some(f=>f.dataset.filter===q.get('category'))?q.get('category'):'All projects';sort.value=['name','recent','visual'].includes(q.get('sort'))?q.get('sort'):'visual';media.value=[...media.options].some(o=>o.value===q.get('media'))?q.get('media'):'all';view=['grid','list'].includes(q.get('view'))?q.get('view'):defaultView;filter(false);}
 function filter(update=true){
  const query=search.value.trim().toLowerCase();let visible=0;
  rows.sort((a,b)=>{if(sort.value==='visual'){const difference=Number(a.dataset.media==='Project map')-Number(b.dataset.media==='Project map');if(difference)return difference;}return sort.value==='name'?a.dataset.name.localeCompare(b.dataset.name):b.dataset.updated.localeCompare(a.dataset.updated)||a.dataset.name.localeCompare(b.dataset.name);});
  rows.forEach(row=>{const show=(!query||row.dataset.search.includes(query))&&(category==='All projects'||row.dataset.category===category)&&(stage.value==='all'||row.dataset.stage===stage.value)&&(media.value==='all'||row.dataset.media===media.value);row.hidden=!show;visible+=Number(show);});
  groups.forEach(group=>{
   const container=group.querySelector('.project-group-rows'),items=rows.filter(row=>row.dataset.category===group.dataset.projectGroup);let count=0;
   items.forEach(row=>{container.append(row);if(!row.hidden){count++;row.querySelector('.row-number').textContent=String(count).padStart(2,'0');}});
   group.hidden=count===0;group.querySelector('.group-count').textContent=`${count} ${count===1?'project':'projects'}${count!==items.length?` of ${items.length}`:''}`;
   container.classList.toggle('project-grid',view==='grid');
  });
  document.querySelector('#result-count').textContent=`${visible} ${visible===1?'project':'projects'}${visible!==rows.length?` of ${rows.length}`:''}`;
  document.querySelector('#empty').hidden=visible!==0;
  filters.forEach(f=>f.setAttribute('aria-pressed',String(f.dataset.filter===category)));views.forEach(f=>f.setAttribute('aria-pressed',String(f.dataset.view===view)));
  if(update){const q=new URLSearchParams();if(query)q.set('q',search.value.trim());if(stage.value!=='all')q.set('stage',stage.value);if(category!=='All projects')q.set('category',category);if(sort.value!=='visual')q.set('sort',sort.value);if(media.value!=='all')q.set('media',media.value);if(view!==defaultView)q.set('view',view);history.replaceState(null,'',location.pathname+(q.size?'?'+q:'')+location.hash);}
 }
 search.addEventListener('input',()=>filter());stage.addEventListener('change',()=>filter());sort.addEventListener('change',()=>filter());media.addEventListener('change',()=>filter());
 filters.forEach(f=>f.addEventListener('click',()=>{category=f.dataset.filter;filter();}));views.forEach(f=>f.addEventListener('click',()=>{view=f.dataset.view;filter();}));
 document.querySelector('#reset').addEventListener('click',()=>{search.value='';stage.value='all';media.value='all';category='All projects';filter();search.focus();});window.addEventListener('popstate',readURL);readURL();
})();

// Motion is an enhancement: content is visible without JS and can always be paused.
(() => {
  const root = document.documentElement;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  const hero = document.querySelector('.portfolio-intro');
  const cards = [...document.querySelectorAll('.showcase-card')];
  const button = document.querySelector('.motion-control');
  let paused = false;
  try { paused = localStorage.getItem('wl-motion') === 'paused'; } catch (_) {}
  let enabled = !paused && !reduced.matches;
  let pointerFrame = 0;
  let currentCard = null;
  let cardPosition = null;
  let heroPosition = null;

  const progress = document.createElement('div');
  progress.className = 'reading-progress';
  progress.setAttribute('aria-hidden', 'true');
  document.body.append(progress);

  const title = hero?.querySelector('h1');
  if (title) {
    title.setAttribute('aria-label', title.textContent.trim());
    const text = title.textContent;
    title.replaceChildren();
    [...text].forEach((character, index) => {
      const letter = document.createElement('span');
      letter.className = character === ' ' ? 'name-letter name-space' : 'name-letter';
      letter.textContent = character === ' ' ? '\u00a0' : character;
      letter.setAttribute('aria-hidden', 'true');
      letter.style.setProperty('--letter-index', index);
      title.append(letter);
    });
  }

  const targets = [...document.querySelectorAll('.showcase-card, .work-heading, .project-group-heading, .about-compact, .home-updates, .contact-compact, .update-card, .detail-image, .detail-body > section')];
  let observer;
  if ('IntersectionObserver' in window) {
    observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, {threshold: 0.08, rootMargin: '0px 0px -24px 0px'});
    targets.forEach((target, index) => {
      // Never conceal content already in view when the enhancement initializes.
      if (target.getBoundingClientRect().top < innerHeight - 24) return;
      target.classList.add('reveal-item');
      target.style.setProperty('--reveal-delay', `${Math.min(index % 3, 2) * 65}ms`);
      observer.observe(target);
    });
  }

  function resetPointer() {
    if (currentCard) {
      currentCard.classList.remove('pointer-active');
      ['--tilt-x', '--tilt-y', '--image-x', '--image-y'].forEach(name => currentCard.style.removeProperty(name));
    }
    currentCard = null;
    cardPosition = null;
    heroPosition = null;
    hero?.style.removeProperty('--hero-x');
    hero?.style.removeProperty('--hero-y');
  }

  function applyMotionPreference() {
    enabled = !paused && !reduced.matches;
    root.classList.toggle('motion-enabled', enabled);
    root.classList.toggle('motion-paused', !enabled);
    if (button) {
      button.hidden = false;
      button.disabled = reduced.matches;
      button.textContent = reduced.matches ? 'Reduced motion' : paused ? 'Resume motion' : 'Pause motion';
      button.setAttribute('aria-pressed', String(!enabled));
      button.title = reduced.matches ? 'Following your device’s reduced motion preference' : 'Control decorative animation';
    }
    if (!enabled) {
      resetPointer();
      cancelAnimationFrame(pointerFrame);
      pointerFrame = 0;
    }
  }

  function drawPointer() {
    pointerFrame = 0;
    if (!enabled || document.hidden || !finePointer.matches) return;
    if (currentCard && cardPosition) {
      currentCard.style.setProperty('--tilt-x', `${-cardPosition.y * 2.8}deg`);
      currentCard.style.setProperty('--tilt-y', `${cardPosition.x * 3.2}deg`);
      currentCard.style.setProperty('--image-x', `${cardPosition.x * 4}px`);
      currentCard.style.setProperty('--image-y', `${cardPosition.y * 3}px`);
    }
    if (heroPosition) {
      hero.style.setProperty('--hero-x', `${heroPosition.x * 6}px`);
      hero.style.setProperty('--hero-y', `${heroPosition.y * 3}px`);
    }
  }
  function queuePointer() {
    if (!pointerFrame) pointerFrame = requestAnimationFrame(drawPointer);
  }
  cards.forEach(card => {
    card.addEventListener('pointermove', event => {
      if (!enabled || !finePointer.matches) return;
      if (currentCard !== card) { resetPointer(); currentCard = card; }
      const box = card.getBoundingClientRect();
      cardPosition = {x: (event.clientX - box.left) / box.width - 0.5, y: (event.clientY - box.top) / box.height - 0.5};
      card.classList.add('pointer-active');
      queuePointer();
    });
    card.addEventListener('pointerleave', resetPointer);
    card.addEventListener('blur', resetPointer);
  });
  hero?.addEventListener('pointermove', event => {
    if (!enabled || !finePointer.matches) return;
    const box = hero.getBoundingClientRect();
    heroPosition = {x: (event.clientX - box.left) / box.width - 0.5, y: (event.clientY - box.top) / box.height - 0.5};
    queuePointer();
  });
  hero?.addEventListener('pointerleave', resetPointer);
  button?.addEventListener('click', () => {
    paused = !paused;
    try { localStorage.setItem('wl-motion', paused ? 'paused' : 'on'); } catch (_) {}
    applyMotionPreference();
  });
  reduced.addEventListener('change', applyMotionPreference);
  finePointer.addEventListener('change', resetPointer);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { resetPointer(); cancelAnimationFrame(pointerFrame); pointerFrame = 0; }
  });

  let scrollFrame = 0;
  function updateScroll() {
    scrollFrame = 0;
    const range = document.documentElement.scrollHeight - innerHeight;
    progress.style.transform = `scaleX(${range > 0 ? Math.min(1, scrollY / range) : 0})`;
    root.classList.toggle('page-scrolled', scrollY > 32);
  }
  addEventListener('scroll', () => {
    if (!scrollFrame) scrollFrame = requestAnimationFrame(updateScroll);
  }, {passive: true});
  addEventListener('resize', updateScroll, {passive: true});
  applyMotionPreference();
  updateScroll();
})();

(() => {
 const list=document.querySelector('#updates-list');if(!list)return;
 const cards=[...list.querySelectorAll('.update-card')],buttons=[...document.querySelectorAll('[data-update-filter]')],search=document.querySelector('#update-search');let type='All updates';
 function readURL(){const q=new URLSearchParams(location.search);type=buttons.some(b=>b.dataset.updateFilter===q.get('type'))?q.get('type'):'All updates';search.value=q.get('q')||'';filter(false);}
 function filter(update=true){let count=0;const term=search.value.trim().toLowerCase();cards.forEach(card=>{const show=(type==='All updates'||card.dataset.updateType===type)&&(!term||card.dataset.updateSearch.includes(term));card.hidden=!show;count+=Number(show);});buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.updateFilter===type)));document.querySelector('#update-count').textContent=`${count} ${count===1?'update':'updates'}`;document.querySelector('#updates-empty').hidden=count!==0;if(update){const q=new URLSearchParams();if(type!=='All updates')q.set('type',type);if(term)q.set('q',search.value.trim());history.replaceState(null,'',location.pathname+(q.size?'?'+q:''));}}
 buttons.forEach(b=>b.addEventListener('click',()=>{type=b.dataset.updateFilter;filter();}));search.addEventListener('input',()=>filter());document.querySelector('#updates-reset').addEventListener('click',()=>{type='All updates';search.value='';filter();search.focus();});window.addEventListener('popstate',readURL);readURL();
})();

// Persist the reader's preferred color theme.
(() => {
  const root = document.documentElement;
  const themeButton = document.querySelector('.theme-toggle');
  let savedTheme; try { savedTheme = localStorage.getItem('wl-theme'); } catch (_) {}
  function theme(value) {
    root.dataset.theme = value;
    if (themeButton) {
      themeButton.setAttribute('aria-pressed', String(value === 'light'));
      themeButton.setAttribute('aria-label', `Switch to ${value === 'light' ? 'dark' : 'light'} theme`);
    }
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', value === 'light' ? '#eeede8' : '#090909');
  }
  theme(savedTheme === 'light' ? 'light' : 'dark');
  themeButton?.addEventListener('click', () => {
    const value = root.dataset.theme === 'light' ? 'dark' : 'light';
    const apply=()=>theme(value);
    if(document.startViewTransition&&!matchMedia('(prefers-reduced-motion: reduce)').matches)document.startViewTransition(apply);else apply();
    try { localStorage.setItem('wl-theme', value); } catch (_) {}
    window.dispatchEvent(new Event('portfolio-theme'));
  });
})();

// Progressive enhancement: image links still open their full-size files without JS.
(() => {
 const links=[...document.querySelectorAll('.evidence-zoom')];if(!links.length)return;
 const dialog=document.createElement('dialog');dialog.className='media-dialog';dialog.setAttribute('aria-label','Project image viewer');
 dialog.innerHTML='<div class="media-dialog-toolbar"><span class="media-position" aria-live="polite"></span><button type="button" class="media-close" aria-label="Close image viewer">Close ×</button></div><div class="media-dialog-image"><img alt=""></div><p class="media-dialog-caption"></p><div class="media-dialog-nav"><button type="button" class="media-prev" aria-label="Previous image">← Previous</button><a class="media-original" target="_blank" rel="noopener noreferrer">Open full image ↗</a><button type="button" class="media-next" aria-label="Next image">Next →</button></div>';
 document.body.append(dialog);let current=0,opener;
 function show(index){current=(index+links.length)%links.length;const link=links[current],img=dialog.querySelector('img');img.src=link.href;img.alt=link.dataset.caption;dialog.querySelector('.media-dialog-caption').textContent=link.dataset.caption;dialog.querySelector('.media-position').textContent=`${current+1} / ${links.length}`;dialog.querySelector('.media-original').href=link.href;dialog.querySelector('.media-prev').disabled=links.length<2;dialog.querySelector('.media-next').disabled=links.length<2;}
 links.forEach((link,index)=>link.addEventListener('click',event=>{if(event.metaKey||event.ctrlKey||event.shiftKey||event.altKey)return;event.preventDefault();opener=link;show(index);dialog.showModal();document.body.classList.add('viewer-open');}));
 dialog.querySelector('.media-close').addEventListener('click',()=>dialog.close());dialog.querySelector('.media-prev').addEventListener('click',()=>show(current-1));dialog.querySelector('.media-next').addEventListener('click',()=>show(current+1));
 dialog.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();show(current+(event.key==='ArrowLeft'?-1:1));}});
 dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});dialog.addEventListener('close',()=>{document.body.classList.remove('viewer-open');opener?.focus();});
})();
// The channel is the source of truth. Keep the last reviewed upload as a fallback.
(() => {
 const broadcasts=[...document.querySelectorAll('[data-channel-broadcast]')];if(!broadcasts.length)return;
 const reduced=matchMedia('(prefers-reduced-motion: reduce)');
 const date=value=>new Date(value).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'});
 const safeEpisode=e=>e&&/^[\w-]{11}$/.test(e.id)&&typeof e.title==='string'&&Number.isFinite(Date.parse(e.published));
 let apiPromise;
 function youtube(){
  if(window.YT?.Player)return Promise.resolve(window.YT);
  if(!apiPromise)apiPromise=new Promise((resolve,reject)=>{
   const prior=window.onYouTubeIframeAPIReady;
   window.onYouTubeIframeAPIReady=()=>{prior?.();resolve(window.YT);};
   const script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';script.onerror=reject;document.head.append(script);
  });return apiPromise;
 }
 function updateStories(episodes){
  const grid=document.querySelector('.episode-grid');if(!grid)return;
  grid.replaceChildren(...episodes.map(e=>{
   const article=document.createElement('article');article.className='episode-card';
   const link=document.createElement('a');link.className='episode-poster';link.href=`https://www.youtube.com/watch?v=${e.id}`;link.target='_blank';link.rel='noopener noreferrer';
   const img=new Image();img.src=`https://i.ytimg.com/vi/${e.id}/hqdefault.jpg`;img.alt=e.title;img.width=480;img.height=360;img.loading='lazy';link.append(img);
   const meta=document.createElement('span');meta.className='eyebrow';meta.textContent=`${date(e.published)} / ${e.format}`;
   const h=document.createElement('h3'),titleLink=link.cloneNode(false);titleLink.className='';titleLink.textContent=e.title;h.append(titleLink);
   const watch=link.cloneNode(false);watch.className='text-link';watch.textContent='Watch on YouTube ↗';article.append(link,meta,h,watch);return article;
  }));
 }
 async function init(){
  let episodes=[],fresh=false;
  try{const response=await fetch('/api/channel',{signal:AbortSignal.timeout(6500)});if(!response.ok)throw new Error();const data=await response.json();episodes=(data.episodes||[]).filter(safeEpisode);fresh=data.status==='fresh';}catch{}
  if(episodes.length)updateStories(episodes);
  const note=document.querySelector('.episode-feed-note');if(note)note.textContent=fresh?'Recent uploads from my YouTube channel. Updated automatically.':'Last checked uploads. Visit YouTube for the current channel.';
  broadcasts.forEach(async shell=>{
   const ep=episodes[0];if(ep){shell.dataset.video=ep.id;shell.dataset.title=ep.title;shell.dataset.format=ep.format;shell.querySelector('.broadcast-title').textContent=ep.title;shell.querySelector('.broadcast-date').textContent=`${date(ep.published)} · ${ep.format}`;shell.querySelector('.broadcast-watch').href=`https://www.youtube.com/watch?v=${ep.id}`;const img=shell.querySelector('.broadcast-poster');img.src=`https://i.ytimg.com/vi/${ep.id}/hqdefault.jpg`;img.alt=ep.title;}
   shell.querySelector('.feed-state').textContent=fresh?'LATEST UPLOAD':'LAST CHECKED UPLOAD';
   const start=shell.querySelector('.broadcast-start'),play=shell.querySelector('.broadcast-play'),sound=shell.querySelector('.broadcast-sound');
   let player,ready=false,playing=false,manuallyPaused=false,visible=true,playRequested=false;
   play.disabled=true;sound.disabled=true;
   let motionPaused=false;try{motionPaused=localStorage.getItem('wl-motion')==='paused';}catch{}
   function playState(value){playing=value;play.textContent=value?'Pause':'Play';play.setAttribute('aria-label',value?'Pause video':'Play video');}
   const observer=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;if(!ready)return;if(!visible)player.pauseVideo();else if(!manuallyPaused&&!reduced.matches&&!document.hidden&&!motionPaused)player.playVideo();},{threshold:.25});observer.observe(shell);
   function userPlay(){manuallyPaused=false;playRequested=true;if(ready){if(player.getPlayerState()===YT.PlayerState.ENDED)player.seekTo(0,true);player.playVideo();}else start.textContent='Opening player…';}
   start.addEventListener('click',userPlay);
   play.addEventListener('click',()=>{if(!ready)return;if(playing){manuallyPaused=true;player.pauseVideo();}else userPlay();});
   sound.addEventListener('click',()=>{if(!ready)return;const enable=player.isMuted();enable?player.unMute():player.mute();sound.textContent=enable?'Sound on':'Sound off';sound.setAttribute('aria-pressed',String(enable));});
   const pause=()=>{if(ready)player.pauseVideo();};
   document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
   reduced.addEventListener('change',()=>{if(reduced.matches)pause();});
   document.querySelector('.motion-control')?.addEventListener('click',()=>{motionPaused=document.querySelector('.motion-control').getAttribute('aria-pressed')==='true';if(motionPaused)pause();});
   try{
    await youtube();
    const mount=shell.querySelector('.broadcast-mount');
    player=new YT.Player(mount,{host:'https://www.youtube-nocookie.com',videoId:shell.dataset.video,playerVars:{autoplay:0,playsinline:1,rel:0,origin:location.origin},events:{
     onReady:()=>{ready=true;play.disabled=false;sound.disabled=false;start.textContent="Play latest story ↗";const iframe=player.getIframe();iframe.title=shell.dataset.title;iframe.setAttribute('allow','autoplay; encrypted-media; picture-in-picture; fullscreen');iframe.setAttribute('referrerpolicy','strict-origin-when-cross-origin');player.mute();if(playRequested||(!reduced.matches&&!motionPaused&&visible&&!document.hidden))player.playVideo();},
     onStateChange:event=>{playState(event.data===YT.PlayerState.PLAYING);if(event.data===YT.PlayerState.PLAYING){shell.classList.add('video-started');start.hidden=true;}if(event.data===YT.PlayerState.ENDED){manuallyPaused=true;start.hidden=false;start.textContent='Replay story ↗';}},
     onAutoplayBlocked:()=>{start.hidden=false;start.textContent='Play latest story ↗';},
     onError:()=>{start.hidden=true;play.disabled=true;sound.disabled=true;shell.querySelector('.feed-state').textContent='WATCH ON YOUTUBE';}
    }});
   }catch{start.hidden=true;play.disabled=true;sound.disabled=true;shell.querySelector('.feed-state').textContent='WATCH ON YOUTUBE';}
  });
 }
 init();
})();
