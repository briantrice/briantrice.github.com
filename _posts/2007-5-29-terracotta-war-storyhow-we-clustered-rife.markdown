--- 
wordpress_id: 138
layout: post
title: "Terracotta War Story:How We Clustered RIFE  "
wordpress_url: http://jonasboner.com/2007/05/29/terracotta-war-storyhow-we-clustered-rife/
---
This is the story how <a href="http://rifers.org/blogs/gbevin">Geert Bevin</a> and I clustered <a href="http://rifers.org">RIFE</a> with <a href="http://terracotta.org">Terracotta</a>. 

The purpose of this blog post is to give an example of how JVM-level clustering of a nontrivial application can be done. Actually, clustering RIFE turned out to be much more challenging than we initially thought, mainly due to its extreme dynamicity, and I hope that our insights and solutions can be of value to someone trying to do a similar thing. 

The first thing that we had to do in order to cluster RIFE with Terracotta was to cluster its <a href="http://en.wikipedia.org/wiki/Continuation">continuations</a>. 

RIFEâ€™s continuations aims to make support for continuations in pure Java available as a general-purpose library, a library that can and is being used by other frameworks and tools. It is implementing continuations by allowing it to use regular Java methods to mark the execution flow to be suspended or resumed. It is using bytecode instrumentation (based on the <a href="http://asm.objectweb.org/">ASM bytecode library</a>) to generate code and redefine classes in order to implement this in the most effective way possible. It is not relying on Java serialization but is instead breaking down the object graph into primitives and stores the actual data on the execution stack (similar to the approach taken by Terracotta). This makes it very nonintrusive and simple to use, since you can work with POJOs with minimal interference from the continuations framework itself. The continuations are linked together in a tree structure which allows you to traverse to the different execution steps the way you want. This means that you can actually step back (and forward) in time, which is a very neat way of solving the browser back button problem - if used in the context of web applications.

Internally RIFE is storing its continuations in a regular <code>java.util.HashMap</code>:

<pre>
private final Map mContexts = new HashMap();
</pre>
 
This means that this map is a data structure that holds on to all the state that we want to cluster, something that makes it a perfect fit for becoming a Terracotta 'root', e.g. the top-level object in a shared/clustered object graph. So, we simply had to define the fully qualified name of the field that held on to this map as the 'root' in our Terracotta configuration:

<pre>
&lt;root&gt;
  &lt;field-name&gt;
    com.uwyn.rife.continuations.ContinuationManager.mContexts
  &lt;/field-name&gt;
  &lt;root-name&gt;mContexts&lt;/root-name&gt;
&lt;/root&gt;
</pre>

That was quite simple. However, initially RIFE was designed to only access this map using a single thread, which allowed it (for performance reasons) to choose to not make it thread safe. Unfortunately, this is an assumption that does not hold when we are clustering the map with Terracotta since then you will have, not multi-threaded, but concurrent access from multiple JVMs. The promise of Terracotta is that it maintains the semantics of Java across the cluster which means that we need to guard our data correctly for concurrent access using Javaâ€™s concurrency primitives or abstractions, primitives and abstractions that Terracotta will maintain the semantics of across the cluster. In short, Terracotta requires you to write thread-safe code. What this boiled down to in practice was that we had to make the access and modifications to the map itself and all the continuations in the map guarded (using synchronized blocks). The simplest option would have been to swap the regular <code>HashMap</code> to a <code>java.util.concurrent.ConcurrentHashMap</code>, but since RIFE needs backward compatibility with Java 1.4, that was not an option. So after making the code thread-safe we could see the continuations effectively clustered by Terracotta. (Some readers might see that what we have actually done here is a simple way of cross-JVM thread migration.)

This works fine if all the clustered classes are loaded through Java's system class loader (or the boot or ext class loaders) since that is a class loader that Terracotta knows about and can identify uniquely. But unfortunately, this is not the case if we are running in an application server since they are normally using a more or less complex hierarchy of class loaders that are specific to the application server itself. The reason why Terracotta needs to be able to uniquely define a class loader is that it needs a way of, at any point in time and on an arbitrary cluster-node, retrieve the class loader instance that has loaded a specific class in order to maintain object identity across the cluster. In the case of RIFE we had two class loaders - <code>EngineClassLoader</code> and <code>TemplateClassLoader</code> - that we had to enhance and make implement the <code>NamedClassLoader</code> interface in Terracotta: 

<pre>
public interface NamedClassLoader {
  public static final String CLASS = 
      "com/tc/object/loaders/NamedClassLoader";
  public static final String TYPE  = "L" + CLASS + ";";
  public String __tc_getClassLoaderName();
  public void __tc_setClassLoaderName(String name);
}
</pre>

We also had to add code for the RIFE class loaders to register themselves in the Terracotta runtime:

<pre>
public EngineClassLoader(ClassLoader parent) {
  â€¦
  com.tc.object.bytecode.hook.impl.ClassProcessorHelper.
      registerGlobalLoader(this);
}
</pre>

Now for the biggest challenge; cluster the RIFE template engine. RIFE is relying heavily on on-the-fly class generation using bytecode instrumentation. This is extremely powerful, since it allows the user to to find what he wants to do in metadata (with heavy reliance on defaults) and then using that metadata together with  templates to generate the actual classes dynamically on demand. 

This extreme dynamicity imposed a lot of interesting challenges in terms of clustering. For example, if a user request comes in to a node (think application server or JVM), let's call it Node1, and asks for for example the Order form. Then, if form does not yet exist, the template engine will do its job of introspecting the metadata and generate this class on-the-fly for us before it continues serving the user. Now imagine a scenario where Node1 crashes and the load balancer redirects the user to another node, let's call it Node2. Then Terracotta will do its job of loading the Order class and instantiate a new Order instance before it pages in the state from that same instance on Node1. The problem is that this class is not available on Node2, it was generated at runtime on Node1. So we end up getting a <code>ClassNotFoundException</code> on Node2. Hmm, too bad. What to do about it? 

The solution turned out to be quite simple. First we created an interface called <code>BytecodeProvider</code>: 

<pre>
public interface BytecodeProvider {
  /**
   * Returns the bytecode for a class with the name specified.
   *
   * @param className the name of the class who's bytecode 
   *             is missing
   * @return the bytecode for the class or NULL if bytecode is 
   *             not in the repository
   */
  public byte[] __tc_getBytecodeForClass(String className);
}
</pre>

Then we modified RIFE's <code>TemplateClassLoader</code>, which is the class that generates the templates in RIFE, to implement this interface:

<pre>â€¦
public byte[] __tc_getBytecodeForClass(final String className) {
  if (null == mBytecodeRepository) {
    return null;
  }		
  synchronized (mBytecodeRepository) {
    return mBytecodeRepository.get(getKeyFor(className));  
  }			    
}
â€¦
</pre>

We also added a code snippet in the the Terracotta runtime to - in the case of a <code>ClassNotFoundException</code> - check if the class loader it tried to use to load a specific class implements this interface, and if it does use the <code>__tc_getBytecodeForClass(String className)</code> method to retrieve the bytes for the class, load it and go on from there:

<pre>â€¦
try {
  return Class.forName(className, false, loader);
} catch (ClassNotFoundException e) {
  if (loader instanceof BytecodeProvider) {
    BytecodeProvider provider = (BytecodeProvider) loader;
    byte[] bytes = provider.__tc_getBytecodeForClass(className);
    if (bytes != null && bytes.length != 0) { 
      return AsmHelper.defineClass(loader, bytes, className); 
    }
  }
  throw e;
}
â€¦
</pre>

So far so good. But what about transferring the bytecode for one node to another, e.g. make it available to any node that needs it? Actually, this was fairly easily solved by using Terracotta itself. We added a <code>HashMap</code> in the implementor of the <code>BytecodeProvider</code> interface, e.g. the <code>TemplateClassLoader</code>, and made sure that as soon as a new class is generated on-the-fly, it is added to the map. After that, the only thing we had to do was to define this map as a shared Terracotta 'root' and we had a cluster wide bytecode repository ready to be used: 

<pre>
&lt;root&gt;
  &lt;field-name&gt;
    com.uwyn.rife.template.TemplateClassLoader.mBytecodeRepository
  &lt;/field-name&gt;
  &lt;root-name&gt;mBytecodeRepository&lt;/root-name&gt;
&lt;/root&gt;
</pre>

Ok, weâ€™re not really done yet, but close. There are some nitty-gritty details that we had to add to the configuration file in order to let Terracotta do its work. First a hint to use auto-locking (for details on lock configuration, see the <a href="http://terracotta.org">official documention</a>): 

<pre> 
 &lt;locks&gt;
   &lt;autolock&gt;
     &lt;method-expression&gt;* *..*.*(..)&lt;/method-expression&gt;
     &lt;lock-level&gt;write&lt;/lock-level&gt;
   &lt;/autolock&gt;
 &lt;/locks&gt;
</pre>

Then we also had to make shure that didn't cluster more than we wanted to, e.g. that we cut the object graph at the appropriate places. This was done by declaring specific fields as 'transient':

<pre>
&lt;transient-fields&gt;
  &lt;field-name&gt;com.uwyn.rife.continuations.ContinuationManager.mRandom&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.Gate.mInitException&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.RequestState.mResponse&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.RequestState.mInitConfig&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.ElementContext.mResponse&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.Site$SiteData.mResourceModificationTimes&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.engine.Site$SiteData.mUrls&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.servlet.RifeFilter.mClassloader&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.servlet.HttpResponse.mResponse&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.servlet.HttpRequest.mHttpServletRequest&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_US_ASCII&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_ISO_8859_1&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_UTF_8&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_UTF_16&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_UTF_16BE&lt;/field-name&gt;
  &lt;field-name&gt;com.uwyn.rife.template.InternalString.mBytesValue_UTF_16LE&lt;/field-name&gt;
&lt;/transient-fields&gt;
</pre>

A bit ugly, but that is about it. 

Finally, we wrapped everything up in a Terracotta Configuration Module which means that the only thing you need to do in order to cluster RIFE is to write a Terracotta configuration file that looks like this:

<pre>
&lt;tc:tc-config xmlns:tc="http://www.terracotta.org/config"&gt;
  &lt;!-- ...system and server stuff... --&gt;
  &lt;clients&gt;
    &lt;modules&gt;
      &lt;module name="clustered-rife-1.6.0" version="1.0.0"/&gt;
    &lt;/modules&gt;
  &lt;/client&gt;
&lt;/tc:tc-config&gt;
</pre>

That was a long story. I hoped that you learned something along the way. If not, at least try it out and enjoy the outcome of our efforts - it is actually quite a breeze to use. 
