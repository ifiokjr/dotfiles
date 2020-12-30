import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, writeFileSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonFilePath = join(__dirname, 'quotes.json');
const pluginFilePath = join(__dirname, 'quotes/quotes.plugin.zsh');
const start = '### START REPLACEMENT ###';
const end = '### END REPLACEMENT ###';
const regexp = /^### START REPLACEMENT ###[\s\S]+### END REPLACEMENT ###$/m;
const options = { encoding: 'utf-8' };

/**
 * @type {Array<{text: string; author: string }>}
 */
const jsonQuotes = JSON.parse(readFileSync(jsonFilePath, options));

/**
 * @type {string[]}
 */
const quotes = [];

for (const { author = 'Unknown', text } of jsonQuotes) {
  quotes.push(
    JSON.stringify(`\\e[0m"${text}"\\n\\t\\e[1m\\e[96m${author}\\e[0m`).replace(
      /\\\\([e|n|t])/g,
      '\\$1',
    ),
  );
}

// Transform quotes array into a bash variable.
const bashQuotesVariable = `${start}\nquotes=(\n\t${quotes.join(
  '\n\t',
)}\n)\n${end}`;

// Current contents of plugins file.
const pluginContents = readFileSync(pluginFilePath, options);

// Transformed contents of plugins file.
const transformedPluginContents = pluginContents.replace(
  regexp,
  bashQuotesVariable,
);

// Only write the files if the output is different.
if (pluginContents !== transformedPluginContents) {
  console.log('Updating quotes.');
  writeFileSync(pluginFilePath, transformedPluginContents, options);
}
