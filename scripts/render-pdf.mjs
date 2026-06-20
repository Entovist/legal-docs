import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import puppeteer from 'puppeteer-core';

function parseArguments(argv) {
  const values = {};

  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];

    if (!name?.startsWith('--') || value === undefined) {
      throw new Error(`Invalid argument near '${name ?? ''}'.`);
    }

    values[name.slice(2)] = value;
  }

  for (const name of ['html', 'output', 'browser', 'title', 'version']) {
    if (!values[name]) {
      throw new Error(`Missing required argument --${name}.`);
    }
  }

  return values;
}

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

async function connectToEdge(executablePath) {
  const profilePath = await mkdtemp(join(tmpdir(), 'entovist-edge-'));
  const activePortPath = join(profilePath, 'DevToolsActivePort');

  spawn(
    executablePath,
    [
      '--headless=new',
      '--remote-debugging-port=0',
      `--user-data-dir=${profilePath}`,
      '--no-first-run',
      '--disable-gpu',
      '--disable-breakpad',
      '--disable-crash-reporter',
      'about:blank'
    ],
    { detached: true, stdio: 'ignore' }
  ).unref();

  for (let attempt = 0; attempt < 120; attempt += 1) {
    try {
      const [port] = (await readFile(activePortPath, 'utf8')).split(/\r?\n/);
      const browser = await puppeteer.connect({ browserURL: `http://127.0.0.1:${port}` });
      return { browser, profilePath };
    }
    catch {
      await delay(250);
    }
  }

  throw new Error('Timed out while connecting to the headless Edge process.');
}

async function removeProfile(profilePath) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      await rm(profilePath, { recursive: true, force: true });
      return;
    }
    catch {
      await delay(250);
    }
  }

  console.warn(`Could not remove temporary Edge profile: ${profilePath}`);
}

const options = parseArguments(process.argv.slice(2));
const { browser, profilePath } = await connectToEdge(options.browser);

try {
  const page = await browser.newPage();
  await page.goto(pathToFileURL(options.html).href, { waitUntil: 'networkidle0' });

  const label = `${escapeHtml(options.title)} · Version ${escapeHtml(options.version)}`;
  const footerTemplate = `
    <div style="box-sizing:border-box;width:100%;margin:0 17mm;padding-top:4px;border-top:1px solid #cbd5e1;color:#64748b;font-family:Arial,sans-serif;font-size:8px;display:flex;justify-content:space-between;align-items:center;">
      <span>${label}</span>
      <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
    </div>`;

  await page.pdf({
    path: options.output,
    format: 'A4',
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: '<div></div>',
    footerTemplate,
    margin: {
      top: '18mm',
      right: '17mm',
      bottom: '20mm',
      left: '17mm'
    }
  });
}
finally {
  await browser.close();
  await removeProfile(profilePath);
}
