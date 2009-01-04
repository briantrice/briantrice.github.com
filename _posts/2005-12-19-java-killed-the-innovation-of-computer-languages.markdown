--- 
wordpress_id: 74
layout: post
title: Java Killed The Innovation Of Computer Languages
wordpress_url: http://jonasboner.com/?p=74
---
I had a very interesting discussion with <a href="http://chris-richardson.blog-city.com/">Chris Richardson</a> at the <a href="http://thespringexperience.com">Spring Experience</a> conference last week. Chris is an old <a href="http://en.wikipedia.org/wiki/Lisp_programming_language">Lisp</a> hacker and used to write Lisp compilers and VMs before switching to Java about 10 years ago.

Here are some quotes from Chris that I find particularly interesting:
<blockquote>Java killed the innovation of computer languages.</blockquote>
<blockquote>AspectJ is one of the few innovations in computer languages the last years.</blockquote>
Some comments on these statements:

<a href="http://en.wikipedia.org/wiki/Java_programming_language">Java</a> has had an enormous impact on enterprise application development the last 10 years and I do believe that Chris is right, it has to some extent "killed the innovation of computer languages" (considering commercially used and widely adopted languages). Sure, <a href="http://en.wikipedia.org/wiki/C_Sharp">C#</a> have some more or less innovative ideas (sometimes I wish I was a .NET developer) and Microsoft is doing some very cool stuff it the labs. But in general nothing has really happened the last 10 years. We have seen many new scripting languages popping up lately (Ruby, Python, Jython, groovy etc.) and even though most of them are both fun and useful - non of them are really innovating, merely reusing and sometimes reshaping old ideas (not saying that that is not enough - most of these languages has contributed tremendously on many ways).

While this is true for commercially adopted languages (for enterprise application, desktop development etc.), things are fortunately different in the academic field and in the labs. The problem here is that not enough effort is made to, wrap up the ideas in something that is (at least to some exent) easy to use, and/or to meet real-world needs of scalability, maintainability, interoperability etc. (due to lack of money or lack of interest?).

For example, one language that I have been playing with on and off the last years is the <a href="http://www.mozart-oz.org/">Mozart Programming System</a> and its language Oz. Working with it is (as they say themselves) in some ways pure magic. It is an hybrid between object-oriented, functional and declarative languages which is very powerful. It supports high-performant network-transparent distribution (no difference between writing an app for one node or many) transparent sharing of classes, objects, variables, procedures etc., as well as real data-flow threads. It has build-in Separation of Concerns, allowing you to declaratively, in different modules, implement f.e. security, fault handling etc. (I should write a blog post about it later.)

But the problem is that it is so hard to use (at least for someone like me, that has been doing Java and C the last 10 years), that simply reaching the stage of being able to start playing with it for real takes more time than most people are willing to spend. However, I really encourage you to spend some time learning it.

I am biased, but I do think that <a href="http://eclipse.org/aspectj/">AspectJ</a> is one of the few really innovating languages that has made it out of the reseach labs into the enterprise without having to do trade-offs between innovation, power, coherent semantics and ease of use.

Some questions to chew on:
<ul>
	<li>What are the requirements for a modern computer language that addresses real-world needs in the enterprise (thinking outside the box)?</li>
	<li>What does it take to replace Java (meaning the language, not the platform)?</li>
	<li>Is it likely to happen within the next 10 years?</li>
	<li>Is it even necessary?</li>
	<li>Which are the most important lessons we have learned?</li>
	<li>Will the next generation computer languages for enterprise development be build upon the Java Platform (JVM)?</li>
	<li>Which role [can/will/do we want] the academic research to play?</li>
	<li>Are we willing to trade <em>Innovation</em> (and potential long term benefits) for <em>Pragmatism</em> and <em>Ease-Of-Use</em> (meaning short term benefits)?</li>
</ul>
