--- 
wordpress_id: 36
layout: post
title: JVM support for AOP (technical session at JavaOne 2005)
wordpress_url: http://jonasboner.com/?p=36
---
If you're interested in knowing more about what the future holds for AOP, then you should come to the technical session TS-7659 (titled "Runtime Aspects With JVM Support") on Tuesday, June 28 at JavaOne 2005.

This will be the first time ever to show an enterprise JVM - BEA JRockit - with native AOP support. Alex Vasseur and myself have been pushing for this idea since the early days of AspectWerkz when we joined the JRockit group, and it's finally taking shape, with now support for AspectJ 5, the de-facto standard for AOP in Java.

Credit should also go to Joakim Dahlstedt, the CTO of JRockit, who has been playing a leading role in the design and implementation.

We will talk about the current problems with bytecode based weaving (multiple agents, double bookkeeping, performance etc.) and then discuss how these problems can be solved through native JVM support. We will show a prototype of our implementation, go through the programming model and run a live demo.

Here is the abstract:

"Aspect Oriented Programming (AOP) is growing in popularity. Adding aspects at runtime, dynamic weaving, can be a very powerful technique for diagnostics, profiling, or debugging of a running system. The concept of adding aspects at runtime (dynamic weaving) is looked upon with skepticism by some. It's also easy for multiple instrumenting agents to cause havoc for each other. We have implemented prototype changes to our Javaâ„¢ Virtual Machine (JVMâ„¢ software), BEA Weblogic JRockit, to support dynamic weaving in the JVM software in a controlled fashion. We also have modified AspectJ 5 to try out this functionality. We believe our changes to the JVM software to support dynamic weaving lessens the skepticism about runtime aspects and allows for multiple instrumenting agents to coexist.
In this session we present the changes we made to the JVM software to support this functionality and the results of this effort. In addition, we compare this approach to current approaches like JVMTI/Hotswap and Project JFluid. Finally, we provide a demonstration of various runtime advice you'll find useful to analyze the behavior of your applications."

Don't miss it, see you there.
