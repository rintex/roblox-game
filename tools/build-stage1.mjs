// Build a ready-to-open place by running the real Stage1Map script in Luau.
// The small mock generates static properties only; Studio must verify gameplay.
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { LuauState } from 'luau-web';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputDirectory = resolve(root, 'build');
const rojo = process.env.ROJO_BIN || '/workspace/.tools/rojo-7.7.1/rojo';

// Luau tables are interop wrappers, so convert them before destroying the VM.
function plainValue(value) {
  if (value === null || typeof value !== 'object') return value;
  const keys = value.keys();
  if (keys.length > 0 && keys.every((key) => Number.isInteger(key) && key >= 1)) {
    keys.sort((a, b) => a - b);
    if (keys.every((key, index) => key === index + 1)) {
      return keys.map((key) => plainValue(value.get(key)));
    }
  }
  return Object.fromEntries(keys.map((key) => [key, plainValue(value.get(key))]));
}

function absolutePaths(node) {
  for (const [name, value] of Object.entries(node)) {
    if (name === '$path') {
      if (typeof value === 'string') node[name] = isAbsolute(value) ? value : resolve(root, value);
      else if (value?.optional) value.optional = resolve(root, value.optional);
    } else if (!name.startsWith('$') && value && typeof value === 'object') {
      absolutePaths(value);
    }
  }
}

// CFrame.lookAt in a row-major array accepted by Rojo's project format.
function cameraFrame(position, target) {
  const norm = (v) => {
    const length = Math.hypot(...v);
    return v.map((component) => component / length);
  };
  const cross = (a, b) => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
  const back = norm(position.map((component, i) => component - target[i]));
  const right = norm(cross([0, 1, 0], back));
  const up = cross(back, right);
  return [
    ...position,
    right[0], up[0], back[0],
    right[1], up[1], back[1],
    right[2], up[2], back[2],
  ];
}

const [source, environment, projectText] = await Promise.all([
  readFile(resolve(root, 'src/server/Stage1Map.server.luau'), 'utf8'),
  readFile(resolve(root, 'tools/map-environment.luau'), 'utf8'),
  readFile(resolve(root, 'default.project.json'), 'utf8'),
]);
const state = await LuauState.createAsync();
let baked;
try {
  const execute = state.loadstring(`${environment}\nlocal function generateMap()\n${source}\nend
generateMap()
local before = #registry
generateMap()
assert(#registry == before, "Running Stage1Map again must not create duplicates")
return exportMap()`, 'Stage1 place builder', true);
  const result = await execute();
  baked = plainValue(result[0]);
} finally {
  state.destroy();
}

const project = JSON.parse(projectText);
project.tree.Workspace = baked.Workspace;
project.tree.Lighting = baked.Lighting;
// Rojo resolves this supported attribute pointer into a saved CurrentCamera Ref.
project.tree.Workspace.$attributes = { Rojo_Target_CurrentCamera: 'Stage1EditorCamera' };
project.tree.Workspace.Camera = {
  $className: 'Camera',
  $id: 'Stage1EditorCamera',
  $properties: {
    CFrame: cameraFrame([110, 95, 110], [0, 0, 0]),
    Focus: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
    CameraType: 'Custom',
    FieldOfView: 70,
  },
};
absolutePaths(project.tree);
await mkdir(outputDirectory, { recursive: true });
const intermediate = resolve(outputDirectory, 'stage1.generated.project.json');
try {
  await writeFile(intermediate, `${JSON.stringify(project, null, 2)}\n`);
  for (const extension of ['rbxlx', 'rbxl']) {
    const output = resolve(outputDirectory, `Stage1.${extension}`);
    const result = spawnSync(rojo, ['build', intermediate, '--output', output], {
      cwd: root,
      stdio: 'inherit',
    });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`Rojo build failed (${result.status})`);
  }
} finally {
  await rm(intermediate, { force: true });
}
console.log('Built build/Stage1.rbxlx and build/Stage1.rbxl: 30 anchored map Parts, one StartSpawn, and the server Script.');
