--- 
wordpress_id: 111
layout: post
title: How To Implement a Distributed CommonJ WorkManager
wordpress_url: http://jonasboner.com/2006/09/14/how-to-implement-a-distributed-commonj-workmanager/
---
In this article I will show you how to implement a distributed version of the <em>CommonJ WorkManager</em> specification using <a href="http://www.terracottatech.com/terracotta_spring.shtml">Terracotta for Spring</a>. This article is a variation of an article that I wrote for <a href="http://www.theserverside.com/tss">TheServerSide.com</a> titled <em>Distributed Computing Made Easy</em>, an article that can be found <a href="http://www.theserverside.com/tt/articles/article.tss?l=DistCompute">here</a>.

<h2>What is CommonJ WorkManager?</h2>

<em>CommonJ</em> is a BEA and IBM joint specification that provides a standard for executing concurrent tasks in a JEE environment. It for example has support for the <em>Master/Worker pattern</em> in its <em>WorkManager API</em>.

From BEA's documentation about the specification: 

<blockquote>"The Work Manager provides a simple API for application-server-supported concurrent execution of work items. This enables J2EE-based applications (including Servlets and EJBs) to schedule work items for concurrent execution, which will provide greater throughput and increased response time. After an application submits work items to a Work Manager for concurrent execution, the application can gather the results. The Work Manager provides common "join" operations, such as waiting for any or all work items to complete. The Work Manager for Application Servers specification provides an application-server-supported alternative to using lower-level threading APIs, which are inappropriate for use in managed environments such as Servlets and EJBs, as well as being too difficult to use for most applications."
</blockquote>

What we are going to do is to first implement a the specification as a regular single node multi-threaded application, based on the <em>Master/Worker</em> pattern. We are also going to use the <a href="http://springframework.org/">Spring Framework</a> and implement the <em>Master</em>, <em>Worker</em> and <em>Shared Queue</em> entities as three different <em>Spring</em> beans; <code>MyWorkManager</code>, <code>Worker</code> and <code>WorkQueue</code>.

We will then use <a href="http://www.terracottatech.com/terracotta_spring.shtml">Terracotta for Spring</a>* to transparently and declaratively, turn this implementation into a multi-node, distributed <em>WorkManager</em>.

<h2>Master (WorkManager)</h2>

<code>MyWorkManager</code> bean implements the <em>CommonJ WorkManager</em> interface which has the API that the user uses to schedule <code>Work</code> and wait for all <code>Work</code> to be completed. The <code>MyWorkManager</code> bean does not have any state, and can therefore be configured as a <em>Prototype</em> in the <em>Spring</em> bean config XML file. 

Here is how we could implement the work manager bean:

<pre>
public class MyWorkManager implements WorkManager { 

  // The Work Queue bean, is injected by Spring
  private final WorkQueue m_queue;

  public MyWorkManager(WorkQueue queue) {
    m_queue = queue;
  }

  public WorkItem schedule(final Work work) throws WorkException {
    WorkItem workItem = new MyWorkItem(work, null);
    m_queue.addWork(workItem);
    return workItem;
  }

  public WorkItem schedule(Work work, WorkListener listener) 
    throws WorkException {
    WorkItem workItem = new MyWorkItem(work, listener);
    m_queue.addWork(workItem); // adds work to the shared queue
    return workItem;
  }

  public boolean waitForAll(Collection workItems, long timeout) {
    long start = System.currentTimeMillis();
    do {
      boolean isAllCompleted = true;
      for (Iterator it = workItems.iterator(); 
           it.hasNext() && isAllCompleted;) {
        int status = ((WorkItem) it.next()).getStatus();
        isAllCompleted = 
            status == WorkEvent.WORK_COMPLETED || 
            status == WorkEvent.WORK_REJECTED;
      }
      if (isAllCompleted) { return true; }
      if (timeout == IMMEDIATE) { return false; }
      if (timeout == INDEFINITE) { continue; }
    } while ((System.currentTimeMillis() - start) < timeout);
    return false;
  }

  public Collection waitForAny(Collection workItems, long timeout) {
    long start = System.currentTimeMillis();
    do {
      synchronized (this) {
        Collection completed = new ArrayList();
        for (Iterator it = workItems.iterator(); it.hasNext();) {
          WorkItem workItem = (WorkItem) it.next();
          if (workItem.getStatus() == WorkEvent.WORK_COMPLETED || 
              workItem.getStatus() == WorkEvent.WORK_REJECTED) {
            completed.add(workItem);
          }
        }
        if (!completed.isEmpty()) { return completed; }
      }
      if (timeout == IMMEDIATE) { return Collections.EMPTY_LIST; }
      if (timeout == INDEFINITE) { continue; }
    } while ((System.currentTimeMillis() - start) < timeout);
    return Collections.EMPTY_LIST;
  }
}
</pre>

<h2>Shared Queue</h2>

The <code>MyWorkManager</code> bean schedules work by adding work to the <code>WorkQueue</code> bean, which is a simple wrapper around a <code>java.util.concurrent.BlockingQueue</code> queue. The <code>WorkQueue</code> bean is the bean that has state, since it holds the queue with all the pending <code>Work</code>. We need to have a single instance of this queue that can be available to all workers, and we therefore define it as <em>Singleton</em> in the bean config XML file. 

The work queue can be implemented like this:

</pre><pre>
public class WorkQueue {
  private final BlockingQueue m_workQueue;

  public WorkQueue() {
    m_workQueue = new LinkedBlockingQueue();
  }

  public WorkQueue(int capacity) {
    m_workQueue = new LinkedBlockingQueue(capacity);
  }

  public MyWorkItem getWork() throws WorkException {
    try {
      return (MyWorkItem) m_workQueue.take(); // blocks if empty
    } catch (InterruptedException e) {
      throw new WorkException(e);
    }
  }

  public void addWork(WorkItem workItem) throws WorkException {
    try {
      m_workQueue.put(workItem);
    } catch (InterruptedException e) {
      WorkRejectedException we = 
          new WorkRejectedException(e.getMessage());
      ((MyWorkItem)workItem).setStatus(WorkEvent.WORK_REJECTED, we);
      throw we;
    }
  }
}
</pre>

<h2>Worker</h2>

Finally, we have the <code>Worker</code> bean. This bean uses a thread pool to spawn up N number of worker threads that continuously grabs and executes Work from the <code>WorkQueue</code>. During the processing of the <code>Work</code>, its status flag is maintained (can be one of either Accepted, Started, Completed or Rejected), this is needed in order for the <code>MyWorkManager</code> bean to be able to continuously monitor the status of the Work it has scheduled. The <code>Worker</code> bean does not have any shared state and is configured as a <em>Prototype</em> in the bean config XML file.

This is what a worker bean implementation can look like. As you can see we choose to make use of the <code>Executor</code> thread pool implementation in the <code>java.util.concurrent</code> package:

<pre>
public class Worker {

  private transient final WorkQueue  m_queue;
  private transient final ExecutorService m_threadPool = 
      Executors.newCachedThreadPool();
  private volatile boolean m_isRunning  = true;

  public Worker(WorkQueue queue) {
    m_queue = queue;
  }

  public void start() throws WorkException {
    while (m_isRunning) {  
      final MyWorkItem workItem = m_queue.getWork();
      m_threadPool.execute(new Runnable() {
        public void run() {
          try {
            Work work = workItem.getResult();
            workItem.setStatus(WorkEvent.WORK_STARTED, null);
            work.run();
            workItem.setStatus(WorkEvent.WORK_COMPLETED, null);
          } catch (Throwable e) {
            workItem.setStatus(
                WorkEvent.WORK_REJECTED, 
                new WorkRejectedException(e.getMessage()));
          }
        });
      }
    }
  }
}
</pre>

<h2>Assembly</h2>

These three beans can now be wired up by the <em>Spring</em> bean config file:

<pre>
&lt;beans&gt;
  &lt;!-- workManager is prototype - not shared --&gt;
  &lt;bean id="workManager"
        class="com.jonasboner.commonj.workmanager.MyWorkManager"     
        singleton="false"&gt;
    &lt;constructor-arg ref="queue"/&gt;
  &lt;/bean&gt;
    
   &lt;!-- worker is prototype - not shared --&gt;
  &lt;bean id="worker" 
        class="com.jonasboner.commonj.workmanager.Worker" 
        singleton="false"&gt;
    &lt;constructor-arg ref="queue"/&gt;
  &lt;/bean&gt;

  &lt;!-- the work queue is singleton - can be made shared by Terracotta --&gt;
  &lt;bean id="queue" 
        class="com.jonasboner.commonj.workmanager.WorkQueue"/&gt;

&lt;/beans&gt;
</pre>

We now have a fully functional local, multi-threaded, implementation of the <em>CommonJ WorkManager</em> specification. 

<h2>Making the WorkManager distributed</h2>

Now comes the hard part right? Well...no.

It turns out that in order to turn this implementation into a distributed <code>WorkManager</code>, all we have to do is to create a <em>Terracotta</em> configuration file in which we declare the <em>Spring</em> beans that we want to share across the cluster:

<pre>     
...
&lt;spring&gt;
  &lt;jee-application name="webAppName"&gt;
    &lt;application-contexts&gt;
      &lt;application-context&gt;
        &lt;paths&gt;
          &lt;path&gt;*/work-manager.xml&lt;/path&gt;
        &lt;/paths&gt;
        &lt;beans&gt;
          &lt;bean name="queue"/&gt;
        &lt;/beans&gt;
      &lt;/application-context&gt;
    &lt;/application-contexts&gt;
  &lt;/jee-application&gt;
&lt;/spring&gt;
...
</pre>

Done! 

Now we have a fully distributed, multi-JVM <em>CommonJ WorkManager</em>.

<h2>Client usage</h2>

Using the distributed work manager is now simply a matter of getting the bean from the application context and invoke <code>schedule(..)</code>:

<pre>
ApplicationContext ctx = 
    new ClassPathXmlApplicationContext("*/work-manager.xml");

// get the work manager from the application context
WorkManager workManager = (WorkManager) ctx.getBean("workManager");

Set pendingWork = new HashSet();
for (int i = 0; i < nrOfWork; i++) {

  // schedule work
  WorkItem workItem = workManager.schedule(new Work() {
      public void run() {
        ... // do work
      }
  });
                
  // collect the pending work
  pendingWork.add(workItem);
}

// wait for all work to be completed
workManager.waitForAll(pendingWork, WorkManager.INDEFINITE);
</pre>

To start up a <code>Worker</code> you simply have to get the <code>Worker</code> bean from the application context and invoke <code>start()</code>: 

</pre><pre>
ApplicationContext ctx = 
    new ClassPathXmlApplicationContext("*/work-manager.xml");

// get the worker from the application context
Worker worker = (Worker) ctx.getBean("worker");

// starting worker
worker.start();
</pre>

The usage of the distributed version would roughly be to start up one <code>WorkManager</code> bean and N number of <code>Worker</code> beans, each one on a different JVM. 

That is all there is to it. Now we have a simple, distributed, reliable, high-performant and scalable <em>CommonJ WorkManager</em> ready for use. 

Enjoy.

* <a href="http://www.terracottatech.com/downloads.jsp">RC 1</a> of <a href="http://www.terracottatech.com/terracotta_spring.shtml">Terracotta for Spring</a> was released some days ago (9/12/2006) and is free for production use for up to two nodes.
