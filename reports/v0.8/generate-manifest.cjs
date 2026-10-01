const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),files=require('../v0.7/version-manifest.json').files.map(f=>f.path);
files.push('scripts/level/skill_library.gd','scripts/level/skill_generator.gd','scripts/tools/dash_prototypes.gd','scenes/tools/dash_prototypes.tscn','scripts/visual/dash_visual.gd','scenes/ui/v08_dash_status.gd','scenes/ui/v08_dash_status.tscn');
for(const folder of ['assets/visual/v08','assets/audio/v08'])if(fs.existsSync(path.join(root,folder)))for(const name of fs.readdirSync(path.join(root,folder)))if(!name.endsWith('.import'))files.push(folder+'/'+name);
for(const file of ['scripts/visual/route_visual.gd','scenes/ui/v06_route_status.gd','scenes/ui/v06_route_status.tscn'])if(fs.existsSync(path.join(root,file)))files.push(file);
const rows=[...new Set(files)].sort().map(p=>({path:p,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex'),bytes:fs.statSync(path.join(root,p)).size}));
const sha256=crypto.createHash('sha256').update(JSON.stringify(rows)).digest('hex');
const manifest={version:'v0.8.0+'+sha256.slice(0,12),sha256,generatedAt:new Date().toISOString(),entry:'res://scenes/main/main.tscn',toolEntry:'res://scenes/tools/generation_editor.tscn',engine:'Godot 4.7.2 stable',configuration:{path:'resources/generation/endless_default.json',schema:1,generator_revision:6,rules_revision:8,legacy_config_revisions:[2,3,4,5],record:'user://signal_runway_endless_v08.json'},files:rows};
fs.writeFileSync(path.join(__dirname,'version-manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({version:manifest.version,files:rows.length,sha256}));
