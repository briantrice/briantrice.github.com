--- 
wordpress_id: 72
layout: post
title: Transparently Clustered Spring @ The Spring Experience
wordpress_url: http://jonasboner.com/?p=72
---
I am heading down to Miami and <a href="http://thespringexperience.com">The Spring Experience</a> conference to do a talk on <a href="http://thespringexperience.com/speaker_topic_view.jsp?topicId=206">Transparently Clustered Spring</a>. 

Basically it is talk about how you can use <a href="https://www.terracottatech.com">Terracotta </a>'s DSO technology to cluster your regular Spring applications <strong>Transparently</strong>, in order to get, better scalability, HA (High Availability), Fail-Over etc. 

The talk will be demo-driven (5 demos) showing among other things:


<ul>
<li>how to make Spring Bean's lifecycles and state mean the same thing on a cluster as on a single node (e.g. clustered, but local to the same ApplicationContext)
</li>
<li>how to turn Spring's ApplicationContext Events into distributed events (but still local within the same ApplicationContext)
</li>
<li>how to avoid using regular messaging and simplify the programming model by:
<ul>
<li>turning arbitrary method invocations into asynchronous distributed events
</li>
<li>use a regular java.util.List or java.util.Queue as a message queue (point-to-point or publish-subscribe)
</li>
</ul>
</li> 
<li>and more...
</li>
</ul>

I hope to see you there.  :)
