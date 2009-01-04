--- 
wordpress_id: 136
layout: post
title: "Distributed Continuations for Java: RIFE and Open Terracotta"
wordpress_url: http://jonasboner.com/2007/04/16/distributed-continuations-for-java-rife-and-open-terracotta/
---
The last couple of years we have seen a new generation of Web frameworks with the ability to keep and maintain user specific conversational (stateful) state emerge in the enterprise. Among all these, I think that <a href="http://rifers.org/">RIFE</a> is one of the most interesting ones. It has a rich and coherent model for rapid development of Web applications. It also has its unique concept of continuations which provides a both rich, simplistic and intuitive programming model for implementing conversational workflows - a concept I think is applicable to a wide range of use-cases and technology areas, even outside Web development. 

But the question is, how can we scale-out and ensure high-availability of these continuation based applications - and how can we do that while preserving its simplicity and semantics? It is here the recent collaboration between RIFE and <a href="http://terracotta.org/">Open Terracotta</a> really shines. Open Terracotta does not force you to choose between simplicity and scale-out, but its JVM-level clustering allows RIFE applications to remain simple and pure POJO based while still getting all the advantages of unlimited scale-out and high-availability. 

It is important to understand that <a href="http://rifers.org/wiki/display/RIFECNT/Home">RIFE Continuations</a> is a completely stand-alone library (which can be used outside RIFE to implement all kinds of interesting stuff, from the declarative workflow used in RIFE itself to thread migration across JVMs (if used with Open Terracotta which can be used with solely the continuation library if needed). These ideas are currently being formalized into a <a href="http://rifers.org/wiki/display/RIFECNT/JSR+Continuations+Provider+API">JSR draft</a> that have been submitted to the JCP, which - if accepted - would bring this very powerful concept into the JVM (or at least the JDK - depending on how it is implemented). 

I am very excited about the work that I have had the opportunity to do with <a href="http://rifers.org/blogs/gbevin">Geert Bevin</a> in order to make this happen and think (and hope) that:

<ul>
<li>RIFE and Open Terracotta will be the number one application stack of choice for future enterprise Java web deployments.
</li>
<li>Continuations in general will be better understood and get more traction in the Java space and help to continue to push the limits of Java. 
</li>
</ul>

The upcoming release of Open Terracotta will include a sample application with RIFE continuations clustered. But if you don't want to wait you should be able to grab the latest sources from the RIFE and Open Terracotta SVN repositories build and run it yourself. 

Enjoy.
