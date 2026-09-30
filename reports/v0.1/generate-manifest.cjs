const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const files=['project.godot','scripts/core/input_bindings.gd','scripts/core/test_room.gd','scripts/player/player.gd','scripts/level/course.gd','scripts/level/run_flow.gd','scripts/ui/interface.gd','scripts/visual/player_visual.gd'];
function walk(dir){for(const item of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){const p=dir+'/'+item.name;if(item.isDirectory())walk(p);else if(/\.(png|wav|tscn|tres)$/.test(p))files.push(p);}}
for(const dir of ['assets/visual','assets/audio','scenes/main','scenes/player','scenes/test_room','scenes/levels','scenes/ui/skins'])walk(dir);
const rows=[...new Set(files)].sort().map(p=>({path:p,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex'),bytes:fs.statSync(path.join(root,p)).size}));
const digest=crypto.createHash('sha256').update(JSON.stringify(rows)).digest('hex');
const manifest={version:'v0.1.0+'+digest.slice(0,12),sha256:digest,generatedAt:new Date().toISOString(),entry:'res://scenes/main/main.tscn',engine:'Godot 4.7.2 stable',files:rows};
fs.writeFileSync(path.join(__dirname,'version-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({version:manifest.version,files:rows.length,sha256:digest}));
