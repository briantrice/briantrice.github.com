--- 
wordpress_id: 132
layout: post
title: How to Build a POJO-based Data Grid using Open Terracotta
excerpt: <p>In this article, I will show you step by step how you can build a reusable POJO-based <em>Data Grid</em> with nothing but standard JDK 1.5 and then make it distributed through the use of the declarative JVM-level clustering technology provided by <a href="http://terracotta.org">Open Terracotta</a>.</p>
wordpress_url: http://jonasboner.com/2007/01/29/how-to-build-a-pojo-based-data-grid-using-open-terracotta/
---
# Introduction

In this article, I will show you step by step how you can build a reusable POJO-based _Data Grid_ with nothing but standard JDK 1.5 and then make it distributed through the use of the declarative JVM-level clustering technology provided by [Open Terracotta](http://terracotta.org).

The article is divided into three sections:

1. In the first section I will talk about the concepts of _Data Grids_, what they are and what they do. I will discuss some of the underlying mechanisms that are used in _Data Grids_ and finally how one can scale out applications on a _Data Grid_. 
1. The second section will walk you through how to build a naive but fully usable implementation of a POJO-based _Data Grid_ by implementing a multi-threaded _Master/Worker_ container and cluster it using [Terracotta's JVM-level clustering technologies](http://terracotta.org). 
1. Last, in the third section I will show you how to extend the initial implementation to handle real-world requirements such as dealing with; high volumes of data, work failure, different routing algorithms, ordering of work and worker failure.

# Part 1: Data Grids - What's behind the buzzwords?

## What are Data Grids?

A _Data Grid_ is a set of servers that together creates a mainframe-class processing service where data and operations can move seamlessly across the grid in order to optimize the performance and scalability of the computing tasks submitted to the grid. A _Data Grid_ scales through use of [Locality of Reference](http://en.wikipedia.org/wiki/Locality_of_reference) (see the section "How do Data Grids scale?") and is highly-available through effective use of data duplication. It combines data management with data processing. 


## What are Data Grids used for?

Applications that could benefit from being run on a _Data Grid_ are usually applications that needs to work on large data sets and/or have a need to parallelize processing of the data in order to get better throughput and performance. Examples are financial risk analysis and other simulations, searching and aggregation on large datasets as well as sales order pipeline processing.


## How do Data Grids scale?

One of the main reasons why _Data Grids_ can scale so well is that they can make intelligent choices if it should move data to its processing context or moved the processing context (the operations) to the data. Effective use of the latter means that it can make use of _Locality of Reference_; this means that data that is being processed on a specific node stays local to that node and will in the ideal case never have to leave that node. Instead, all operations that are working on this specific data set will always be routed to this specific node. 

The immediate benefits are that it has the advantage of minimizing the latency and can in the ideal case give unlimited and linear scalability. How well it scales is of course use-case specific, and it can take both effort and skills in partitioning the data and work sets, as well as potential routing algorithms. The ultimate (and simplest) situation is when all work are what we call [Embarrassingly Parallel](http://en.wikipedia.org/wiki/Embarrassingly_parallel) - which means that it has no shared state and can to its working complete isolation. But it is in most cases acceptable to partition the work into _work sets_, in such a way that the _work sets_ have no shared state. However, the latter solution might need some intelligent routing algorithms, something that we will take a look at later.


## How do Data Grids deal with failure?

_Data Grids_ are resilient to failure and down time by effective use of data duplication. _Data Grids_ can be seen as an organic system of cells (nodes) that is designed to not only handle, but expect failure of individual cells (nodes). This is very different from traditional design of distributed systems in which each node is seen as an isolated unit which must always expect the worst and protect itself accordingly. See [this page](http://www.artima.com/forums/flat.jsp?forum=106&thread=172063) for a more thorough discussion on the subject. 


# Part 2: Build a multi-threaded Master/Worker container and cluster it with Open Terracotta

<img src="http://www.jonasboner.com/images/master_worker.jpg" alt="Master/Worker algorithm" align="right"/>

## What is the Master/Worker pattern?

The _Master/Worker_ pattern is a pattern that is heavily used in _Data Grids_ and is one of the most well-known and common patterns for parallelizing work. We will now explain the characteristics of the pattern and then go through the possible approaches for a Java implementation.

So, how does it work? 

The _Master/Worker_ pattern consists of three logical entities: a _Master_, a _Shared Space_ and one or more instances of a _Worker_. The _Master_ initiates the computation by creating a set of tasks, puts them in some shared space and then waits for the tasks to be picked up and completed by the _Workers_. The shared space is usually some sort of _Shared Queue_, but it can also be implemented as a _Tuple Space_ (for example in Linda programming environments, such as JavaSpaces, where the pattern is used extensively). One of the advantages of using this pattern is that the algorithm automatically balances the load. This is possible due to the simple fact that, the work set is shared, and the workers continue to pull work from the set until there is no more work to be done. The algorithm usually has good scalability as long as the number of tasks, by far exceeds the number of workers and if the tasks take a fairly similar amount of time to complete.


## Possible approaches in Java

Let's now look at the different alternatives we have for implementing this in Java. There might be more ways of doing it, but we will focus the discussion on three different alternatives, each one with a higher abstraction level.

### Using Java's threading primitives

The most hard-core approach is to use the concurrency and threading primitives that we have in the _Java Language Specification_ (JLS), e.g. _wait/notify_ and the _synchronized_ and _volatile_ keywords. The benefits are that everything is really "under your fingers", meaning that you could customize the solution without limitations.  However, this is also its main problem, since it is both a very hard and tedious to implement this yourself, and will most likely be even worse to maintain.  These low-level abstractions is not something that you want to work with on a day-to-day basis.  We need to raise the abstractions level above the core primitives in the _Java Memory Model_ and that is exactly what the data structure abstractions in the _java.util.concurrent_ library in JDK 1.5 does for us. 

### Using the java.util.concurrent abstractions

Given that using the low-level abstractions in JLS is both tedious and hard to use, the concurrency abstractions in JDK 1.5 was both a very welcome and natural addition to the Java libraries. It is a very rich API that provides everything from semaphores and barriers to implementations of the Java Collections data structure interfaces highly tuned for concurrent access. It also provides an _ExecutorService_, which is mainly a thread pool that provides direct support for the _Master/Worker_ pattern. This is very powerful, since you're basically getting support from the _Master/Worker_ pattern in a single abstraction. 

It is possible to cluster the _ExecutorService_ using _Terracotta_, you can read about that exercise in [this article](http://www.theserverside.com/tt/articles/article.tss?l=DistCompute). Even though this approach would be sufficient in many situations and use-cases it has some problems:

* First, it does not separate the master from the worker (since they are both part of the same abstraction). What this means in practice is that you cannot scale out that the master independently of the worker but each node will contain both a master and a worker. 

* Second, and perhaps even more important, is that it is lacking a layer of reliability and control.  Meaning that it is no way of knowing if a specific work task has been started, completed or if it has been rejected due to some error.  This means that there is no way we can detect work failure and can retry the work task on the same node or on another node. So we need a way to deal with these things in a simple and if possible standardized way. 

### Using the CommonJ WorkManager specification

Spawning and coordinating threads is something that have been prohibited by the EJB specification.  However, there has naturally been (and still is) a common need for coordinating work in JEE (something that was partly, but not completely solved in a very verbose way with _Message-Driven Beans_ (MDB)).  This need was the main motivation why IBM and BEA decided to do a joint specification that solves this problem by providing a standardized way of executing concurrent tasks in a JEE environment. The specification is called _CommonJ_ and has support for the _Master/Worker_ pattern in its _WorkManager_ API.

From BEA's documentation about the specification:
> "The Work Manager provides a simple API for application-server-supported concurrent execution of work items. This enables J2EE-based applications (including Servlets and EJBs) to schedule work items for concurrent execution, which will provide greater throughput and increased response time. After an application submits work items to a Work Manager for concurrent execution, the application can gather the results. The Work Manager provides common "join" operations, such as waiting for any or all work items to complete. The Work Manager for Application Servers specification provides an application-server-supported alternative to using lower-level threading APIs, which are inappropriate for use in managed environments such as Servlets and EJBs, as well as being too difficult to use for most applications."


What is interesting is that specification not only defines an API for submitting work and getting the result back, but it also provides functionality for tracking work status in that it allows you to register listener that will receive callback events whenever the state of the work has been changed. This makes it possible to for example not only detect work failure but also the reason why it failed, which gives us a possibility of restarting the work.

Each of the three approaches we have looked at so far have been built upon the previous one and has gradually raised the abstraction level. But even more importantly minimized and simplified the code that we as users have to write and maintain. 

The most natural choice is to base our implementation on the _CommonJ WorkManager_ specification. It is a simple and minimalistic specification and seems to provide everything that we need in order to build a reliable _Master/Worker_ container.

Here are the interfaces in the specification:
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">Work</span> <span class="meta meta_definition meta_definition_class meta_definition_class_extends meta_definition_class_extends_java"></span><span class="storage storage_modifier storage_modifier_java">extends</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">Runnable</span> { }

<span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkManager</span> {
  <span class="storage storage_type storage_type_java">WorkItem</span> schedule(<span class="storage storage_type storage_type_java">Work</span> work);
  <span class="storage storage_type storage_type_java">WorkItem</span> schedule(<span class="storage storage_type storage_type_java">Work</span> work, <span class="storage storage_type storage_type_java">WorkListener</span> listener);
  <span class="storage storage_type storage_type_java">boolean</span> waitForAll(<span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> workItems, <span class="storage storage_type storage_type_java">long</span> timeout);
  <span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> waitForAny(<span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> workItems, <span class="storage storage_type storage_type_java">long</span> timeout);
}

<span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkItem</span> {
  <span class="storage storage_type storage_type_java">Work</span> getResult();
  <span class="storage storage_type storage_type_java">int</span> getStatus();
}

<span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkListener</span> {
  <span class="storage storage_type storage_type_java">void</span> workAccepted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workRejected(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workStarted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workCompleted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
}

<span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkEvent</span> {
  <span class="storage storage_type storage_type_java">int</span> <span class="constant constant_other constant_other_java">WORK_ACCEPTED</span>  = <span class="constant constant_numeric constant_numeric_java">1</span>;
  <span class="storage storage_type storage_type_java">int</span> <span class="constant constant_other constant_other_java">WORK_REJECTED</span>  = <span class="constant constant_numeric constant_numeric_java">2</span>;
  <span class="storage storage_type storage_type_java">int</span> <span class="constant constant_other constant_other_java">WORK_STARTED</span>   = <span class="constant constant_numeric constant_numeric_java">3</span>;
  <span class="storage storage_type storage_type_java">int</span> <span class="constant constant_other constant_other_java">WORK_COMPLETED</span> = <span class="constant constant_numeric constant_numeric_java">4</span>;
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="storage storage_type storage_type_java">int</span> getType();
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="storage storage_type storage_type_java">WorkItem</span> getWorkItem();
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="storage storage_type storage_type_java">WorkException</span> getException();
}
</pre>



## The Plan

The plan is that we will first implement the specification as a regular multi-threaded application using the _java.util.concurrent_ abstractions (in particular the _ExecutorService_ and the _LinkedBlockingQueue_ classes) and then use _Open Terracotta_ to declaratively (and transparently), turn it into a multi-JVM, distributed implementation.


## Creating the Master (WorkManager)

We start with creating the _SingleQueueWorkManager_, which serves as our _Master._ It implements the _CommonJ WorkManager_ interface which provides the API that the user uses to schedule the _Work_ and wait for the _Work_ to be completed. It has a reference to the work queue that is shared between the _Master_ and the _Workers_, in this case represented by the _SingleWorkQueue_ abstraction.

Here is how we could implement the work manager:
<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">SingleQueueWorkManager</span> <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">WorkManager</span> {

  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">SingleWorkQueue</span> m_queue;

<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">SingleQueueWorkManager</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">SingleWorkQueue</span> queue) {
    m_queue = queue;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">WorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">schedule</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work) <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="storage storage_type storage_type_java">DefaultWorkItem</span> workItem = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkItem</span>(work, <span class="constant constant_language constant_language_java">null</span>);
    m_queue.put(workItem);
    <span class="keyword keyword_control keyword_control_java">return</span> workItem;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">WorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">schedule</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work, final <span class="storage storage_type storage_type_java">WorkListener</span> listener)
      <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="storage storage_type storage_type_java">DefaultWorkItem</span> workItem = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkItem</span>(work, listener);
    m_queue.put(workItem);
    <span class="keyword keyword_control keyword_control_java">return</span> workItem;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">boolean</span> <span class="entity entity_name entity_name_function entity_name_function_java">waitForAll</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> workItems, <span class="storage storage_type storage_type_java">long</span> timeout) {
    <span class="storage storage_type storage_type_java">long</span> start = <span class="support support_type support_type_built-ins support_type_built-ins_java">System</span>.currentTimeMillis();
    <span class="keyword keyword_control keyword_control_java">do</span> {
      <span class="storage storage_type storage_type_java">boolean</span> isAllCompleted = <span class="constant constant_language constant_language_java">true</span>;
      <span class="keyword keyword_control keyword_control_java">for</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">Iterator</span> it = workItems.iterator();
           it.hasNext() <span class="keyword keyword_operator keyword_operator_logical keyword_operator_logical_java">&amp;&amp;</span> isAllCompleted;) {
        <span class="storage storage_type storage_type_java">int</span> status = ((<span class="storage storage_type storage_type_java">WorkItem</span>) it.next()).getStatus();
        isAllCompleted =
            status <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_COMPLETED</span> ](](
            status <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>;
      }
      <span class="keyword keyword_control keyword_control_java">if</span> (isAllCompleted) { <span class="keyword keyword_control keyword_control_java">return</span> <span class="constant constant_language constant_language_java">true</span>; }
      <span class="keyword keyword_control keyword_control_java">if</span> (timeout <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="constant constant_other constant_other_java">IMMEDIATE</span>) { <span class="keyword keyword_control keyword_control_java">return</span> <span class="constant constant_language constant_language_java">false</span>; }
      <span class="keyword keyword_control keyword_control_java">if</span> (timeout <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="constant constant_other constant_other_java">INDEFINITE</span>) { <span class="keyword keyword_control keyword_control_java">continue</span>; }
    } <span class="keyword keyword_control keyword_control_java">while</span> ((<span class="support support_type support_type_built-ins support_type_built-ins_java">System</span>.currentTimeMillis() <span class="keyword keyword_operator keyword_operator_arithmetic keyword_operator_arithmetic_java">-</span> start) <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span> timeout);
    <span class="keyword keyword_control keyword_control_java">return</span> <span class="constant constant_language constant_language_java">false</span>;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">Collection</span> <span class="entity entity_name entity_name_function entity_name_function_java">waitForAny</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> workItems, <span class="storage storage_type storage_type_java">long</span> timeout) {
    <span class="storage storage_type storage_type_java">long</span> start = <span class="support support_type support_type_built-ins support_type_built-ins_java">System</span>.currentTimeMillis();
    <span class="keyword keyword_control keyword_control_java">do</span> {
      <span class="storage storage_modifier storage_modifier_java">synchronized</span> (<span class="variable variable_language variable_language_java">this</span>) {
        <span class="support support_type support_type_built-ins support_type_built-ins_java">Collection</span> completed = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">ArrayList</span>();
        <span class="keyword keyword_control keyword_control_java">for</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">Iterator</span> it = workItems.iterator(); it.hasNext();) {
          <span class="storage storage_type storage_type_java">WorkItem</span> workItem = (<span class="storage storage_type storage_type_java">WorkItem</span>) it.next();
          <span class="keyword keyword_control keyword_control_java">if</span> (workItem.getStatus() <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_COMPLETED</span> ](](
              workItem.getStatus() <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>) {
            completed.add(workItem);
          }
        }
        <span class="keyword keyword_control keyword_control_java">if</span> (<span class="keyword keyword_operator keyword_operator_logical keyword_operator_logical_java">!</span>completed.isEmpty()) { <span class="keyword keyword_control keyword_control_java">return</span> completed; }
      }
      <span class="keyword keyword_control keyword_control_java">if</span> (timeout <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="constant constant_other constant_other_java">IMMEDIATE</span>) { <span class="keyword keyword_control keyword_control_java">return</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">Collections</span>.<span class="constant constant_other constant_other_java">EMPTY_LIST</span>; }
      <span class="keyword keyword_control keyword_control_java">if</span> (timeout <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">==</span> <span class="constant constant_other constant_other_java">INDEFINITE</span>) { <span class="keyword keyword_control keyword_control_java">continue</span>; }
    } <span class="keyword keyword_control keyword_control_java">while</span> ((<span class="support support_type support_type_built-ins support_type_built-ins_java">System</span>.currentTimeMillis() <span class="keyword keyword_operator keyword_operator_arithmetic keyword_operator_arithmetic_java">-</span> start) <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span> timeout);
    <span class="keyword keyword_control keyword_control_java">return</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">Collections</span>.<span class="constant constant_other constant_other_java">EMPTY_LIST</span>;
  }
}
</pre>

    
## Creating the Shared Queue

The _SingleQueueWorkManager_ schedules work by adding work to the _SingleWorkQueue_. The _SingleWorkQueue_ is the artifact that has state that needs to be shared between the _Master_ and the _Workers_, since it holds the queue with all the pending _Work_. We need to have a single instance of this queue that can be available to both the _Master_ and all its _Workers_.

The work queue can be implemented like this:
<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">SingleWorkQueue</span> {

  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> Terracotta Shared Root
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span> m_workQueue =
      <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">LinkedBlockingQueue</span>();

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">put</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">DefaultWorkItem</span> workItem) <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
      m_workQueue.put(workItem); <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> blocks if queue is full
    } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">InterruptedException</span> e) {
      e.printStackTrace();
      <span class="storage storage_type storage_type_java">WorkRejectedException</span> we = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkRejectedException</span>(e.getMessage());
      workItem.setStatus(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>, we);
      <span class="support support_type support_type_built-ins support_type_built-ins_java">Thread</span>.currentThread().interrupt();
      <span class="keyword keyword_control keyword_control_java">return</span> we;            }
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">DefaultWorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">peek</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="keyword keyword_control keyword_control_java">return</span> m_workQueue.peek(); <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> returns null if queue is empty
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">DefaultWorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">take</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
      <span class="keyword keyword_control keyword_control_java">return</span> m_workQueue.take(); <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> blocks if queue is empty
    } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">InterruptedException</span> e) {
      <span class="support support_type support_type_built-ins support_type_built-ins_java">Thread</span>.currentThread().interrupt();
      <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">throw</span> <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkException</span>(e);
    }
  }
}
</pre>

As you can see, it is a simple wrapper around a _java.util.concurrent.BlockingQueue_ queue and has three methods; _take(), put()_ and _peek()_ which simply delegates to the _BlockingQueue_ but also adds error handling in that it sets the status for the _Work_ in case of failure.


## Creating the Worker

Finally, we have the _Worker_, in our case represented by the _SingleQueueWorker_ abstraction. This class uses a thread pool to spawn up N number of worker threads that continuously grabs and executes _Work_ from the _SingleWorkQueue_. During the processing of the _Work_, the status flag in the wrapping _WorkItem_ is maintained (can be one of either _ACCEPTED, STARTED, COMPLETED_ or _REJECTED_). This is needed in order for the _SingleQueueWorkManager_ to be able to continuously monitor the status of the _Work_ it has scheduled.&nbsp;

This is what a _Worker_ implementation can look like. As you can see we choose to make use of the _ExecutorService_ thread pool implementation in the _java.util.concurrent_ package:
<pre class="textmate-source mac_classic"><span class="source source_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="storage storage_type storage_type_java">SingleQueueWorker</span> <span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">Worker</span> {

  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">protected</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">ExecutorService</span> m_threadPool = <span class="support support_type support_type_built-ins support_type_built-ins_java">Executors</span>.newCachedThreadPool();
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">protected</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">SingleWorkQueue</span> m_queue;
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">protected</span> <span class="storage storage_modifier storage_modifier_java">volatile</span> <span class="storage storage_type storage_type_java">boolean</span> m_isRunning = <span class="constant constant_language constant_language_java">true</span>;

<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">SingleQueueWorker</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">SingleWorkQueue</span> queue) {
    m_queue = queue;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">start</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) <span class="meta meta_definition meta_definition_throws meta_definition_throws_java"></span><span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">throws</span> <span class="storage storage_type storage_type_java">WorkException</span> {
    <span class="keyword keyword_control keyword_control_java">while</span> (m_isRunning) {
      <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">DefaultWorkItem</span> workItem = m_queue.take();
      <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">Work</span> work = workItem.getResult();
      m_threadPool.execute(<span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">Runnable</span>() {
<span class="meta meta_definition meta_definition_method meta_definition_method_java">        </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">run</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
          <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
            workItem.setStatus(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_STARTED</span>, <span class="constant constant_language constant_language_java">null</span>);
            work.run();
            workItem.setStatus(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_COMPLETED</span>, <span class="constant constant_language constant_language_java">null</span>);
          } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">Throwable</span> e) {
            workItem.setStatus(
                <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>, <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkRejectedException</span>(e));
          }
        }
      });
    }
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">stop</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
    m_isRunning = <span class="constant constant_language constant_language_java">false</span>;
    m_threadPool.shutdown();
  }
}
</pre>


## What about my Work?

Now we have the three main artifacts in place; the _Master_, the _Worker_ and the _Shared Queue_. But what about this _Work_ abstraction and which role does the _DefaultWorkItem_ play?

Starting with the _Work_ abstraction. It is an interface in the _CommonJ WorkManager_ specification but is an interface that we cannot implement generically in the _WorkManager_ "container" we are building now, but should be implemented by the user of this container since the implementation of the actual work that is supposed to be done is of course use-case specific.

The _DefaultWorkItem_ is an implementation of the _WorkItem_ interface in the specification. It's purpose is simply to wrap a _Work_ instance and provide additional information, such as status and an optional _WorkListener_ and can look something like this:
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">DefaultWorkItem</span> <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">WorkItem</span> {

  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">volatile</span> <span class="storage storage_type storage_type_java">int</span> m_status;
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">Work</span> m_work;
  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">WorkListener</span> m_workListener;

<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">DefaultWorkItem</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work, final <span class="storage storage_type storage_type_java">WorkListener</span> workListener) {
    m_work = work;
    m_status = <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_ACCEPTED</span>;
    m_workListener = workListener;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">Work</span> <span class="entity entity_name entity_name_function entity_name_function_java">getResult</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
    <span class="keyword keyword_control keyword_control_java">return</span> m_work;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public synchronized </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">setStatus</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(
      final </span><span class="storage storage_type storage_type_java">int</span> status, final <span class="storage storage_type storage_type_java">WorkException</span> exception) {
    m_status = status;
    <span class="keyword keyword_control keyword_control_java">if</span> (m_workListener <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">!=</span> <span class="constant constant_language constant_language_java">null</span>) {
      <span class="keyword keyword_control keyword_control_java">switch</span> (status) {
        <span class="keyword keyword_control keyword_control_java">case</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_ACCEPTED</span>:
          m_workListener.workAccepted(
              <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkEvent</span>(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_ACCEPTED</span>, <span class="variable variable_language variable_language_java">this</span>, exception));
          <span class="keyword keyword_control keyword_control_java">break</span>;
        <span class="keyword keyword_control keyword_control_java">case</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>:
          m_workListener.workRejected(
              <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkEvent</span>(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>, <span class="variable variable_language variable_language_java">this</span>, exception));
          <span class="keyword keyword_control keyword_control_java">break</span>;
        <span class="keyword keyword_control keyword_control_java">case</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_STARTED</span>:
          m_workListener.workStarted(
              <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkEvent</span>(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_STARTED</span>, <span class="variable variable_language variable_language_java">this</span>, exception));
          <span class="keyword keyword_control keyword_control_java">break</span>;
        <span class="keyword keyword_control keyword_control_java">case</span> <span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_COMPLETED</span>:
          m_workListener.workCompleted(
              <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkEvent</span>(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_COMPLETED</span>, <span class="variable variable_language variable_language_java">this</span>, exception));
          <span class="keyword keyword_control keyword_control_java">break</span>;
      }
    }
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public synchronized </span><span class="storage storage_type storage_type_java">int</span> <span class="entity entity_name entity_name_function entity_name_function_java">getStatus</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
    <span class="keyword keyword_control keyword_control_java">return</span> m_status;
  }
  ... <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> remaining methods omitted (toString() and compareTo())
}
</pre>

A _WorkListener_ is a listener that the user can register in order to track the status of the work and can upon reception of a state-changed-event take proper action (like retry upon failure etc.)

That's it, now we now have a fully functional single-JVM, multi-threaded, implementation of the _CommonJ WorkManager_ specification. Even thought this could be useful as is, there is no way we can scale it out with the needs of the application, since we are bound by the computing power in the single box we are using. Plus, it is not topic for the article. So, let's make it a bit more interesting. 


## Introducing Open Terracotta

[Open Terracotta](http://terracotta.org) is a product that delivers JVM-level clustering as a runtime infrastructure service. It is Open Source and available under a Mozilla-based license.

_Terracotta_ uses bytecode instrumentation to adapt the target application at class load time. In this phase it extends the application in order to ensure that the semantics of the _Java Language Specification_ (JLS) are correctly maintained across the cluster, including object references, thread coordination, garbage collection etc.

Another important thing to mention is that _Terracotta_ does not use _Java Serialization_, which means that any POJO can be shared across the cluster. What this also means is that _Terracotta_ is not sending the whole object graph for the POJO state to all nodes but breaks down the graph into pure data and is only sending the actual "delta" over the wire, meaning the actual changes - the data that is "stale" on the other node(s). 

_Terracotta_ is using an architecture known as _hub-and-spoke_, which means that it has one central L2 server and N number of L1 clients. (The L1 client is the Terracotta client JARs running inside the target JVM, while the L2 server is the central Terracotta server. L1 and L2 refers to first and second level caches.) 

This might seem strange, since most clustering solutions on the market today are using _peer-to-peer_, but as we will see, _hub-and-spoke_ has some advantages and makes it possible to do some very interesting optimizations. The server plays two different roles:

* First it serves as the coordinator ("the traffic cop") in the cluster. It keeps track of things like; which thread in which node is holding which lock, which nodes are referencing which part of the shared state, which objects have not been used for a specific time period and can be paged out, etc. Keeping all this knowledge in one single place is very valuable and allows for very interesting optimizations. 

* Second, it serves as a dedicated state _Service of Record_ (SoR), meaning that it stores all the shared state in the cluster. The state server does not know anything about Java, but only stores the bytes of the data that has changed plus a minimal set of meta info. The L2 server itself is clusterable through a SAN-based failover mechanism. This means that it is possible to scale-out the L2 server in the same fashion as most peer-to-peer solutions but with the advantage of keeping the L2 separate from the L1. This separation allows us to scale out the L1 clients and the L2 servers independently of each other, which is the way that the _Internet_ scales.

One way of looking at _Terracotta_ is to see it as [_Network Attached Memory_](http://www.devx.com/Java/Article/32603/1763?supportItem=1). _Network Attached Memory_ (NAM) is similar to _Network Attached Storage_ (NAS) in the sense that JVM-level (heap-level) replication is making NAM's presence transparent just like NAS can be transparent behind a file I/O API. Getting NAM to perform and scale is similar to any I/O platform; read-ahead buffering, read/write locking optimizations etc. 

Even though it is in clustering, meaning scalability and high-availability, of Web and enterprise applications, that _Terracotta_ can bring its most immediate value, it is really a platform for solving generic distributed computing and shared memory problems in plain Java code. This is something that makes it applicable to a wide range problem domains, for example building a POJO-based _Data Grid_. 

## Let's cluster it using Open Terracotta!

I know what you are thinking:
> "Clustering, hmmm... Now comes the hard part right?"

Well...no.

It turns out that in order to cluster our current _WorkManager_ implementation, all we have to do is to create a _Terracotta_ configuration file in which we define three things:

1. The fully qualified name of the top level object in the object graph that we want to share. In our case we want to share the work queue. This means that the most natural root would be the _LinkedBlockingQueue_ in the _SingleWorkQueue_ class, e.g. the m_workQueue field.
1. The classes that we want to include for instrumentation. We can include all classes for instrumentation, e.g. use a "match-all" pattern, but it is usually better to narrow down the scope of the classes that _Terracotta_ needs to introspect.
1. The potential lock boundaries that we want Terracotta to introspect. These are called _auto-locks_ and is simply a hint that Terracotta should treat the synchronized blocks in these places as transaction boundaries. (You can also define explicit locks called _named-locks_.) In our case we will define a "match-all" pattern for the locking, something that works fine in most cases and should be treated as the default.
<pre class="textmate-source mac_classic"><span class="text text_xml">    ...
    </span><span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">roots</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">root</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">field-name</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
          org.terracotta.datagrid.workmanager.singlequeue.SingleWorkQueue.m_workQueue
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">field-name</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">root</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">roots</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">instrumented-classes</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">include</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">class-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
          org.terracotta.datagrid.workmanager..*
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">class-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">honor-transient</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>true<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">honor-transient</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">include</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">instrumented-classes</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>

    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">locks</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">autolock</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">method-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>* *..*.*(..)<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">method-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">lock-level</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>write<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">lock-level</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">autolock</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">locks</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    ...
</pre>

Done!

Now we have a distributed/multi-JVM _CommonJ WorkManager_ ready for use. But in order to call it a POJO-based _Data Grid_, we need extend it a bit and address some challenges that are likely to arise if we were to deploy this implementation into production. 

# Part 3: Getting serious - Handling real-world challenges

Now we have learned the basics of _Data Grids_, the _Master/Worker_ pattern and what the _CommonJ WorkManager_ specification is all about. We also walked you through how to implement a distributed _CommonJ WorkManager_ by first creating a single-JVM implementation that we then cluster into a distributed multi-JVM implementation with _Open Terracotta_.

However, it was a fairly simple and in some sense naÃ¯ve implementation. This was a good exercise in terms of education and understanding, but in order to use the implementation in the real world we need to know how to address some of the challenges is that might come up. Now we will discuss some of these challenges and how we can extend the initial implementation to address them.

The challenges that we will look at, one by one, are how to handle:

* Very high volumes of data?
* Work failure?
* Routing?
* Ordering?
* Worker failure?

## Dealing with very high volumes of data

Our current implementation has one single queue that is shared by the master(s) and the all workers. This usually gives acceptable performance and scalability when used with a moderate work load. However, if we need to deal with very high volumes of data then it is likely that we will bottleneck on the single queue. So how can we address this in the most simple fashion?

The perhaps simplest solution is to create one queue per worker, and have the master do some more or less intelligent load-balancing. If we are able to do a good partition of the work and data, that we discussed in the previous section ("Scaling Data Grids"), then this solution is one that will:

* **Maximize the use of _Locality of Reference_** - since all work that are operating on the same data set will be routed to the same queue with the same worker working on them
* **Minimize contention** - since since there will only be one reader and one writer per queue.

If we take a look at the current code, what needs to be changed is to first change the _SingleWorkQueue_ class to a _WorkQueueManager_ class and swap the single _LinkedBlockingQueue_ to a _ConcurrentHashMap_ with entries containing a _routing ID_ mapped to a _LinkedBlockingQueue_:

Swap the wrapped _LinkedBlockingQueue_:
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">SingleWorkQueue</span> {

  <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">WorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> m_workQueue = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">LinkedBlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">WorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span>();
  â€¦
}

</pre>

To a _ConcurrentHashMap_ of _LinkedBlockingQueue_'s :
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">DefaultWorkQueueManager</span>&lt;ID&gt; <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">WorkQueueManager</span> {

  <span class="support support_type support_type_built-ins support_type_built-ins_java">Map</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span> , <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">WorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;</span> m_workQueues =
      <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">ConcurrentHashMap</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span>, <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">WorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;</span>();
  â€¦
}

</pre>

We also need to change the _WorkManager_ implementation and rewrite the _schedule(..)_ methods to use a _Router_ abstraction and not put the work directly into the queue:

Change the _schedule(..)_ method from:
<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">DefaultWorkManager</span> <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">WorkManager</span> {

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">WorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">schedule</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work) {
    <span class="storage storage_type storage_type_java">WorkItem</span> workItem = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkItem</span>(work, <span class="constant constant_language constant_language_java">null</span>);
    m_queue.put(workItem);
    <span class="keyword keyword_control keyword_control_java">return</span> workItem;
  }
  ...
}
</pre>

To redirect to the _Router_ abstraction (more on the _Router_ below):
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">RoutingAwareWorkManager</span>&lt;ID&gt; <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">WorkManager</span> {

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">WorkItem</span> <span class="entity entity_name entity_name_function entity_name_function_java">schedule</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work) {
    <span class="keyword keyword_control keyword_control_java">return</span> m_router.route(work);
  }
  ...
}
</pre>

In the last code block we could see that we have introduced a new abstraction; the _Router_, which leads us to the topic of how to deal with different routing schemes.

## Dealing with different routing schemes

By splitting up the single working queue into multiple queues each with a unique routing ID we are opening up for the possibility of providing different routing schemes that can be customized to address specific use cases. 

As in the previous section, we have to make some changes to the initial single queue implementation. First we need to add a routing id to the _WorkItem_ abstraction, we do that by adding the generic type ID and let the _WorkItem_ implement the _Routable_ interface:

<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">RoutableWorkItem</span>&lt;ID&gt; <span class="meta meta_definition meta_definition_class meta_definition_class_extends meta_definition_class_extends_java"></span><span class="storage storage_modifier storage_modifier_java">extends</span> <span class="storage storage_type storage_type_java">DefaultWorkItem</span> <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">Routable</span>&lt;<span class="storage storage_type storage_type_java">ID</span>&gt; {

  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">protected</span> <span class="constant constant_other constant_other_java">ID</span> m_routingID;

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">ID</span> <span class="entity entity_name entity_name_function entity_name_function_java">getRoutingID</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
    <span class="keyword keyword_control keyword_control_java">return</span> m_routingID;
  }
  ...
}
</pre>

As we saw in the previous section, we also introduce a new abstraction called _Router_:
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">Router</span>&lt;ID&gt; {
  <span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> route(<span class="storage storage_type storage_type_java">Work</span> work);
  <span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> route(<span class="storage storage_type storage_type_java">Work</span> work, <span class="storage storage_type storage_type_java">WorkListener</span> listener);
  <span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> route(<span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> <span class="storage storage_type storage_type_java">WorkItem</span>);
}
</pre>

This abstraction can be used to implement various load-balancing algorithms, such as for example:
* **Round-robin** - _Router_ circles around all queues one by one
* **Work load sensitive balancing** - _Router_ looks at queue depth and always sends the next pending work to the shortest queue
* **Data affinity** - "Sticky routing", meaning that the _Router_ sends all pending work of a specific type to a specific queue
* **Roll your own** - to maximize _Locality of Reference_ for your specific requirements

In our _Router_ implementation we have three default algorithms; _round-robin_, _load-balancing_ and _single queue_. You can find them as static inner classes in the _Router_ interface.  

Here is an example of the load-balancing router implementation that takes an array of the routing IDs that are registered and always sends the next pending work to the shortest queue:
<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">LoadBalancingRouter</span>&lt;ID&gt; <span class="meta meta_definition meta_definition_class meta_definition_class_implements meta_definition_class_implements_java"></span><span class="storage storage_modifier storage_modifier_java">implements</span> <span class="storage storage_type storage_type_java">Router</span>&lt;<span class="storage storage_type storage_type_java">ID</span>&gt; {

  <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">private</span> <span class="storage storage_modifier storage_modifier_java">final</span> <span class="storage storage_type storage_type_java">WorkQueueManager</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> m_queueManager;

<span class="meta meta_definition meta_definition_class meta_definition_class_java">  </span><span class="storage storage_modifier storage_modifier_java">private static </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkQueueInfo</span>&lt;ID&gt; {
    <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="constant constant_other constant_other_java">ID</span> routingID;
    <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span>routableworkitem <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;</span> workQueue;
    <span class="storage storage_modifier storage_modifier_access-control storage_modifier_access-control_java">public</span> <span class="storage storage_type storage_type_java">int</span> queueLength = <span class="support support_type support_type_built-ins support_type_built-ins_java">Integer</span>.<span class="constant constant_other constant_other_java">MAX_VALUE</span>;
  }

<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">LoadBalancingRouter</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(
      final </span><span class="storage storage_type storage_type_java">WorkQueueManager</span>&lt;<span class="storage storage_type storage_type_java">ID</span>&gt; queueManager, final <span class="storage storage_type storage_type_java">ID</span>[] routingIDs) {
    m_queueManager = queueManager;
    <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create all queues upfront
    <span class="keyword keyword_control keyword_control_java">for</span> (<span class="storage storage_type storage_type_java">int</span> i = <span class="constant constant_numeric constant_numeric_java">0</span>; i <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span> routingIDs.length; i<span class="keyword keyword_operator keyword_operator_increment-decrement keyword_operator_increment-decrement_java">++</span>) {
      m_queueManager.getOrCreateQueueFor(routingIDs[i]);
    }
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">RoutableWorkItem&lt;ID&gt;</span> <span class="entity entity_name entity_name_function entity_name_function_java">route</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work) {
    <span class="keyword keyword_control keyword_control_java">return</span> route(work, <span class="constant constant_language constant_language_java">null</span>);
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">RoutableWorkItem&lt;ID&gt;</span> <span class="entity entity_name entity_name_function entity_name_function_java">route</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">Work</span> work, final <span class="storage storage_type storage_type_java">WorkListener</span> listener) {
    <span class="storage storage_type storage_type_java">WorkQueueLength</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> shortestQueue = getShortestWorkQueue();
    <span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> workItem =
        <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span>(work, listener, shortestQueue.routingID);
    <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
      shortestQueue.workQueue.put(workItem);
    } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">InterruptedException</span> e) {
      workItem.setStatus(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>, <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkException</span>(e));
      <span class="support support_type support_type_built-ins support_type_built-ins_java">Thread</span>.currentThread().interrupt();
    }
    <span class="keyword keyword_control keyword_control_java">return</span> workItem;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">RoutableWorkItem&lt;ID&gt;</span> <span class="entity entity_name entity_name_function entity_name_function_java">route</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(final </span><span class="storage storage_type storage_type_java">RoutableWorkItem</span>&lt;<span class="storage storage_type storage_type_java">ID</span>&gt; workItem) {
    <span class="storage storage_type storage_type_java">WorkQueueLength</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> shortestQueue = getShortestWorkQueue();
    <span class="storage storage_modifier storage_modifier_java">synchronized</span> (workItem) {
      workItem.setRoutingID(shortestQueue.routingID);
    }
    <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
      shortestQueue.workQueue.put(workItem);
    } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="support support_type support_type_built-ins support_type_built-ins_java">InterruptedException</span> e) {
      workItem.setStatus(<span class="storage storage_type storage_type_java">WorkEvent</span>.<span class="constant constant_other constant_other_java">WORK_REJECTED</span>, <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkException</span>(e));
      <span class="support support_type support_type_built-ins support_type_built-ins_java">Thread</span>.currentThread().interrupt();
    }
    <span class="keyword keyword_control keyword_control_java">return</span> workItem;
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">private </span><span class="storage storage_type storage_type_java">WorkQueueLength&lt;ID&gt;</span> <span class="entity entity_name entity_name_function entity_name_function_java">getShortestWorkQueue</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>) {
    <span class="storage storage_type storage_type_java">WorkQueueLength</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span> shortestQueue = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">WorkQueueLength</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;</span>();

    <span class="storage storage_type storage_type_java">int</span> queueLengthForShortestQueue = <span class="support support_type support_type_built-ins support_type_built-ins_java">Integer</span>.<span class="constant constant_other constant_other_java">MAX_VALUE</span>;
    <span class="constant constant_other constant_other_java">ID</span> routingIDForShortestQueue = <span class="constant constant_language constant_language_java">null</span>;
    <span class="support support_type support_type_built-ins support_type_built-ins_java">Map</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span> , <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">RoutableWorkItem</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;&gt;</span> queues =
        m_queueManager.getQueues();
<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java">    </span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">for</span> <span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="support support_type support_type_built-ins support_type_built-ins_java">Map</span>.<span class="storage storage_type storage_type_java">Entry</span>&lt;<span class="storage storage_type storage_type_java">ID</span>, <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span>&lt;<span class="storage storage_type storage_type_java">RoutableWorkItem</span>&lt;<span class="storage storage_type storage_type_java">ID</span>&gt;&gt;&gt; entry:
        queues.entrySet()) {
      <span class="constant constant_other constant_other_java">ID</span> routingID = entry.getKey();
      <span class="support support_type support_type_built-ins support_type_built-ins_java">BlockingQueue</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span>routableworkitem <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;</span> queue = entry.getValue();
      <span class="storage storage_type storage_type_java">int</span> queueSize = queue.size();
      <span class="keyword keyword_control keyword_control_java">if</span> (queueSize <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span> = queueLengthForShortestQueue) {
        queueLengthForShortestQueue = queueSize;
        routingIDForShortestQueue = routingID;
      }
    }
    shortestQueue.workQueue =
        m_queueManager.getOrCreateQueueFor(routingIDForShortestQueue);
    shortestQueue.routingID = routingIDForShortestQueue;
    <span class="keyword keyword_control keyword_control_java">return</span> shortestQueue;
  }
}
</pre>

## Dealing with work failure

As we discussed earlier in this article the _CommonJ WorkManager_ specification provides APIs for event-based failure reporting and tracking of work status.  Each _Work_ instance is wrapped in a _WorkItem_ instance which provides status information. It also gives us the possibility of defining an optional _WorkListener_ through which we will get callback events whenever the status of the work has been changed. 

The  _WorkListener_ interface looks like this: 

<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">interface</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">WorkListener</span> {
  <span class="storage storage_type storage_type_java">void</span> workAccepted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workRejected(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workStarted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
  <span class="storage storage_type storage_type_java">void</span> workCompleted(<span class="storage storage_type storage_type_java">WorkEvent</span> we);
}
</pre>

As you can see, we can implement callbacks methods that subscribes to events triggered by work being _accepted_, _rejected_, _started_ and _completed_. In this particular case we are mainly interested in doing something when receiving the _work rejected_ event. In order to do that to we simply need to create a implementation of the _WorkListener_ interface and add some code in the _workRejected_ method:
<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="meta meta_definition meta_definition_class meta_definition_class_java"></span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_java">RetryingWorkListener</span> implemets WorkListener {

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">workRejected</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="storage storage_type storage_type_java">WorkEvent</span> we) {
    <span class="storage storage_type storage_type_java">Expection</span> cause = we.getException();
    <span class="storage storage_type storage_type_java">WorkItem</span> wi = we.getWorkItem();
    <span class="storage storage_type storage_type_java">Work</span> work = wi.getResult(); <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> the rejected work

    ... <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> reroute the work onto queue X
  }

<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">workAccepted</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="storage storage_type storage_type_java">WorkEvent</span> event) {}
<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">workCompleted</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="storage storage_type storage_type_java">WorkEvent</span> event) {}
<span class="meta meta_definition meta_definition_method meta_definition_method_java">  </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">void</span> <span class="entity entity_name entity_name_function entity_name_function_java">workStarted</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="storage storage_type storage_type_java">WorkEvent</span> event) {}
}
</pre>


## Dealing with ordering of work

In some situations it might be important to define and maintain ordering of the work.  This doesn't seem to be a problem if we have a single instance of the master, but imagine scaling out the master; then it immediately gets worse.  

So, how can we maintain ordering of the work? Since the internal implementation is based on POJOs and everything is open and customizable, it is actually very easy to implement support for ordering.  All we need to do is to swap our map of _LinkedBlockingQueue_(s) to a map of _PriorityBlockingQueue_ (s).

Then you can let your _Work_ implement _Comparable_ and create a custom _Comparator_ that you pass it into the constructor of the _PriorityBlockingQueue_:

<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="support support_type support_type_built-ins support_type_built-ins_java">Comparator</span> c = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="support support_type support_type_built-ins support_type_built-ins_java">Comparator</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="storage storage_type storage_type_java">RoutableWorkItem</span> <span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&lt;</span><span class="constant constant_other constant_other_java">ID</span><span class="keyword keyword_operator keyword_operator_comparison keyword_operator_comparison_java">&gt;&gt;</span>() {
<span class="meta meta_definition meta_definition_method meta_definition_method_java">    </span><span class="storage storage_modifier storage_modifier_java">public </span><span class="storage storage_type storage_type_java">int</span> <span class="entity entity_name entity_name_function entity_name_function_java">compare</span><span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(
        </span><span class="storage storage_type storage_type_java">RoutableWorkItem</span> workItem1,
        <span class="storage storage_type storage_type_java">RoutableWorkItem</span> workItem2)
      Comparable work1 = <span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="support support_type support_type_built-ins support_type_built-ins_java">Comparable</span>)workItem1.getResult<span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>);
      Comparable work2 = <span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="support support_type support_type_built-ins support_type_built-ins_java">Comparable</span>)workItem2.getResult<span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span>);
      return work1.compareTo<span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(work2</span>);
    }};
</pre>

If you need to maintain ordering of the result then you have to do something similar with the references to the _WorkItem_(s) that you get when invoking _schedule(..)_ on the _WorkManager_ instance. 

## Dealing with worker failure

In a reliable distributed system it is important to be able to detect if a worker goes down.  (In order to simplify the discussion, let's define a worker as being a JVM.) There are some different ways this could be implemented and we will now discuss some of the different strategies that we can take.

1. **Heartbeat mechanism** - In this strategy each worker has an open connection to the master through which it continuously (and periodically) sends a heartbeat (some sort of "I'm-alive" event) to the master. The master can then detect if the heartbeat for a specific worker stops and can after a certain time period consider the node to be dead. This is for example the way that [Google's MapReduce implementation](http://www.cs.wisc.edu/~dusseau/Classes/CS739/Writeups/mapreduce.pdf) detects worker failure.
1. **Work timestamp** - Here we are adding a timestamp to each pending work item. The master can then periodically peek into the head of each work queue, read the timestamp and and match it to a predefined timeout interval. If it detects that a work item has timed out then it can consider the worker(s) that is polling from the specific queue to be dead. 
1. **Worker "is-alive-lock"** - This strategy utilizes the cross-JVM thread coordination that _Terracotta_ enables.  The first thing that each worker does when it starts up is spawn a thread that takes a worker specific lock:<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="storage storage_modifier storage_modifier_java">synchronized</span>(workerLock) {
  <span class="keyword keyword_control keyword_control_java">while</span> (isRunning) {}; <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> hold the lock until worker is shut down or dies
}</pre>Then the the worker connects to the master which spawns up a thread that tries to take the exact same lock. Here comes the trick - the master thread will block until the lock is released, something that will only happen if the worker dies:<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="storage storage_modifier storage_modifier_java">synchronized</span>(workerLock) { <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> will block here until worker dies
  ... <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> worker dead - take proper action
}</pre>
1. **Terracotta Server notifications** - Since detection of a node failure is such a common problem, an implementation in which the _Terracotta_ clients can subscribe on notifications of node death from the _Terracotta Server_ is underway and will be released in an upcoming version of _Open Terracotta_.   

In all of the strategies we need to take proper action when worker failure has been detected. In our case it would (among other things) mean to reroute all non-completed work to another queue. 

## Rewrite the Terracotta config

As you perhaps remember from section "Very high volumes of data?", in order to make the implementation more scalable we had to change the _SingleWorkQueue_ class to a _WorkQueueManager_ class and swap the single _LinkedBlockingQueue_ to a _ConcurrentHashMap_ with entries containing a _routing ID_ mapped to a _LinkedBlockingQueue_. When we did that we also changed the name of the field and the name of class holding this field, this is something that needs to be reflected in the _Terracotta_ configuration file:

<pre class="textmate-source mac_classic"><span class="text text_xml">...
</span><span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">roots</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">root</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">field-name</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      org.terracotta.datagrid.workmanager.routing. 
          DefaultWorkQueueManager.m_workQueues
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">field-name</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">root</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">roots</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
...
</pre>

## How to use the POJO Grid?

Here is an example of the usage of the _WorkManager_, _WorkQueueManager_, _Router_ and _WorkListener_ abstractions:

<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> Create the work queue manager with 'String' as routing ID type.
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> The DefaultWorkQueueManager is usually sufficient, but you can
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> easily provide your own implementation of the WorkQueueManager
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> interface
<span class="storage storage_type storage_type_java">WorkQueueManager</span> workQueueManager = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkQueueManager</span>();

<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create the router - there are a bunch of default routers in the
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> Router interface, such as SingleQueueRouter, RoundRobinRouter
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> and LoadBalancingRouter, but it is probably here that you need to
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> plug in your custom implementaion
<span class="storage storage_type storage_type_java">Router</span> router = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">Router</span>.<span class="storage storage_type storage_type_java">LoadBalancingRouter</span>(workQueueManager);   

<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create the work manager - this implementation is very generic and
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> most likely enough for you needs
<span class="storage storage_type storage_type_java">WorkManager</span> workManager = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">RoutingAwareWorkManager</span>(router);

<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> optionally (null is ok) create a work listener that will get a call
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> back each time the status of a WorkEvent (Work) has changed -
<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> allows you to for example take proper action upon failure and retry etc.
<span class="storage storage_type storage_type_java">WorkListener</span> workListener = <span class="constant constant_language constant_language_java">null</span>;

<span class="support support_type support_type_built-ins support_type_built-ins_java">Set</span> workSet = ... <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create a set with the work to be done

<span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> loop over the work set
<span class="meta meta_definition meta_definition_constructor meta_definition_constructor_java"></span><span class="entity entity_name entity_name_function entity_name_function_constructor entity_name_function_constructor_java">for</span> <span class="meta meta_definition meta_definition_param-list meta_definition_param-list_java">(</span><span class="storage storage_type storage_type_java">Work</span> work: workSet) {
   <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> the work item, wrapping the work (result) and holds the status
  <span class="storage storage_type storage_type_java">RoutableWorkItem</span> workItem;
  <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
    <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> schedule the work, e.g. add it to the work queue and get the
    <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span>work item in return that can be used to keep track of the
    <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> pending work
    workItem = workManager.schedule(work, workListener);
  } <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="storage storage_type storage_type_java">WorkException</span> e) {
    <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> handle failure
  }
}
</pre>

To start up a _Worker_ you simply have to create an instance of the _Worker_, pass in a reference to the _DefaultWorkQueueManager_ and the routing id to use, and finally invoke _start():_

<pre class="textmate-source mac_classic"><span class="source source_java">
</span><span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">try</span> {
  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create a work queue manager with 'String' as routing ID type
  <span class="storage storage_type storage_type_java">WorkQueueManager</span> workQueueManager = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">DefaultWorkQueueManager</span>();

  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> create and start up a Worker implementation - the provided RoutingAwareWorker
  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> implementation is usually enough
  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> we pass in the work queue manager and the routing ID for this worker
  <span class="storage storage_type storage_type_java">Worker</span> worker = <span class="keyword keyword_other keyword_other_class-fns keyword_other_class-fns_java">new</span> <span class="storage storage_type storage_type_java">RoutingAwareWorker</span>(workQueueManager, <span class="string string_quoted string_quoted_double string_quoted_double_java"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_java">"</span>ROUTING_ID_1<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_java">"</span>);
  worker.start();

} <span class="keyword keyword_control keyword_control_catch-exception keyword_control_catch-exception_java">catch</span> (<span class="storage storage_type storage_type_java">WorkException</span> e) {
  <span class="comment comment_line comment_line_double-slash comment_line_double-slash_java"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_java">//</span> handle failure
}
</pre>
## Don't we need a result queue? 

There is no need for a result queue, since the _Master_ is holding on to the _WorkItem_ e.g. the pending work (the work that is in progress) including its result. _Terracotta_ maintains Java's pass-by-reference semantics, the regular (local) reference to the _WorkItem_ that the _Master_ holds, will work transparently across the cluster. This means that a _Worker_ can update the exact same _WorkItem_ and the _Master_ would know about it immediately. 

## Enabling Terracotta

The client usage would roughly be to start up one _WorkManager_ and N number of _Workers_, each one on a different JVM. Before you start up the _WorkManager_ and _Workers_ you have to enable the _Terracotta_ runtime. 

There are two ways you can do this:

### Use Terracotta wrapper script

 _Open Terracotta_ ships with a script that should be used as a drop-in replacement to the regular _java_ command. The name of the script is _dso-java_ and can be found in the _bin_ directory in the distribution. To use the recommended _Terracotta_ startup script:

* Find the _dso-java_ script in the _dso/bin_ directory.
* Replace the regular invocation to _java_ with the invocation to _dso-java_.

### Use JVM options

You can also use additional JVM options for applications inside the web container, perform the following:

* Prepend the _Terracotta Boot Jar_ to the _Java bootclasspath_.
* Define the path to the _Terracotta_ configuration file.

Here is an example (assuming you are running _Windows_):
<pre class="textmate-source mac_classic"><span class="source source_java-props"></span><span class="keyword keyword_other keyword_other_java-props">java -Xbootclasspath/p</span><span class="punctuation punctuation_separator punctuation_separator_key-value punctuation_separator_key-value_java-props">:</span>&lt;path to terracotta boot jar&gt; 
<span class="keyword keyword_other keyword_other_java-props">     -Dtc.config</span><span class="punctuation punctuation_separator punctuation_separator_key-value punctuation_separator_key-value_java-props">=</span>path/to/your/tc-config.xml
<span class="keyword keyword_other keyword_other_java-props">     -Dtc.install-root</span><span class="punctuation punctuation_separator punctuation_separator_key-value punctuation_separator_key-value_java-props">=</span>&lt;path to terracotta install dir&gt; 
      ... &lt;your regular options&gt; ...
</pre>

## Run it

Now we are almost done, but before you spawn up the _Master_ and the _Workers_ we must first start the _Terracotta Server_. This is done by invoking the _start-tc-server_ script in the _dso/bin_ directory. After you have done that then you can just start up the _Master_ and the _Workers_ (in any order you like).

That is all there is to it. 


## Benefits of implementing a POJO-based Data Grid

So let's wrap up with a brief discussion of the most immediate benefits of building and using a POJO-based _Data Grid_. Here are some of the benefits that we value:

* **Work with POJOs** - You get to work with POJOs, meaning simple and plain Java code. Any POJO can be shared across the cluster and migrated between worker nodes. There is no need for implementing _Serializable_ or any other interface. It is as simple as Java can be.
* **Event-driven development** - The _Master/Worker_ (and _CommonJ WorkManager_) pattern leans itself towards event-driven development with no need for explicit threading and guarding. This can simplify the user code immensely compared to the use of explicit thread coordination. 
* **Simpler development and testing** - We have talked about how _Open Terracotta_ allows you to develop an application for a single JVM and then simply cluster it in order to run it on multiple JVMs. This means that you can simplify the development and testing of your Data Grid application by doing the development and testing on your workstation, utilizing multiple threads instead of JVMs and then deploy the application onto multiple nodes at a later stage.
* **White Box container implementation** - The whole grid implementation is "under your fingers", nothing is really abstracted away from you as a developer. This gives you the freedom to design _Master_, _Worker_, routing algorithms, fail-over schemes etc. the way you need, you can customize everything as much as you want.

## Resources

* Checkout the distribution for the POJO-based Data Grid. It is a Maven 2 based project that includes a sample implementation of a distributed web spider. Read the readme.html for instructions on how to build and run the sample: 
[http://svn.terracotta.org/svn/forge](http://svn.terracotta.org/svn/forge) - (module projects/labs/opendatagrid)
* Download Terracotta's JVM-clustering technology - Open Source: 
[http://terracotta.org](http://terracotta.org)
* Tutorial that is using the implementation outlined in this article to build a parallel web spider (that is part of the pojo-grid distribution): 
[http://terracotta.org/confluence/display/orgsite/TutorialTerracottaDsoSpider](http://terracotta.org/confluence/display/orgsite/TutorialTerracottaDsoSpider)
* Article - Distributed Computing Made Easy: 
[http://www.theserverside.com/tt/articles/article.tss?l=DistCompute](http://www.theserverside.com/tt/articles/article.tss?l=DistCompute)
* Article - Stateful Session Clustering: Have Your Availability and Scale It Too: 
[http://www.devx.com/Java/Article/32603/](http://www.devx.com/Java/Article/32603/)
* Documentation for Terracotta's JVM-clustering technology: 
[http://terracotta.org/confluence/display/orgsite/Documentation](http://terracotta.org/confluence/display/orgsite/Documentation)
* Author's weblog:
[http://jonasboner.com](http://jonasboner.com)
