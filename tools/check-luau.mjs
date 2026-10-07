import {readFile, readdir} from 'node:fs/promises';
import {join} from 'node:path';
import {LuauState} from 'luau-web';

async function sources(directory) {
  const entries=await readdir(directory,{withFileTypes:true});
  const nested=await Promise.all(entries.map(entry=>entry.isDirectory()
    ? sources(join(directory,entry.name))
    : entry.name.endsWith('.luau') ? [join(directory,entry.name)] : []));
  return nested.flat();
}
const files=await sources('src');
if(!files.length) throw new Error('No Luau sources found');
const state=await LuauState.createAsync();
try {
  for(const file of files) state.loadstring(await readFile(file,'utf8'),file,true);
  console.log(`Luau compilation passed: ${files.length} production files.`);
} finally {state.destroy();}
