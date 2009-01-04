--- 
wordpress_id: 129
layout: post
title: In Search For the Ultimate Cross-Platform Backup Solution
wordpress_url: http://jonasboner.com/2007/01/10/in-search-for-the-ultimate-cross-platform-backup-solution/
---
The last year I have been spending time finding the "ultimate" backup solution for Mac. I also have the requirement that it had to work equally good on Windows, since I am running both Windows and Mac. For example, I would like to be able to commit to my local [SVN](http://subversion.tigris.org/) repository on my [MacBook](http://www.apple.com/macbookpro/), type one single command to upload the changes (only the deltas) to my backup hosting, then invoke one single command on my Windows box to retrieve the latest changes so I can build and test it on Windows - and vice versa. 

The different approaches that I have been playing with the last year are: 

* CD-RW
* External HD with USB/FireWire connection (small portable to carry around).
* Running a Linux server on a spare box  (*openssh*, *rsync* etc.).

Unfortunately, none of these alternatives really worked for me, each one had its problems. 

I wanted the backup solution to have:  

1. Zero administration time, it should just work - on Windows and Mac.2. 24/7 uptime.
2. Fast connection.
3. Secure connection.
4. No cables or other hardware to carry around.

Then I found [Amazon S3](http://aws.amazon.com/s3). 

It is inexpensive: 

* Pay only for what you use. There is no minimum fee, and no start-up cost.
* $0.15 per GB-Month of storage used.
* $0.20 per GB of data transferred.

It has a fairly rich API:

* Write, read, and delete objects containing from 1 byte to 5 gigabytes of data each. The number of objects you can store is unlimited.
* Each object is stored and retrieved via a unique, developer-assigned key.
* Authentication mechanisms are provided to ensure that data is kept secure from unauthorized access. Objects can be made private or public, and rights can be granted to specific users.
* Uses standards-based REST and SOAP interfaces designed to work with any Internet-development toolkit.
* Built to be flexible so that protocol or functional layers can easily be added.  Default download protocol is HTTP.  A BitTorrent(TM) protocol interface is provided to lower costs for high-scale distribution.  Additional interfaces will be added in the future. 

Great stuff, seemed to do what I needed. So far so good. But then the next problem - how to find a usable S3 client that:

* Worked equally good on Mac an on Windows.
* Could be run in command mode (so I could schedule it with *cron*).
* Detected updated and new files - e.g. did not just shovel everything up to the server.

After X hours trying out different (bad and worse) clients I found [jetS3t](https://jets3t.dev.java.net/) - which actually seemed very usable. It is a Java based application, that has two apps in one:

* [Cockpit](https://jets3t.dev.java.net/cockpit.html): a Swing GUI program that is fairly easy to configure. It supports drag and drop, detects new and updated files, keeps the original file name **and** path (more important than you think), compresses (gzip) files, encrypts them etc. Read the documentation for more details. It also has a Java applet that you can use if you want to download some files to a computer that does not have Cockpit installed: [http://jets3t.s3.amazonaws.com/index.html](http://jets3t.s3.amazonaws.com/index.html).

* [Synchronize](https://jets3t.dev.java.net/synchronize.html): a command line tool that has the same functionality as Cockpit but runs in headless mode. This is great if you want to schedule backups (using *cron* or similar) or just want a simple - single command - way of synching up the data. 

Good stuff. Perhaps not ultimate, but I am happy for now.

Another thing that I have found very useful in S3 is the possibility of creating public URLs or Torrents that can be made available for a specific amount of time. This is very useful if you want to share files with friends. We even use this feature at [Terracotta](http://terracotta.org/) to host the distribution of our downloads. 

Thoughts? Can it be improved?

----
**Update:** [Geert Bevin](http://rifers.org/blogs) pointed me to the [js3tream](http://js3tream.sourceforge.net/) project. It plays nicely with standard shell tools such as *tar*, *gzip*, piping etc.: 
<pre>
tar -C / -czpO /etc | java -jar js3tream.jar -K mykey.txt \
-b mybucket:etc.tgz -i -t "An archive of my /etc directory"
</pre>
According to Geert it is working fine. I have to try it out.  
