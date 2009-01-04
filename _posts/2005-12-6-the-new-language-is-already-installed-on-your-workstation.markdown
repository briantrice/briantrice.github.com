--- 
wordpress_id: 73
layout: post
title: The "New Language" Is Already Installed On Your Workstation
wordpress_url: http://jonasboner.com/?p=73
---
Victoria Livshitz is <a href="http://www.theserverside.com/news/thread.tss?thread_id=37922">"Envisioning a New Language"</a>, it is an interesting read and I find this quote particulary interesting:  

<blockquote>
Give the local virtual machine (LVM) the ability to act as a container for managed application code. Create a virtual machine and distributed runtime environment that in principle subsume the functionality of the application containers and middleware. While retaining middleware from an interoperability standpoint, the basic needs of distributed applications, such as load balancing, failover, remote communications, mobility of services and their containers, quality of service, and service-level management, should be embedded into a runtime environment for the language
</blockquote>

This is actually what we are doing at <a href="http://www.terracottatech.com/">Terracotta</a>  in our <a href="http://www.terracottatech.com/product/dso.html">Distributed Shared Objects (DSO)</a> technology.

But instead of inventing a new languague (or introducing new APIs), we are using the APIs and bytecode instructions that we already have in Java and instead extending their semantics, in order to have Plain Java code, written for a single VM, work correctly (and scale) in a distributed environment.

So I would say that the "New Language" is already installed on your workstation...and it is called Java, it just needs to be boosted up some... ;)  
