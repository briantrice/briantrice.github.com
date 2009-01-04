--- 
wordpress_id: 35
layout: post
title: "Nordev 2005: Rickard on real world use-cases for AOP etc."
wordpress_url: http://jonasboner.com/?p=35
---
I just got back from the Nordic Software Developer Summit (Nordev) 2005.  Strange enough, this is the first good developer conference that we have had in Sweden.  

Altogether it was a really good event with two major tracks, one Java and one .Net. The Java track had interesting talks on topics like: AOP :-), agile development, hibernate, spring, manageability of the JRockit JVM etc. (e.g. the usual suspects).

I was glad to see that AOP got a lot of focus with talks from myself and Rickard Oberg and a hands-on workshop (on AspectJ).  Both sessions were packed, and people seemed enthusiastic about it.   

Of all things you can be nervous about, I was nervous about speaking in Swedish (my native language).  I had never spoken about AOP in Swedish so it was interesting and a good exercise :-).  Everything went pretty well except that eclipse died on me when I was starting up the demo (3.1 M6). (The demo was about how to write a unit of work to achieve transparent persistence/replication/transaction management, perhaps something for an upcoming blog post...).

I enjoyed Rickard's talk.  He based the talk on examples from the CMS application and he has built, and it was interesting to see both simple and advanced usage of AOP in the real world application.  He's using a pretty extreme approach to AOP in which every single object is built up a using intertype declarations (introductions/mixins).  I do not think that this model fits every project, and it for sure has drawbacks, but in their CMS application it has given them extremely high reuse and development speed.

He showed examples of client aspects, how objects can render themselves differently based on which intertype declarations it has.  For example, if an object in their GUI (a page, a site, a portlet etc.) has the intertype declaration ACL applied to it then it will give you the possibility to open up a window to manage security for this object. This object can also be given the Tree intertype declaration, which will allow you to browse the object in a tree structure etc.

He also showed examples on how they do client synchronization and cluster wide replication, using the same aspect (which simply records the events triggered and then plays it back).  Another interesting aspect that they have is what he calls partial object versioning, in which intertype declarations can be versioned and different versions can be used (in the same object), depending on how system is configured. 

Rickard gave an example of a customer that came in with a new functional requirements very late in the release cycle, requirements that required redesign of some parts of the system, but that he managed to solve in a simple and generic way by applying an aspect.

Then he talked about the need for tools and that most problems that people are complaining about when it comes to AOP are actually not related to AOP, but to the lack of good tools. He showed one interesting tool that they are using on a daily basis, a tool for doing a diff of the system.  This diff showed you which advice and or intertype declarations had been removed or added since the last time the system's state was recorded. For example, after a regular refactoring, the diff should be zero.  This is something that we should add to AJDT.

All and all a good conference, you should try to get there next year.
