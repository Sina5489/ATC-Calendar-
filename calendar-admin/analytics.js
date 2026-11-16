(()=>{'use strict';
const BASE='https://pcgywfcguxhvmzwjftei.supabase.co',KEY='sb_publishable_5Ip0y9knqh0oqAAfMfnjmQ_jpbVA-I_',VERSION='1.1.2';
const ua=navigator.userAgent||'',match=ua.match(/ATCCalendarAPK\/([0-9.]+)/),apk=!!match,version=match?.[1]||VERSION,platform=apk?'apk':'pwa';
const id=()=>{try{return crypto.randomUUID()}catch{return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{const r=Math.random()*16|0;return(c==='x'?r:(r&3|8)).toString(16)})}};
const get=k=>{try{return localStorage.getItem(k)}catch{return null}},set=(k,v)=>{try{localStorage.setItem(k,v)}catch{}};
let visitor=get('atc_analytics_visitor');if(!visitor){visitor=id();set('atc_analytics_visitor',visitor)}
let session;try{session=sessionStorage.getItem('atc_analytics_session')}catch{}if(!session){session=id();try{sessionStorage.setItem('atc_analytics_session',session)}catch{}}
const fresh=!get('atc_analytics_seen');if(fresh)set('atc_analytics_seen','1');
const device=/Android/i.test(ua)?'Android':/iPhone|iPad|iPod/i.test(ua)?'iOS':/Windows/i.test(ua)?'Windows':/Macintosh|Mac OS/i.test(ua)?'macOS':/Linux/i.test(ua)?'Linux':'Other';
const browser=/Edg\//.test(ua)?'Edge':/Firefox\//.test(ua)?'Firefox':/CriOS|Chrome\//.test(ua)?'Chrome':/Safari\//.test(ua)?'Safari':'Other',Q='atc_analytics_queue_v1';
function queue(row,table='atc_analytics_events'){try{const a=JSON.parse(get(Q)||'[]');a.push({...row,_table:table});set(Q,JSON.stringify(a.slice(-100)))}catch{}}
async function post(row,table='atc_analytics_events'){try{const r=await fetch(BASE+'/rest/v1/'+table,{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+KEY,'Content-Type':'application/json',Prefer:'return=minimal'},body:JSON.stringify(row),keepalive:true});if(!r.ok)throw Error();return true}catch{return false}}
async function flush(){if(!navigator.onLine)return;let a=[];try{a=JSON.parse(get(Q)||'[]')}catch{}const remain=[];for(const item of a){const row={...item};const table=row._table||'atc_analytics_events';delete row._table;if(!await post(row,table))remain.push(item)}set(Q,JSON.stringify(remain.slice(-100)))}
function send(type,metadata={}){const row={event_type:type,platform,visitor_id:visitor,session_id:session,is_new:type==='session_start'&&fresh,app_version:version,device_type:device,browser,path:location.pathname,metadata};post(row).then(ok=>{if(!ok)queue(row)})}
function trackAdClick(e){const link=e.target?.closest?.('#atcOnlineAdLink');if(!link)return;const img=document.getElementById('atcOnlineAdImage');const imageUrl=img?.currentSrc||img?.src||'';const targetUrl=link.href||'';if(!imageUrl||!targetUrl||targetUrl==='#'||!/^https?:/i.test(targetUrl))return;const row={image_url:imageUrl,target_url:targetUrl,platform,visitor_id:visitor,session_id:session};post(row,'atc_ad_click_events').then(ok=>{if(!ok)queue(row,'atc_ad_click_events')});send('ad_click',{image_url:imageUrl,target_url:targetUrl})}
send('session_start');send('page_view');document.addEventListener('click',trackAdClick,true);setInterval(()=>{if(!document.hidden)send('heartbeat')},60000);addEventListener('online',flush);
addEventListener('error',e=>{const t=e.target;if(t&&t!==window){send('resource_error',{tag:t.tagName||'unknown',source:(t.src||t.href||'').slice(0,180)});return}send('app_error',{name:e.error?.name||'Error',message:String(e.message||'').slice(0,180)})},true);
addEventListener('unhandledrejection',e=>send('app_error',{name:'UnhandledRejection',message:String(e.reason?.message||e.reason||'').slice(0,180)}));flush();
})();