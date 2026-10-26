// Featured work: manual selection only, with a complete archive always available.
(() => {
 const room=document.querySelector('.workroom');if(!room)return;
 const stage=room.querySelector('.workroom-stage');
 const panels=[...room.querySelectorAll('[data-studio-panel]')];
 const choices=[...room.querySelectorAll('[data-studio-select]')];
 let current=0;
 function select(index){
  current=(index+panels.length)%panels.length;
  panels.forEach((panel,i)=>{const front=i===current,next=i===(current+1)%panels.length;panel.classList.toggle('is-front',front);panel.classList.toggle('is-next',next);panel.classList.toggle('is-away',!front&&!next);panel.inert=!front&&!next;panel.setAttribute('aria-hidden',String(!front&&!next));});
  const panel=panels[current];
  room.querySelector('[data-studio-name]').textContent=panel.dataset.name;
  room.querySelector('[data-studio-category]').textContent=panel.dataset.category;
  room.querySelector('[data-studio-role]').textContent=panel.dataset.role;
  room.querySelector('[data-studio-count]').textContent=`${String(current+1).padStart(2,'0')} / ${String(panels.length).padStart(2,'0')}`;
  room.querySelector('[data-studio-link]').href=panel.href;
  choices.forEach((button,i)=>button.setAttribute('aria-pressed',String(i===current)));
 }
 choices.forEach((button,i)=>button.addEventListener('click',()=>select(i)));
 room.querySelector('[data-studio-prev]').addEventListener('click',()=>select(current-1));
 room.querySelector('[data-studio-next]').addEventListener('click',()=>select(current+1));
 room.querySelector('.studio-switcher').hidden=false;
 room.querySelector('.studio-switcher').addEventListener('keydown',event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();select(event.key==='Home'?0:event.key==='End'?panels.length-1:current+(event.key==='ArrowLeft'?-1:1));choices[current].focus();});
 const pointer=matchMedia('(hover:hover) and (pointer:fine)');
 let frame=0,position=null;
 function reset(){position=null;cancelAnimationFrame(frame);frame=0;stage.style.removeProperty('--studio-x');stage.style.removeProperty('--studio-y');}
 stage.addEventListener('pointermove',event=>{if(!pointer.matches||!document.documentElement.classList.contains('motion-enabled'))return;const box=stage.getBoundingClientRect();position={x:(event.clientX-box.left)/box.width-.5,y:(event.clientY-box.top)/box.height-.5};if(!frame)frame=requestAnimationFrame(()=>{frame=0;if(!position)return;stage.style.setProperty('--studio-x',`${position.x*9}px`);stage.style.setProperty('--studio-y',`${position.y*6}px`);});});
 stage.addEventListener('pointerleave',reset);document.addEventListener('visibilitychange',reset);room.querySelector('.motion-control')?.addEventListener('click',reset);
 select(0);
})();
