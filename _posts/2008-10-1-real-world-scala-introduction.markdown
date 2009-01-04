--- 
wordpress_id: 159
layout: post
title: "Real-World Scala: Introduction"
wordpress_url: http://jonasboner.com/2008/10/01/real-world-scala-introduction/
---
The last nine months I have been running my own business together with some friends (<a href="http://www.triental.com/">Triental AB</a>). We are building a product suite for private banking and wealth management with a focus on portfolio management, analysis and simulation. 

One of the great things of being your own is that you get to choose whatever technology you like and think is best suitable for the job. The last years I have been studying and playing with Functional Programming (FP) in general and <a href="http://www.scala-lang.org/">Scala</a> in particular (among with Erlang, Clojure and Haskell). FP has been used successfully in the financial domain before (for example <a href="http://ocaml.janestcapital.com/">Jane Street Capital (OCaml)</a> and <a href="http://labs.businessobjects.com/cal/">Business Objects (CAL)</a>), and the work we do is heavily based on mathematics which maps excellent to the FP paradigm. 

Apart from the FP properties (such as immutability, high-order functions, closures etc.) Scala also have some other interesting properties such as: 

* Mixin composition (enables creation of components build up of reusable fragments, even runtime composition) 
* Actors library (message-passing concurrency, an easy way of parallelizing long-running computations and simulations out on multi-core or SMP machines)
* Flexible syntax with decent type inference (high productivity, great for DSLs etc.)
* Statically typed (fast, in most cases as fast as Java)
* Pattern matching
* Seamless interoperability with Java
* and much much more

So I decided to try use FP and Scala for real.

By choosing to base the development on FP and a new and fairly unproven (at least in the industry) language like Scala, we were exposing ourselves to two main risks: 

* Technology: will the technology deliver, can we fix or work around the problems that will emerge down the road etc.?
* Education: will the process and time needed to be invested in learning a new language and paradigm slow us down too much?

And will the benefit of using it in terms of:

* higher productivity,
* cleaner, more stable and more reusable code, and
* more fun 

outweigh the potential risks and upfront time (and money) investment? 

To be honest, the trip has been a bit bumpy sometimes, but now after nine months of development I can say that Scala pulled it off. Both of these risks were manageable. We are very happy with the strategic decision to use Scala. 

Technology-wise, one of the biggest problems of using Scala in a JEE application stack is that there are (currently) no frameworks, patterns or "best-practices" that will help you address fundamental issues like: 

* Dependency Injection (DI)
* Code tangling and scattering e.g. AOP
* Transaction demarcation and context propagation
* Component life-cycle

Basically, we didn't have a "container" that could handle this for us so we had to write it ourselves. The good thing is that most Java frameworks works very nicely with Scala. For example, we have had using no problems using JPA, Wicket etc. and deploy it in a standard JEE appserver. 

Regarding the second risk; education, it turned out to not be much of an issue. Our developers who had never written a line in Scala and had very little experience with FP in general were fully up to speed in a couple of months. The first weeks there were some complaints but now they are loving it. Scala gives a smooth learning curve to FP since it, being a unique blend of the OO and FP paradigms, allows one to start with a very Java-esque imperative style of programming and gradually move towards a functional style. Now we have rewritten most of the imperative chunks of code that were written during the early education stages. 

This is the first post in a series of articles in which I will try to explain how we are bridging the "Scala <--> Real-World" gap. I have to stress that these are by no means the only way to do things and perhaps not the best way of doing things, but simply the way we have solved our problems and what work for us. Hopefully it will also work for you. 

For those that are interested here is a list of the Scala frameworks that we are currently using: 

* Scala (for the domain model, persistence layer, service layer, facade layer and container code)
* <a href="http://www.lag.net/configgy/">Configgy</a> (logging and configuration)
* <a href="http://github.com/jboner/scala-otp/tree/master">Scala OTP</a> (actor management)
* <a href="http://liftweb.net">Lift</a> (misc util)
* <a href="http://scalax.scalaforge.org/">scalax</a> (misc util)
* <a href="http://www.artima.com/scalatest/">ScalaTest</a> (testing)
* <a href="http://code.google.com/p/scalacheck/">ScalaCheck</a> (testing)

The rest is a fairly standard Java stack: 

* Wicket
* Hibernate (JPA)
* Atomikos (JTA)
* Terracotta
* Wicket-Push (Cometd)
* Dojo
* AspectJ
* XStream
* TestNG
* DBUnit
* EasyMock
* MySQL
* Jetty
* Maven
* Hudson

The topics I am planning on covering are: 

* Dependency Injection
* AOP
* Transaction demarcation (JTA) and context propagation
* Asynchronous event-driven components
* ORM (JPA)

Stay tuned for the next article. 
