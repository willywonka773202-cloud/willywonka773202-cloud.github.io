(() => {
 const search=document.querySelector('#search'),stage=document.querySelector('#stage'),sort=document.querySelector('#sort'),list=document.querySelector('#project-list');
 if(!search||!stage||!list)return;
 const rows=[...list.querySelectorAll('.project-row')],filters=[...document.querySelectorAll('[data-filter]')],views=[...document.querySelectorAll('[data-view]')];
 let category='All projects',view='grid';
 function readURL(){const q=new URLSearchParams(location.search);search.value=q.get('q')||'';stage.value=[...stage.options].some(o=>o.value===q.get('stage'))?q.get('stage'):'all';category=filters.some(f=>f.dataset.filter===q.get('category'))?q.get('category'):'All projects';sort.value=q.get('sort')==='name'?'name':'recent';view=q.get('view')==='list'?'list':'grid';filter(false);}
 function filter(update=true){
  const query=search.value.trim().toLowerCase();let visible=0;
  rows.sort((a,b)=>sort.value==='name'?a.dataset.name.localeCompare(b.dataset.name):b.dataset.updated.localeCompare(a.dataset.updated)||a.dataset.name.localeCompare(b.dataset.name));
  rows.forEach((row,index)=>{row.querySelector('.row-number').textContent=String(index+1).padStart(2,'0');list.append(row);const show=(!query||row.dataset.search.includes(query))&&(category==='All projects'||row.dataset.category===category)&&(stage.value==='all'||row.dataset.stage===stage.value);row.hidden=!show;visible+=Number(show);});
  document.querySelector('#result-count').textContent=`${visible} ${visible===1?'project':'projects'}${visible!==rows.length?` of ${rows.length}`:''}`;
  document.querySelector('#empty').hidden=visible!==0;list.classList.toggle('project-grid',view==='grid');
  filters.forEach(f=>f.setAttribute('aria-pressed',String(f.dataset.filter===category)));views.forEach(f=>f.setAttribute('aria-pressed',String(f.dataset.view===view)));
  if(update){const q=new URLSearchParams();if(query)q.set('q',search.value.trim());if(stage.value!=='all')q.set('stage',stage.value);if(category!=='All projects')q.set('category',category);if(sort.value!=='recent')q.set('sort',sort.value);if(view!=='grid')q.set('view',view);history.replaceState(null,'',location.pathname+(q.size?'?'+q:'')+location.hash);}
 }
 search.addEventListener('input',()=>filter());stage.addEventListener('change',()=>filter());sort.addEventListener('change',()=>filter());
 filters.forEach(f=>f.addEventListener('click',()=>{category=f.dataset.filter;filter();}));views.forEach(f=>f.addEventListener('click',()=>{view=f.dataset.view;filter();}));
 document.querySelector('#reset').addEventListener('click',()=>{search.value='';stage.value='all';category='All projects';filter();search.focus();});window.addEventListener('popstate',readURL);readURL();
})();

(() => {
 const list=document.querySelector('#updates-list');if(!list)return;
 const cards=[...list.querySelectorAll('.update-card')],buttons=[...document.querySelectorAll('[data-update-filter]')],search=document.querySelector('#update-search');let type='All updates';
 function readURL(){const q=new URLSearchParams(location.search);type=buttons.some(b=>b.dataset.updateFilter===q.get('type'))?q.get('type'):'All updates';search.value=q.get('q')||'';filter(false);}
 function filter(update=true){let count=0;const term=search.value.trim().toLowerCase();cards.forEach(card=>{const show=(type==='All updates'||card.dataset.updateType===type)&&(!term||card.dataset.updateSearch.includes(term));card.hidden=!show;count+=Number(show);});buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.updateFilter===type)));document.querySelector('#update-count').textContent=`${count} ${count===1?'update':'updates'}`;document.querySelector('#updates-empty').hidden=count!==0;if(update){const q=new URLSearchParams();if(type!=='All updates')q.set('type',type);if(term)q.set('q',search.value.trim());history.replaceState(null,'',location.pathname+(q.size?'?'+q:''));}}
 buttons.forEach(b=>b.addEventListener('click',()=>{type=b.dataset.updateFilter;filter();}));search.addEventListener('input',()=>filter());document.querySelector('#updates-reset').addEventListener('click',()=>{type='All updates';search.value='';filter();search.focus();});window.addEventListener('popstate',readURL);readURL();
})();

// A small, dependency-free layer for theme, motion, and the spatial gallery.
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
    theme(value); try { localStorage.setItem('wl-theme', value); } catch (_) {}
    window.dispatchEvent(new Event('portfolio-theme'));
  });
  const cards = [...document.querySelectorAll('.gallery-card')];
  const stage = document.querySelector('.gallery-stage');
  if (cards.length && stage) {
    let current = 0, startX = 0, startY = 0;
    function render() {
      const mobile = innerWidth < 700;
      cards.forEach((card, index) => {
        let offset = (index - current + cards.length) % cards.length;
        if (offset > cards.length / 2) offset -= cards.length;
        const distance = Math.abs(offset);
        const x = offset * (mobile ? 180 : 285);
        const z = -distance * (mobile ? 180 : 230);
        card.style.transform = `translateX(${x}px) translateZ(${z}px) rotateY(${offset * -18}deg) rotateZ(${offset * 1.8}deg)`;
        card.style.opacity = distance > 2 ? '0' : '1';
        card.style.pointerEvents = distance > 2 ? 'none' : 'auto';
        card.style.zIndex = String(10 - distance);
        card.classList.toggle('is-current', offset === 0);
        card.tabIndex = offset === 0 ? 0 : -1;
        card.setAttribute('aria-hidden', String(offset !== 0));
      });
      document.querySelector('#gallery-counter').textContent = `${String(current + 1).padStart(2, '0')} / ${String(cards.length).padStart(2, '0')}`;
      document.querySelector('#gallery-name').textContent = cards[current].dataset.name;
    }
    function move(direction) { current = (current + direction + cards.length) % cards.length; render(); }
    document.querySelector('#gallery-prev').addEventListener('click', () => move(-1));
    document.querySelector('#gallery-next').addEventListener('click', () => move(1));
    stage.addEventListener('keydown', event => { if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') { event.preventDefault(); move(event.key === 'ArrowRight' ? 1 : -1); } });
    stage.addEventListener('pointerdown', event => { startX = event.clientX; startY = event.clientY; });
    let swiped = false;
    stage.addEventListener('pointerup', event => { const dx = event.clientX - startX; const dy = event.clientY - startY; swiped = Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy); if (swiped) move(dx < 0 ? 1 : -1); });
    stage.addEventListener('click', event => { if (swiped) { event.preventDefault(); swiped = false; return; } const card = event.target.closest('.gallery-card'); if (card && !card.classList.contains('is-current')) { event.preventDefault(); current = cards.indexOf(card); render(); } });
    window.addEventListener('resize', render, { passive: true });
    render();
  }
  const canvas = document.querySelector('#wireframe');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const motionButton = document.querySelector('#motion-toggle');
  const preference = matchMedia('(prefers-reduced-motion: reduce)');
  let paused = preference.matches, visible = true, frame = 0, width = 0, height = 0, time = 0, last = 0;
  let pointerX = 0, pointerY = 0, targetX = 0, targetY = 0;
  // An original animated topographic surface, projected into perspective.
  function surface(x, z, t) {
    const ridge = Math.exp(-Math.pow(x * .34 + Math.sin(z * .18 + t * .18) * .9, 2));
    return ridge * 2.7 + Math.sin(x * .52 + z * .26 + t * .3) * .85 + Math.cos(z * .4 - x * .21 + t * .16) * .55;
  }
  function draw(t) {
    ctx.clearRect(0, 0, width, height);
    const light = root.dataset.theme === 'light';
    const ink = light ? '38,38,33' : '197,200,183';
    const scale = Math.max(width, 800) * .071;
    const project = (x, z) => {
      const y = surface(x, z, t);
      const perspective = 16 / (z + 25);
      return [width * .5 + (x + pointerX * .6) * scale * perspective, height * .29 + (z * .37 - y * 1.4 + pointerY * .3) * scale * perspective];
    };
    const line = (points, alpha) => {
      ctx.beginPath(); points.forEach(([x,y],i) => i ? ctx.lineTo(x,y) : ctx.moveTo(x,y));
      ctx.strokeStyle = `rgba(${ink},${alpha})`; ctx.lineWidth = .65; ctx.stroke();
    };
    for (let z = -7; z <= 24; z += .58) {
      const points = [];
      for (let x = -23; x <= 23; x += .38) points.push(project(x,z));
      line(points, .12 + .12 * (1 - (z + 7) / 31));
    }
    for (let x = -23; x <= 23; x += .58) {
      const points = [];
      for (let z = -7; z <= 24; z += .38) points.push(project(x,z));
      line(points,.19);
    }
  }
  function tick(now) {
    frame = 0;
    if (paused || !visible || document.hidden) return;
    if (now - last >= 32) { time += Math.min(now-last, 64) / 1000; last = now; pointerX += (targetX - pointerX) * .06; pointerY += (targetY - pointerY) * .06; draw(time); }
    frame = requestAnimationFrame(tick);
  }
  function start() { if (!frame && !paused && visible && !document.hidden) { last = performance.now(); frame = requestAnimationFrame(tick); } }
  function stop() { cancelAnimationFrame(frame); frame = 0; }
  function motionState() { document.body.classList.toggle('motion-paused', paused); motionButton.textContent = paused ? 'Play motion' : 'Pause motion'; motionButton.setAttribute('aria-pressed', String(paused)); paused ? stop() : start(); }
  function resize() { const box = canvas.getBoundingClientRect(); width = box.width; height = box.height; const ratio = Math.min(devicePixelRatio || 1, 1.5); canvas.width = width * ratio; canvas.height = height * ratio; ctx.setTransform(ratio,0,0,ratio,0,0); draw(time); }
  motionButton.addEventListener('click', () => { paused = !paused; motionState(); });
  preference.addEventListener('change', () => { paused = preference.matches; motionState(); });
  canvas.parentElement.addEventListener('pointermove', event => { const rect = canvas.getBoundingClientRect(); targetX = (event.clientX - rect.left)/width - .5; targetY = (event.clientY - rect.top)/height - .5; },{passive:true});
  canvas.parentElement.addEventListener('pointerleave', () => { targetX = 0; targetY = 0; });
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; visible ? start() : stop(); }).observe(canvas);
  document.addEventListener('visibilitychange', () => document.hidden ? stop() : start());
  window.addEventListener('resize', resize, {passive:true});
  window.addEventListener('portfolio-theme', () => draw(time));
  resize(); motionState();
})();
