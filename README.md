# fetchbatch
Multi-account fetchmail init.d script for Debian 9

A modification of the standard Fetchmail deamon script based on [this post](http://fnxweb.com/blog/2012/07/14/using-multiple-fetchmail-instances-for-instant-gratification/) in order to fetch multiple email accounts

Starts deamons for all .conf files from `/etc/fetchmail.conf.d`

## Currently Working
* start
* stop
* status

## Untested
* force-reload/restart
* try-restart
* awaken

## Known issues
* debug-run
