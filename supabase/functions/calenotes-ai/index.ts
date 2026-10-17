// Deploy this optional function only if you want to provide website AI at your expense.
// Secrets: DEEPSEEK_API_KEY, ALLOWED_ORIGINS (comma-separated origins).
Deno.serve(async (request:Request)=>{
 const origin=request.headers.get('Origin')||'';
 const allowed=(Deno.env.get('ALLOWED_ORIGINS')||'').split(',').map(s=>s.trim()).filter(Boolean);
 const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':allowed.includes(origin)?origin:'null','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Vary':'Origin'};
 const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(!allowed.includes(origin))return reply({message:'Site origin is not configured in ALLOWED_ORIGINS'},403);
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return reply({message:'Method not allowed'},405);
 const token=request.headers.get('Authorization')||'';
 if(!token.startsWith('Bearer '))return reply({message:'Please sign in'},401);
 const url=Deno.env.get('SUPABASE_URL')!;const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
 try{
  const auth=await fetch(url+'/auth/v1/user',{headers:{apikey:anon,Authorization:token}});
  if(!auth.ok)return reply({message:'Session expired. Please sign in again.'},401);
  const user=await auth.json();if(!user.id)return reply({message:'Please sign in'},401);
  const secret=Deno.env.get('DEEPSEEK_API_KEY');if(!secret)return reply({message:'站点管理员尚未启用网页 AI。'},503);
  const raw=await request.text();if(raw.length>50000)return reply({message:'Request is too large'},413);
  const payload=JSON.parse(raw);const prompt=String(payload.prompt||'').slice(0,20000);if(!prompt)return reply({message:'Prompt is required'},400);
  const quota=await fetch(url+'/rest/v1/rpc/consume_calenotes_ai_quota',{method:'POST',headers:{apikey:anon,Authorization:token,'Content-Type':'application/json'},body:'{}'});
  if(!quota.ok)return reply({message:'请先执行数据库建表脚本以启用 AI 配额。'},503);
  if(await quota.json()!==true)return reply({message:'今天的 AI 使用次数已到上限，明天再来。'},429);
  const body:Record<string,unknown>={model:Deno.env.get('DEEPSEEK_MODEL')||'deepseek-flash',stream:false,max_tokens:2048,messages:[...(payload.systemPrompt?[{role:'system',content:String(payload.systemPrompt).slice(0,12000)}]:[]),{role:'user',content:prompt}]};
  if(payload.format==='json')body.response_format={type:'json_object'};
  const response=await fetch('https://api.deepseek.com/chat/completions',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${secret}`},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});
  const result=await response.json();if(!response.ok)return reply({message:result.error?.message||'AI 服务暂时不可用'},502);
  return reply({response:result.choices?.[0]?.message?.content||''});
 }catch(error){return reply({message:error instanceof SyntaxError?'请求格式无效':'请求暂时失败，请稍后重试。'},500);}
});
