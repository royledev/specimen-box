/* ============================================================
   標本箱 — prototype interactions
   ============================================================ */
'use strict';

/* ---------- scene captions (shown in the rail) ---------- */
const CAPTIONS = {
  boot:  '不満③ 起動演出。土の欠片が集まり「標本箱」がポンッと弾む。地層ラインが描かれる（日常を発掘する世界の入り口）。',
  onboard:'追加：生年月日の選択画面。誕生日に特別な標本が掘れる。ホイールで年／月／日を選ぶ。',
  home:  '不満①⑤⑥ 直近1週間を日付ごとに。1日3回通知＝最大3標本を3スロットで表示（未回答は空の発掘穴）。他の日は右上▦／下部ボタンのカレンダーから選択（色玉＝その日の発掘数）。',
  reveal:'不満④ 発掘演出。地中から標本が掘り出され、土ぼこりが舞う。レア度に比例して演出が大きく。左で ★1／★3／★5／誕生日／深夜 を切替。',
  detail:'不満④ 詳細。発掘記録風メタ、レアを主役級バッジに。風化メーターと封印導線。',
  seal:  '不満⑤ 封印の再設計。金枠＋鍵をやめ、琥珀の結晶に封じ込める演出。下のボタンで再生。',
};

/* ---------- specimen dataset ---------- */
// 1日3回通知 → 1日あたり最大3標本。t=発掘時刻。rarity stars 1-5 / special 'birthday'|'midnight'|null / weather 0..1 / sealed
const SPECIMENS = [
  // 2026-06-14 (今日) — 3つ揃い
  {h:265,date:'2026-06-14',t:'02:47',stars:5,special:'midnight',weather:0.18,sealed:false,a:'天井のシミを20分見た',q:'今日、いちばん無駄だったことは？'},
  {h:48, date:'2026-06-14',t:'08:12',stars:2,special:null,weather:0.05,sealed:false,a:'コーヒーをこぼした',q:'今朝いちばん最初に触ったものは？'},
  {h:150,date:'2026-06-14',t:'13:40',stars:3,special:null,weather:0.10,sealed:false,a:'鳩を3羽かぞえた',q:'今日すれ違った生き物は？'},
  // 2026-06-13 — 2つ（1つ未発掘）
  {h:18, date:'2026-06-13',t:'09:05',stars:1,special:null,weather:0.22,sealed:false,a:'靴下の毛玉',q:'今いちばん近くにある布は？'},
  {h:320,date:'2026-06-13',t:'19:30',stars:4,special:null,weather:0.0, sealed:true, a:'まばたきの音',q:'今日きいた小さな音は？'},
  // 2026-06-12 — 3つ揃い
  {h:200,date:'2026-06-12',t:'08:40',stars:1,special:null,weather:0.30,sealed:false,a:'みかん',q:'いま見えている丸いものは？'},
  {h:95, date:'2026-06-12',t:'12:15',stars:2,special:null,weather:0.34,sealed:false,a:'冷蔵庫のブーン',q:'部屋でいちばん低い音は？'},
  {h:280,date:'2026-06-12',t:'22:50',stars:3,special:null,weather:0.0, sealed:true, a:'コンビニのレシート',q:'手の届く範囲で一番安いものは？'},
  // 2026-06-11 — なし（丸ごと未発掘）
  // 2026-06-10 — 1つ
  {h:130,date:'2026-06-10',t:'15:20',stars:2,special:null,weather:0.40,sealed:false,a:'階段13段',q:'今日かぞえたものは？'},
  // 2026-06-09 — 3つ揃い
  {h:175,date:'2026-06-09',t:'07:55',stars:1,special:null,weather:0.45,sealed:false,a:'同じ曲を7回',q:'今日くり返したことは？'},
  {h:235,date:'2026-06-09',t:'14:10',stars:2,special:null,weather:0.50,sealed:false,a:'消しゴムの角',q:'なくなりかけているものは？'},
  {h:60, date:'2026-06-09',t:'23:05',stars:4,special:null,weather:0.52,sealed:false,a:'冷たい床',q:'今日いちばん長く触れていたものは？'},
  // 2026-06-08 — 2つ
  {h:340,date:'2026-06-08',t:'10:30',stars:3,special:null,weather:0.60,sealed:false,a:'郵便受けを2回見た',q:'意味もなく開けたものは？'},
  {h:20, date:'2026-06-08',t:'21:00',stars:1,special:null,weather:0.62,sealed:false,a:'天井の蛍光灯',q:'今日見上げたものは？'},
  // ── 以下はカレンダー／総数用（当月の他の発掘日 + 過去月） ──
  {h:110,date:'2026-06-06',t:'12:00',stars:4,special:null,weather:0.0, sealed:true, a:'雪の予報だけ',q:'今日の天気は？'},
  {h:300,date:'2026-06-03',t:'18:20',stars:2,special:null,weather:0.7, sealed:false,a:'消えかけの付箋',q:'はがれかけているものは？'},
  {h:8,  date:'2026-06-01',t:'07:30',stars:1,special:null,weather:0.8, sealed:false,a:'寝癖',q:'今朝の自分の変なところは？'},
  {h:280,date:'2026-05-21',t:'00:10',stars:5,special:'birthday',weather:0.0,sealed:true,a:'自分におめでとう',q:'今日だれかに言った言葉は？'},
  {h:130,date:'2026-05-14',t:'14:00',stars:1,special:null,weather:0.42,sealed:false,a:'靴下の毛玉',q:'今いちばん近くにある布は？'},
];

/* ---------- shared earthy-pop palette (coral/amber/mustard/moss/sand/clay) ---------- */
const POP = ['234,106,69','240,151,58','242,194,76','91,166,126','224,162,78','199,91,89'];
const popRGB = () => POP[(Math.random()*POP.length)|0];

/* ============================================================
   Floating bubbles (bright background ambiance)
   ============================================================ */
const sky = document.getElementById('sky');
const sctx = sky.getContext('2d');
let bubbles = [], W = 0, H = 0, parY = 0;
function sizeSky(){
  const r = sky.getBoundingClientRect();
  W = sky.width = r.width * devicePixelRatio;
  H = sky.height = r.height * devicePixelRatio;
  const n = Math.round((r.width*r.height)/12000);
  bubbles = Array.from({length:n}, () => ({
    x:Math.random()*W, y:Math.random()*H,
    r:(Math.random()*8+2.5)*devicePixelRatio,
    a:Math.random()*0.06+0.03, sway:Math.random()*Math.PI*2,
    sp:Math.random()*0.0009+0.0003, dr:(Math.random()*0.08+0.03)*devicePixelRatio,
    rgb:popRGB(),
  }));
}
function drawSky(t){
  sctx.clearRect(0,0,W,H);
  for(const b of bubbles){
    const x = b.x + Math.sin(t*b.sp + b.sway)*10*devicePixelRatio;
    const y = b.y - parY*devicePixelRatio*0.4;
    const g = sctx.createRadialGradient(x, y, 0, x, y, b.r);
    g.addColorStop(0, `rgba(${b.rgb},${b.a*1.4})`);
    g.addColorStop(0.7, `rgba(${b.rgb},${b.a})`);
    g.addColorStop(1, `rgba(${b.rgb},0)`);
    sctx.beginPath(); sctx.arc(x, y, b.r, 0, 7);
    sctx.fillStyle = g; sctx.fill();
    b.y -= b.dr;
    if(b.y < -30) { b.y = H + 30; b.x = Math.random()*W; b.rgb = popRGB(); }
  }
  requestAnimationFrame(drawSky);
}
sizeSky();
addEventListener('resize', sizeSky);
requestAnimationFrame(drawSky);

/* ============================================================
   Scene switching
   ============================================================ */
const scenes = [...document.querySelectorAll('.scene')];
const navBtns = [...document.querySelectorAll('#sceneNav .rail-btn')];
const caption = document.getElementById('caption');
const foot = document.getElementById('deviceFoot');
const rarityPicker = document.getElementById('rarityPicker');
let current = 'boot';

function go(name){
  current = name;
  scenes.forEach(s => s.classList.toggle('active', s.dataset.scene === name));
  navBtns.forEach(b => b.classList.toggle('active', b.dataset.go === name));
  caption.textContent = CAPTIONS[name] || '';
  foot.textContent = '標本箱 · ' + ({boot:'起動',onboard:'生年月日',home:'標本一覧',reveal:'標本の発掘',detail:'発掘記録',seal:'封印の儀式'}[name]);
  rarityPicker.hidden = (name !== 'reveal');
  onEnter(name);
}
function onEnter(name){
  if(name === 'boot') playBoot();
  if(name === 'home') buildHome();
  if(name === 'reveal') playReveal(currentRarity);
  if(name === 'seal') resetSeal();
}

document.body.addEventListener('click', e => {
  const t = e.target.closest('[data-go]');
  if(t){ go(t.dataset.go); }
});
document.getElementById('replayBtn').addEventListener('click', () => onEnter(current));

/* font toggle */
document.getElementById('fontSeg').addEventListener('click', e => {
  const b = e.target.closest('.seg-btn'); if(!b) return;
  document.querySelectorAll('#fontSeg .seg-btn').forEach(x=>x.classList.toggle('active', x===b));
  document.documentElement.classList.toggle('font-round', b.dataset.font==='round');
  document.documentElement.classList.toggle('font-sans', b.dataset.font==='sans');
});

/* ============================================================
   01 BOOT
   ============================================================ */
const bootScene = document.querySelector('[data-scene="boot"] .boot');
const bootParticles = document.getElementById('bootParticles');
function playBoot(){
  bootScene.classList.remove('play');
  bootParticles.innerHTML = '';
  // converging particles toward the title
  for(let i=0;i<46;i++){
    const p = document.createElement('i');
    const ang = Math.random()*Math.PI*2, dist = 120+Math.random()*180;
    const sx = Math.cos(ang)*dist, sy = Math.sin(ang)*dist;
    p.style.left = '50%'; p.style.top = '46%';
    p.style.background = `rgb(${popRGB()})`;
    p.style.transform = `translate(${sx}px,${sy}px) rotate(${Math.random()*180}deg)`;
    p.style.transition = `transform 1.2s cubic-bezier(.16,1,.3,1) ${0.1+Math.random()*0.5}s, opacity .8s`;
    bootParticles.appendChild(p);
    requestAnimationFrame(()=>{ p.style.opacity = '.9'; p.style.transform = `translate(${sx*0.06}px,${sy*0.06}px)`; });
    setTimeout(()=>{ p.style.opacity = '0'; }, 1500+Math.random()*500);
  }
  void bootScene.offsetWidth;
  bootScene.classList.add('play');
}

/* ============================================================
   02 HOME — recent week (by date) + calendar
   ============================================================ */
const homeCount = document.getElementById('homeCount');
const homeScroll = document.getElementById('homeScroll');
const weekList = document.getElementById('weekList');
const WD = ['日','月','火','水','木','金','土'];
const TODAY = {y:2026, m:6, d:14};                 // currentDate = 2026-06-14
const pad2 = n => String(n).padStart(2,'0');
const dateKey = (y,m,d) => `${y}-${pad2(m)}-${pad2(d)}`;
const SLOTS = 3;                                    // 1日3回通知 → 最大3標本
// 日付ごとにグルーピングし、各日を発掘時刻 t の昇順に並べる
const byDate = {};
for(const s of SPECIMENS){ (byDate[s.date] ??= []).push(s); }
for(const k in byDate){ byDate[k].sort((a,b)=>a.t.localeCompare(b.t)); }

function slotHTML(s){
  if(!s) return `<div class="slot empty"><div class="orb-wrap"><div class="pit"></div></div><span class="slot-time">—</span></div>`;
  const cls = ['orb', s.sealed?'sealed':'', (!s.sealed && s.weather>0)?'weather':''].filter(Boolean).join(' ');
  const tag = s.special==='birthday' ? '🎂' : s.special==='midnight' ? '🌙' : '';
  return `<div class="slot" data-go="detail">
      <div class="orb-wrap">
        <div class="${cls}" style="--h:${s.h};--w:${s.weather}"></div>
        ${tag?`<span class="cell-tag">${tag}</span>`:''}
      </div>
      <span class="slot-time">${s.t}</span>
    </div>`;
}

function buildHome(){
  homeCount.textContent = String(SPECIMENS.length).padStart(3,'0');
  weekList.innerHTML = '';
  // last 7 days, newest first
  for(let i=0;i<7;i++){
    const dt = new Date(TODAY.y, TODAY.m-1, TODAY.d - i);
    const y=dt.getFullYear(), m=dt.getMonth()+1, d=dt.getDate();
    const wd = WD[dt.getDay()];
    const arr = byDate[dateKey(y,m,d)] || [];
    const row = document.createElement('div');
    row.className = 'day-row' + (arr.length ? '' : ' empty');
    row.style.animationDelay = (i*0.05)+'s';
    let slots = '';
    for(let k=0;k<SLOTS;k++) slots += slotHTML(arr[k]);
    row.innerHTML = `
      <div class="day-date"><b>${d}</b><small>${wd}</small>
        <span class="day-count">${arr.length}/${SLOTS}</span></div>
      <div class="day-haul">${slots}</div>`;
    weekList.appendChild(row);
  }
}
/* parallax */
homeScroll.addEventListener('scroll', ()=>{ parY = homeScroll.scrollTop*0.12; });

/* ---------- calendar overlay ---------- */
const cal = document.getElementById('cal');
const calGrid = document.getElementById('calGrid');
function buildCalendar(){
  calGrid.innerHTML = '';
  const first = new Date(TODAY.y, TODAY.m-1, 1).getDay();   // weekday of the 1st
  const days = new Date(TODAY.y, TODAY.m, 0).getDate();      // days in month
  for(let i=0;i<first;i++){
    const b = document.createElement('div'); b.className = 'cal-day blank'; calGrid.appendChild(b);
  }
  for(let d=1; d<=days; d++){
    const arr = byDate[dateKey(TODAY.y, TODAY.m, d)] || [];
    const cell = document.createElement('div');
    const isToday = d===TODAY.d;
    cell.className = 'cal-day' + (arr.length?' has':'') + (isToday?' today':'');
    if(arr.length){ cell.dataset.go = 'detail';
      // up to 3 colored dots = その日の発掘数
      const dots = arr.slice(0,SLOTS).map(s=>`<i class="dot" style="--h:${s.h}"></i>`).join('');
      cell.innerHTML = `<span>${d}</span><div class="dots">${dots}</div>`;
    } else {
      cell.innerHTML = `<span>${d}</span><i class="pip"></i>`;
    }
    calGrid.appendChild(cell);
  }
}
function openCal(){ buildCalendar(); cal.classList.add('show'); }
function closeCal(){ cal.classList.remove('show'); }
document.getElementById('calBtn').addEventListener('click', openCal);
document.getElementById('calCta').addEventListener('click', openCal);
document.getElementById('calClose').addEventListener('click', closeCal);
cal.addEventListener('click', e => { if(e.target===cal) closeCal(); });
// picking a date with a specimen closes the calendar before navigating
calGrid.addEventListener('click', e => { if(e.target.closest('.cal-day.has')) closeCal(); });

/* ============================================================
   03 REVEAL — rarity-scaled
   ============================================================ */
const RARITY = {
  s1:{stars:1,special:null,h:120,badge:null,cls:'第 I 類 — 通常',color:'cyan',rings:1,parts:8,rays:false,flash:0},
  s3:{stars:3,special:null,h:150,badge:null,cls:'第 III 類 — 希少',color:'cyan',rings:2,parts:24,rays:false,flash:0.3},
  s5:{stars:5,special:null,h:265,badge:'極稀の標本',cls:'第 V 類 — 極稀',color:'gold',rings:4,parts:80,rays:true,flash:0.9},
  birthday:{stars:5,special:'birthday',h:280,badge:'誕生日の標本',cls:'年に一度の標本',color:'gold',rings:3,parts:70,rays:true,flash:0.8},
  midnight:{stars:4,special:'midnight',h:265,badge:'深夜の標本',cls:'真夜中の標本',color:'violet',rings:3,parts:50,rays:false,flash:0.5},
};
let currentRarity = 's5';
const reveal = document.getElementById('reveal');
const revealOrb = document.getElementById('revealOrb');
const revealStars = document.getElementById('revealStars');
const revealClass = document.getElementById('revealClass');
const revealBadge = document.getElementById('revealBadge');
const revealFrame = document.getElementById('revealFrame');
const revealRings = document.getElementById('revealRings');
const revealBurst = document.getElementById('revealBurst');
const revealRays = document.getElementById('revealRays');
const revealFlash = document.getElementById('revealFlash');
const COLORMAP = {cyan:'#5BA67E',violet:'#6E7CA0',gold:'#F0973A'};

document.querySelectorAll('#rarityPicker .chip').forEach(c=>{
  c.addEventListener('click',()=>{
    document.querySelectorAll('#rarityPicker .chip').forEach(x=>x.classList.toggle('active',x===c));
    currentRarity = c.dataset.rarity;
    playReveal(currentRarity);
  });
});

function playReveal(key){
  const r = RARITY[key];
  const col = COLORMAP[r.color];
  reveal.classList.remove('play');
  revealRings.innerHTML = ''; revealBurst.innerHTML = '';
  revealRays.classList.remove('go'); revealFlash.classList.remove('go'); revealStars.classList.remove('go');
  revealFrame.className = 'reveal-frame';

  revealOrb.style.setProperty('--h', r.h);
  // stars
  revealStars.innerHTML = '★★★★★'.split('').map((s,i)=>
    `<span style="${i<r.stars?'':'opacity:0!important;'}">${i<r.stars?'★':''}</span>`).join('');
  revealClass.textContent = r.cls;
  revealClass.style.fontFamily = '';
  // badge
  if(r.badge){ revealBadge.style.display=''; revealBadge.textContent = r.badge;
    revealBadge.style.color = '#fff';
    revealBadge.style.background = col;
    revealBadge.style.boxShadow = `0 8px 18px -6px ${hexA(col,0.6)}`;
  } else { revealBadge.style.display='none'; }
  if(r.special==='birthday'){ revealBadge.textContent = '🎂 ' + r.badge; revealFrame.classList.add('birthday'); }
  if(r.special==='midnight'){ revealBadge.textContent = '🌙 ' + r.badge; revealFrame.classList.add('midnight'); }

  void reveal.offsetWidth;
  reveal.classList.add('play');

  // impact at ~1.0s (when vial lands)
  setTimeout(()=>{
    // rings
    for(let i=0;i<r.rings;i++){
      const ring = document.createElement('i');
      const sz = 90 + i*70;
      ring.style.width = ring.style.height = sz+'px';
      ring.style.borderColor = col;
      ring.style.animationDelay = (i*0.12)+'s';
      revealRings.appendChild(ring);
      requestAnimationFrame(()=>ring.classList.add('go'));
    }
    // particle burst
    for(let i=0;i<r.parts;i++){
      const p = document.createElement('i');
      const ang = Math.random()*Math.PI*2, dist = 40+Math.random()*(110+r.stars*22);
      p.style.background = `rgb(${popRGB()})`;
      p.style.left='0';p.style.top='0';
      p.style.transition = `transform 1s cubic-bezier(.16,1,.3,1), opacity 1.1s`;
      revealBurst.appendChild(p);
      requestAnimationFrame(()=>{
        p.style.transform = `translate(${Math.cos(ang)*dist}px,${Math.sin(ang)*dist}px) rotate(${Math.random()*360}deg)`;
        p.style.opacity='0';
      });
      setTimeout(()=>p.remove(),1200);
    }
    if(r.rays){ revealRays.classList.add('go'); }
    if(r.flash){ revealFlash.style.opacity=r.flash; revealFlash.classList.add('go'); }
  }, 1000);

  // stars pop after meta appears
  setTimeout(()=>{
    revealStars.querySelectorAll('span').forEach((s,i)=> s.style.animationDelay=(i*0.12)+'s');
    revealStars.classList.add('go');
  }, 1500);
}
function hexA(hex,a){const n=parseInt(hex.slice(1),16);return `rgba(${n>>16&255},${n>>8&255},${n&255},${a})`;}

/* ============================================================
   05 SEAL
   ============================================================ */
const sealRoom = document.querySelector('.seal-room');
const sealDo = document.getElementById('sealDo');
const sealState = document.getElementById('sealState');
const sealLine = document.getElementById('sealLine');
const crystal = document.getElementById('crystal');
const sealShards = document.getElementById('sealShards');

function resetSeal(){
  sealRoom.classList.remove('sealing');
  crystal.classList.remove('locked');
  sealState.textContent = '封をする前';
  sealLine.innerHTML = 'この標本を、風化しない結晶へ。<br/>大切なものだけを、永く手元に。';
  sealDo.style.display = '';
  sealDo.disabled = false;
  sealShards.innerHTML = '';
}
sealDo.addEventListener('click', ()=>{
  if(sealRoom.classList.contains('sealing')) return;
  sealDo.disabled = true;
  // shard burst inward→out
  for(let i=0;i<18;i++){
    const sh=document.createElement('i');
    const ang=Math.random()*Math.PI*2,d=50+Math.random()*70;
    sh.style.background=`rgb(${popRGB()})`;
    sh.style.transition=`transform 1s cubic-bezier(.16,1,.3,1) ${.2+Math.random()*.3}s,opacity 1.1s`;
    sealShards.appendChild(sh);
    requestAnimationFrame(()=>{sh.style.opacity='.9';sh.style.transform=`translate(${Math.cos(ang)*d-4}px,${Math.sin(ang)*d-4}px) rotate(${Math.random()*360}deg)`;});
    setTimeout(()=>{sh.style.opacity='0';},900);
  }
  sealRoom.classList.add('sealing');
  setTimeout(()=>{
    crystal.classList.add('locked');
    sealState.textContent = '封印 完了';
    sealLine.innerHTML = '結晶に封じられた。<br/>この標本は、もう風化しない。';
    sealDo.style.display = 'none';
  }, 1600);
});

/* ============================================================
   boot
   ============================================================ */
go('boot');
