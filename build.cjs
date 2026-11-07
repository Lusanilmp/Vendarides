const fs=require('node:fs');const path=require('node:path');
fs.rmSync('dist',{recursive:true,force:true});fs.mkdirSync('dist');
for(const name of fs.readdirSync('.'))if(/\.(html|css|js|webmanifest)$/.test(name)&&!name.endsWith('.test.js'))fs.copyFileSync(name,path.join('dist',name));
fs.cpSync('assets','dist/assets',{recursive:true});
