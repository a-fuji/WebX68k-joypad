import {Client} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import {writeFile} from 'node:fs/promises';
const client=new Client({name:'pirate68k-handshake-check',version:'1.0'});
const transport=new StdioClientTransport({command:process.execPath,args:['mcp/server.mjs'],env:{...process.env,WEBX68K_BRIDGE_PORT:'3299'}});
try{
 await client.connect(transport);
 const list=await client.listTools();
 const required=['status','screen_text','screenshot','type_text','key_sequence','disk_list_files','disk_read_file','read_memory'];
 for(const name of required)if(!list.tools.some(t=>t.name===name))throw new Error('Missing MCP tool: '+name);
 const result={result:'PASS',server:client.getServerVersion(),bridgePort:3299,tools:list.tools.map(t=>t.name)};
 await writeFile('_local/pirate68k/mcp-handshake.json',JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result));
}finally{await client.close();}
