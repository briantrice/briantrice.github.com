--- 
wordpress_id: 151
layout: post
title: "Oredev 2007: BDD, LINQ, Scalability trends etc."
wordpress_url: http://jonasboner.com/2007/11/17/oredev-2007-bdd-linq-terracotta-etc/
---
I had the pleasure of attending <a href="http://oredev.org">Oredev</a> last month. This was a great conference. I have attended this conference three years in a row and it's getting better and better every year. 

This year they had a great speaker lineup and I was able to catch some very interesting talks. Among the most memorable ones were <a href="http://dannorth.net/">Dan North</a>'s keynote about why "Best Practices" in software development are neither "Best" no "Practices". I also attended Dan's talk on BDD (<a href="http://behaviour-driven.org/">Behavior-Driven
Development</a>). Great talk. I find BDD very interesting, it feels like the natural extension of, or complement to TDD (Test-Drived Development) in that it focuses on getting complete concept coverage in the tests instead of code coverage (as in TDD). 

Other great talks were <a href="http://blog.toolshed.com/">Andy Hunt</a>'s (Pragmatic Programmers) keynote and <a href="http://research.microsoft.com/~emeijer/">Erik Meijer</a>'s talk on <a href="http://msdn2.microsoft.com/en-us/netframework/aa904594.aspx">LINQ</a>. The latter one was fun to watch, Erik (undeliberately it felt like) turned it more or less into a praise of <a href="http://haskell.org">Haskell</a>; how they have stolen all the good stuff in LINQ from Haskell and that the world would be a better place if everyone just used Haskell. 

My talk on <a href="http://terracotta.org">Terracotta</a> was able to attract quite a lot of attendees. One of the most interesting things was when I asked them, at the end of the talk, how many could see immediate need for something like Terracotta in their daily work roughly 80% raise their hands. I find this quite amazing and is actually something that have been consistent during last half year. I remember when I started asking this question, around 2 years ago, roughly 5-10 % raised their hands. This is quite a drastic change. Since I know that we were facing the same problems with scalability and HA a couple of years as we do now, I guess this is a sign of that the awareness of clustering, persistent and durable RAM and similar services has increased; that people have started to consider writing stateful applications with rich domain models - which implies another solution to HA and scalability than Oracle RAC and similar. 

However, the best thing was that the conference had invited one of the best coffee shops in Malmo to serve all speakers unlimited amount of caffeine in the form of espresso, cafe latte, machiatto or whatever was asked for. I paid them 4-5 visits every day.


