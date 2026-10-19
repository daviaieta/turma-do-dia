// Os 10 personagens da Turma do Dia (SVG gerado por código, desenhos originais).
// API: Characters.ids, Characters.svg(id, mood)  com mood = 'smile' | 'happy'
(function () {
const INK = '#2B2420';

function face(x, y, mood, o = {}){
  const ec = o.ec || INK;
  const mouth = mood === 'happy'
    ? `<path d="M${x-9} ${y+7} Q${x} ${y+20} ${x+9} ${y+7} Z" fill="${ec}"/>`
    : (o.o ? `<ellipse cx="${x}" cy="${y+11}" rx="3.2" ry="4" fill="${ec}"/>`
           : `<path d="M${x-7} ${y+8} Q${x} ${y+16} ${x+7} ${y+8}" fill="none" stroke="${ec}" stroke-width="2.6" stroke-linecap="round"/>`);
  const eyes = (o.closed && mood !== 'happy')
    ? `<path d="M${x-17} ${y-1} q5 5 10 0 M${x+7} ${y-1} q5 5 10 0" fill="none" stroke="${ec}" stroke-width="2.8" stroke-linecap="round"/>`
    : `<ellipse class="eye" cx="${x-12}" cy="${y-2}" rx="3.4" ry="4.6" fill="${ec}"/>
       <ellipse class="eye" cx="${x+12}" cy="${y-2}" rx="3.4" ry="4.6" fill="${ec}"/>`;
  const glasses = o.glasses ? `
    <circle cx="${x-12}" cy="${y-2}" r="11.5" fill="#FF8A1F" fill-opacity=".5" stroke="${INK}" stroke-width="3"/>
    <circle cx="${x+12}" cy="${y-2}" r="11.5" fill="#FF8A1F" fill-opacity=".5" stroke="${INK}" stroke-width="3"/>
    <path d="M${x-1} ${y-3} h2 M${x-23.5} ${y-4} l-7 -3 M${x+23.5} ${y-4} l7 -3" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>` : '';
  return `
    <circle cx="${x-19}" cy="${y+8}" r="5" fill="#FF8A8A" opacity=".55"/>
    <circle cx="${x+19}" cy="${y+8}" r="5" fill="#FF8A8A" opacity=".55"/>
    ${eyes}${glasses}${mouth}`;
}
function limbs(o){
  const {ls, rs, legTop, l1, l2, hand} = o;
  const leftArm = `<path d="M${ls[0]} ${ls[1]} q-16 6 -14 28" fill="none" stroke="${INK}" stroke-width="4.5" stroke-linecap="round"/>
    <circle cx="${ls[0]-14}" cy="${ls[1]+28}" r="4.2" fill="${INK}"/>`;
  const hx = rs[0]+16, hy = rs[1]-26;
  const rightArm = `<g class="wave" style="transform-origin:${rs[0]}px ${rs[1]}px">
    <path d="M${rs[0]} ${rs[1]} q16 -4 16 -26" fill="none" stroke="${INK}" stroke-width="4.5" stroke-linecap="round"/>
    <circle cx="${hx}" cy="${hy}" r="4.2" fill="${INK}"/>${hand ? hand(hx, hy) : ''}</g>`;
  const legs = `<path d="M${l1} ${legTop} v22 M${l2} ${legTop} v22" stroke="${INK}" stroke-width="4.5" stroke-linecap="round"/>
    <ellipse cx="${l1-3}" cy="${legTop+24}" rx="8" ry="4.2" fill="${INK}"/>
    <ellipse cx="${l2+3}" cy="${legTop+24}" rx="8" ry="4.2" fill="${INK}"/>`;
  return legs + leftArm + rightArm;
}
const S = (inner) => `<svg viewBox="0 0 120 180" aria-hidden="true"><g class="bob">${inner}</g></svg>`;
const ST = `stroke="${INK}" stroke-width="3.2" stroke-linejoin="round"`;

const CHARS = [
  { id:'sol', name:'Sol', 
    build(m){
      let rays = '';
      for (let a = 0; a < 360; a += 30){
        if (a >= 60 && a <= 120) continue;
        const r = a * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
        rays += `<path d="M${60+c*39} ${84+s*39} L${60+c*52} ${84+s*52}" stroke="#FFB020" stroke-width="6.5" stroke-linecap="round"/>`;
      }
      return S(limbs({ls:[30,100], rs:[90,100], legTop:113, l1:50, l2:70}) +
        `<g class="rays">${rays}</g>
        <circle cx="60" cy="84" r="31" fill="#FFD23F" ${ST}/>
        <path d="M40 66 q5 -9 14 -11" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".6"/>
        ${face(60,86,m)}`);
    }},
  { id:'mochila', name:'Mochila', 
    build(m){
      return S(limbs({ls:[34,86], rs:[86,86], legTop:130, l1:50, l2:70}) +
        `<path d="M52 42 v-9 a8 8 0 0 1 16 0 v9" fill="none" stroke="${INK}" stroke-width="3.2" stroke-linecap="round"/>
        <rect x="32" y="40" width="56" height="92" rx="22" fill="#4A86E0" ${ST}/>
        <rect x="42" y="100" width="36" height="26" rx="9" fill="#356BC2" ${ST}/>
        <path d="M44 108 h32" stroke="${INK}" stroke-width="2.4" stroke-linecap="round" stroke-dasharray="3 5"/>
        <circle cx="60" cy="108" r="3" fill="#FFD23F" stroke="${INK}" stroke-width="2"/>
        ${face(60,70,m)}`);
    }},
  { id:'gota', name:'Gota', 
    build(m){
      return S(limbs({ls:[31,102], rs:[89,102], legTop:126, l1:50, l2:70}) +
        `<path d="M60 22 C60 22 26 66 26 96 C26 115 41 128 60 128 C79 128 94 115 94 96 C94 66 60 22 60 22 Z" fill="#5BC3F2" ${ST}/>
        <path d="M38 94 q-2 14 8 24" fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round" opacity=".65"/>
        ${face(60,98,m)}`);
    }},
  { id:'prato', name:'Prato', 
    build(m){
      const fork = (x,y) => `<path d="M${x} ${y-4} v-13 M${x-4} ${y-17} v-7 M${x+4} ${y-17} v-7 M${x-4} ${y-17} h8" fill="none" stroke="${INK}" stroke-width="2.4" stroke-linecap="round"/>`;
      return S(limbs({ls:[21,92], rs:[99,92], legTop:128, l1:50, l2:70, hand:fork}) +
        `<circle cx="60" cy="88" r="40" fill="#fff" ${ST}/>
        <circle cx="60" cy="88" r="30" fill="none" stroke="#E5DCCB" stroke-width="2.5"/>
        <path d="M38 112 q6 -10 14 -4 q4 8 -2 12 q-10 2 -12 -8 Z" fill="#6B3B22" ${ST.replace('3.2','2.4')}/>
        <path d="M58 118 q8 -12 18 -6 q4 8 -4 12 q-10 2 -14 -6 Z" fill="#F6EBCB" ${ST.replace('3.2','2.4')}/>
        <circle cx="82" cy="106" r="7" fill="#F5A623" ${ST.replace('3.2','2.4')}/>
        ${face(60,78,m)}`);
    }},
  { id:'prompt', name:'Prompt', 
    build(m){
      return S(limbs({ls:[26,88], rs:[94,88], legTop:124, l1:50, l2:70}) +
        `<rect x="24" y="42" width="72" height="84" rx="12" fill="#1F2937" ${ST}/>
        <circle cx="35" cy="52" r="3" fill="#FF6B6B"/><circle cx="44" cy="52" r="3" fill="#FFD23F"/><circle cx="53" cy="52" r="3" fill="#4ADE80"/>
        ${face(60,84,m,{ec:'#4ADE80'})}
        <rect class="cur" x="52" y="110" width="16" height="4" rx="2" fill="#4ADE80"/>`);
    }},
  { id:'gi', name:'Gi', 
    build(m){
      return S(limbs({ls:[30,84], rs:[90,84], legTop:128, l1:50, l2:70}) +
        `<path d="M30 48 L48 40 Q60 50 72 40 L90 48 L98 126 L22 126 Z" fill="#fff" ${ST}/>
        <path d="M44 42 L47 100 M76 42 L73 100" fill="none" stroke="#CFC7B6" stroke-width="3" stroke-linecap="round"/>
        <rect x="22" y="100" width="76" height="13" fill="#F1EDE2" ${ST.replace('3.2','2.8')}/>
        <path d="M56 113 l-5 17 M64 113 l5 15" stroke="${INK}" stroke-width="2.8" stroke-linecap="round"/>
        <circle cx="60" cy="107" r="6" fill="#F1EDE2" ${ST.replace('3.2','2.6')}/>
        ${face(60,70,m)}`);
    }},
  { id:'peso', name:'Peso', 
    build(m){
      return S(limbs({ls:[27,106], rs:[93,106], legTop:132, l1:50, l2:70}) +
        `<path d="M40 76 C34 36 86 36 80 76" fill="none" stroke="${INK}" stroke-width="13" stroke-linecap="round"/>
        <path d="M40 76 C34 40 86 40 80 76" fill="none" stroke="#6B7280" stroke-width="6" stroke-linecap="round"/>
        <circle cx="60" cy="100" r="34" fill="#374151" ${ST}/>
        <path d="M36 88 q4 -12 16 -16" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".35"/>
        ${face(60,102,m,{ec:'#fff'})}`);
    }},
  { id:'lua', name:'Lua', 
    build(m){
      return S(limbs({ls:[26,98], rs:[94,98], legTop:118, l1:50, l2:70}) +
        `<circle cx="60" cy="84" r="35" fill="#F3EAC9" ${ST}/>
        <circle cx="38" cy="62" r="6" fill="#E4D7A8"/><circle cx="84" cy="64" r="4" fill="#E4D7A8"/>
        <circle cx="82" cy="108" r="7" fill="#E4D7A8"/><circle cx="40" cy="104" r="4.5" fill="#E4D7A8"/>
        ${face(60,86,m,{glasses:true})}`);
    }},
  { id:'claquete', name:'Claquete', 
    build(m){
      return S(limbs({ls:[26,102], rs:[94,102], legTop:126, l1:50, l2:70}) +
        `<rect x="26" y="62" width="68" height="64" rx="7" fill="#fff" ${ST}/>
        <path d="M26 74 H94" stroke="${INK}" stroke-width="2.4"/>
        <g class="clap"><rect x="26" y="44" width="68" height="18" rx="5" fill="${INK}"/>
        <path d="M40 62 L48 44 H58 L50 62 Z M62 62 L70 44 H80 L72 62 Z" fill="#fff"/>
        <rect x="26" y="44" width="68" height="18" rx="5" fill="none" ${ST}/></g>
        ${face(60,98,m)}`);
    }},
  { id:'travesseiro', name:'Travesseiro', 
    build(m){
      return S(limbs({ls:[26,94], rs:[94,94], legTop:124, l1:50, l2:70}) +
        `<path d="M28 60 Q60 48 92 60 Q98 92 92 122 Q60 132 28 122 Q22 92 28 60 Z" fill="#CFE0FF" ${ST}/>
        <path d="M34 66 l5 5 M86 66 l-5 5 M34 118 l5 -5 M86 118 l-5 -5" stroke="#9DB7E8" stroke-width="2.6" stroke-linecap="round"/>
        ${face(60,92,m,{closed:true,o:true})}
        <g class="zz"><text x="92" y="52" font-size="16" font-weight="700" fill="${INK}" font-family="ui-rounded,system-ui">z</text><text x="100" y="40" font-size="12" font-weight="700" fill="${INK}" font-family="ui-rounded,system-ui">z</text></g>`);
    }}
];

  const byId = Object.fromEntries(CHARS.map(c => [c.id, c]));
  window.Characters = {
    ids: CHARS.map(c => c.id),
    svg(id, mood) { const c = byId[id]; return c ? c.build(mood || 'smile') : ''; }
  };
})();
