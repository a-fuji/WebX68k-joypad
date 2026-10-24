const response=await fetch('http://127.0.0.1:5399/'+process.argv[2],{method:'POST',body:process.argv[3]||'{}'});
const body=await response.text();console.log(body);if(!response.ok)process.exitCode=1;
