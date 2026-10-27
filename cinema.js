// Lightweight motion; no render loop while idle, hidden, or outside the viewport.
(() => {
 const room=document.querySelector('.workroom');if(!room)return;
 const root=document.documentElement,stage=room.querySelector('.workroom-stage');
 const panels=[...room.querySelectorAll('[data-studio-panel]')],choices=[...room.querySelectorAll('[data-studio-select]')];
 const controls=room.querySelector('.studio-switcher'),description=room.querySelector('.studio-description');
 const reduced=matchMedia('(prefers-reduced-motion: reduce)'),pointer=matchMedia('(hover:hover) and (pointer:fine)');
 let current=0,timer=0,inView=false,hovered=false;
 const motion=()=>root.classList.contains('motion-enabled')&&!reduced.matches&&!document.hidden;
 function restart(){
  clearTimeout(timer);timer=0;room.classList.remove('gallery-running');
  const focused=stage.contains(document.activeElement)||controls.contains(document.activeElement)||description.contains(document.activeElement);
  if(!motion()||!inView||hovered||focused)return;
  // Restart the visible progress line along with the actual timer.
  requestAnimationFrame(()=>{if(timer)room.classList.add('gallery-running');});
  timer=setTimeout(()=>select(current+1,true),9000);
 }
 function select(index,automatic=false){
  current=(index+panels.length)%panels.length;
  description.setAttribute('aria-live',automatic?'off':'polite');
  panels.forEach((panel,i)=>{const front=i===current,next=i===(current+1)%panels.length;panel.classList.toggle('is-front',front);panel.classList.toggle('is-next',next);panel.classList.toggle('is-away',!front&&!next);panel.inert=!front&&!next;panel.setAttribute('aria-hidden',String(!front&&!next));});
  const panel=panels[current];
  room.querySelector('[data-studio-name]').textContent=panel.dataset.name;
  room.querySelector('[data-studio-category]').textContent=panel.dataset.category;
  room.querySelector('[data-studio-role]').textContent=panel.dataset.role;
  room.querySelector('[data-studio-count]').textContent=`${String(current+1).padStart(2,'0')} / ${String(panels.length).padStart(2,'0')}`;
  room.querySelector('[data-studio-link]').href=panel.href;
  choices.forEach((button,i)=>button.setAttribute('aria-pressed',String(i===current)));
  restart();
 }
 choices.forEach((button,i)=>button.addEventListener('click',()=>select(i)));
 room.querySelector('[data-studio-prev]').addEventListener('click',()=>select(current-1));
 room.querySelector('[data-studio-next]').addEventListener('click',()=>select(current+1));controls.hidden=false;
 controls.addEventListener('keydown',event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();select(event.key==='Home'?0:event.key==='End'?panels.length-1:current+(event.key==='ArrowLeft'?-1:1));choices[current].focus();});
 new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;restart();},{threshold:.2}).observe(stage);
 for(const area of [stage,controls,description]){
  area.addEventListener('pointerenter',()=>{hovered=true;restart();});area.addEventListener('pointerleave',()=>{hovered=false;restart();});
  area.addEventListener('focusin',restart);area.addEventListener('focusout',()=>setTimeout(restart,0));
 }
 let frame=0,position=null;
 function reset(){position=null;cancelAnimationFrame(frame);frame=0;stage.style.removeProperty('--studio-x');stage.style.removeProperty('--studio-y');}
 stage.addEventListener('pointermove',event=>{if(!pointer.matches||!motion())return;const box=stage.getBoundingClientRect();position={x:(event.clientX-box.left)/box.width-.5,y:(event.clientY-box.top)/box.height-.5};if(!frame)frame=requestAnimationFrame(()=>{frame=0;if(!position)return;stage.style.setProperty('--studio-x',`${position.x*22}px`);stage.style.setProperty('--studio-y',`${position.y*14}px`);});});
 stage.addEventListener('pointerleave',reset);
 const scenes=[...document.querySelectorAll('.case-scene')],visibleScenes=new Set();let scrollFrame=0;
 function paint(){scrollFrame=0;if(!motion())return;visibleScenes.forEach(scene=>{const box=scene.getBoundingClientRect(),progress=Math.max(-1,Math.min(1,(innerHeight/2-box.top-box.height/2)/(innerHeight/2+box.height/2)));scene.style.setProperty('--scene-shift',`${progress*36}px`);scene.style.setProperty('--heading-shift',`${-progress*22}px`);});}
 function schedule(){if(!scrollFrame&&motion())scrollFrame=requestAnimationFrame(paint);}
 const sceneObserver=new IntersectionObserver(entries=>{entries.forEach(entry=>entry.isIntersecting?visibleScenes.add(entry.target):visibleScenes.delete(entry.target));schedule();});scenes.forEach(scene=>sceneObserver.observe(scene));
 window.addEventListener('scroll',schedule,{passive:true});window.addEventListener('resize',schedule,{passive:true});
 function sync(){reset();restart();if(!motion()){cancelAnimationFrame(scrollFrame);scrollFrame=0;scenes.forEach(scene=>{scene.style.removeProperty('--scene-shift');scene.style.removeProperty('--heading-shift');});}else schedule();}
 new MutationObserver(sync).observe(root,{attributes:true,attributeFilter:['class']});document.addEventListener('visibilitychange',sync);reduced.addEventListener('change',sync);
 select(0);
})();
