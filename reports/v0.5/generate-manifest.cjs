const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),files=require('../v0.4.1/version-manifest.json').files.map(f=>f.path);
files.push('scripts/level/vertical_library.gd','scripts/level/continuous_hazard.gd','scenes/ui/v05_status.gd','scenes/ui/v05_status.tscn','assets/visual/v05/platform_cap.svg','assets/visual/v05/ground_side.svg','assets/visual/v05/route_upper.svg','assets/audio/v05/hurt_tick.wav');
const rows=[...new Set(files)].sort().map(p=>({path:p,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex'),bytes:fs.statSync(path.join(root,p)).size}));
const sha256=crypto.createHash('sha256').update(JSON.stringify(rows)).digest('hex');
const manifest={version:'v0.5.0+'+sha256.slice(0,12),sha256,generatedAt:new Date().toISOString(),entry:'res://scenes/main/main.tscn',toolEntry:'res://scenes/tools/generation_editor.tscn',engine:'Godot 4.7.2 stable',configuration:{path:'resources/generation/endless_default.json',schema:1,generator_revision:3,rules_revision:5,legacy_config_revision:2,record:'user://signal_runway_endless_v05.json'},files:rows};
fs.writeFileSync(path.join(__dirname,'version-manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({version:manifest.version,files:rows.length,sha256}));
