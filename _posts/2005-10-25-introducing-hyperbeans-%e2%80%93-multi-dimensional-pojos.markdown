--- 
wordpress_id: 46
layout: post
title: "Introducing HyperBeans \xC3\xA2\xE2\x82\xAC\xE2\x80\x9C multi-dimensional POJOs"
excerpt: |
  This article is introducing <i>HyperBeans</i>, a proposal for a framework for <a href="http://domino.watson.ibm.com/library/cyberdig.nsf/0/2a4097e93456d0cf85256ca9006dac29?OpenDocument">Symmetric Aspect-Oriented Software Development</a>  in <b>plain</b> Java (i.e. no extensions to Java is being used). These ideas are based on the work I have done in <i><a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a></i>  and in the <a href="http://dev2dev.bea.com/pub/a/2005/08/jvm_aop_2.html">JVM support for AOP</a>  in <i>JRockit</i> and are loosely based on the work on <a href="http://www.cs.virginia.edu/~eos/papers/cs_2004_21.pdf"><i>Classpects</i></a>  by Kevin Sullivan and Hridesh Rajan. 

wordpress_url: http://jonasboner.com/?p=46
---
<p>
<br />
<h2> Introduction </h2>
</p>

<p>
This article is introducing <i>HyperBeans</i>, a proposal for a framework for <a href="http://domino.watson.ibm.com/library/cyberdig.nsf/0/2a4097e93456d0cf85256ca9006dac29?OpenDocument">Symmetric Aspect-Oriented Software Development</a>  in <b>plain</b> Java (i.e. no extensions to Java is being used). These ideas are based on the work I have done in <i><a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a></i>  and in the <a href="http://dev2dev.bea.com/pub/a/2005/08/jvm_aop_2.html">JVM support for AOP</a>  in <i>JRockit</i> and are loosely based on the work on <a href="http://www.cs.virginia.edu/~eos/papers/cs_2004_21.pdf"><i>Classpects</i></a>  by Kevin Sullivan and Hridesh Rajan. 
</p>

<p>
If you don't care about the research and background behind the ideas presented in this article (and want to see some code right away), then you should skip the rest of this section.
</p>

<p>
Aspect-Oriented Software Development (AOSD) in general, tries, among other things, to address the problem defined as <a href="http://www.research.ibm.com/hyperspace/Papers/tr21452.ps">the tyranny of dominant decomposition</a> , in which the prominent concerns, usually the business logic, dominate the class design, especially the inheritance hierarchy (as observed in <a href="http://www-128.ibm.com/developerworks/java/library/j-aopwork4/">this article</a>).  
</p>

<p>
Historically there has been (and still is) two different main philosophies in AOSD, the asymmetric philosophy and the symmetric philosophy.
A detailed discussion about their semantic and philosophical differences is out of the scope for this article (read <a href="http://domino.watson.ibm.com/library/cyberdig.nsf/0/2a4097e93456d0cf85256ca9006dac29?OpenDocument">this article</a>  for a detailed discussion). </p>

<p>
Juri Memmert has written a good <a href="http://www.jpmdesign.net/wordpress/2005/08/04/symmetry-vs-asymmetry/">introductory article</a> on the subject in which he defines the different philosophies like this:
</p>

<blockquote>
<b>The asymmetric philosophy</b>

<p>An asymmetric approach to AOSD relies on the notion that there is a base body of code that is then augmented with aspects. There is a concept ional difference (and an implementation difference) between the base and the aspects so that an aspect can not serve as the base of another composition. Most asymmetric approaches use language extensions to declare aspects as first class entities.
</p>
	 
<b>The symmetric philosophy</b>

<p>A symmetric approach to AOSD is based on the notion that all concerns in a system are created equal and, in the asymmetric terminology, can serve as both aspect and base in different compositions. Most symmetric approaches use programming languages as-is, although there are approaches that rely on language extensions as well.
</p>
</blockquote>

<p>
The leading implementation for asymmetric AOSD is <a href="http://www.eclipse.org/aspectj/"><i>AspectJ</i></a>, while the most well-known symmetric implementation is <a href="http://www.research.ibm.com/hyperspace/HyperJ/HyperJ.htm"><i>Hyper/J</i></a> (now part of the <i>Concern Manipulation Environment</i> (CME) project).
</p> 

<p>  
Asymmetric AOSD has so far been the dominant way of implementing AOSD in Java, and in the enterprise space at large. There has been, and still is, a lot of debate in the research community around whether the symmetric or the asymmetric philosophy is the best way of implementing AOSD and many papers have been written on the subject (see the reference section at the end).
</p>

<p>
When implementing the <i>AspectWerkz</i> AOP framework  (which now has been merged with <i>AspectJ</i>), I have been involved in efforts trying to stretch the boundaries of asymmetric AOSD and even though I believe that the asymmetric approach is the preferable in many cases, it definitely has some shortcomings. For example, asymmetric AOSD addresses the problem of 'the tyranny of dominant decomposition' by allowing us to modularize all concerns, but the dominant concern, using aspects. Since the dominant concern needs to serve as "base", the decision deciding which concern should be seen as the dominant one still needs to be taken, and this is a decision that should not be taken lightly since it is something that is usually very hard to change.
</p>

<p>
When taking a look at how a symmetric approach handles the above given problem, I find the symmetric solution very natural and appealing (at least conceptually). In which, if using <i>Hyper/J</i>'s terminology, a system is seen as a multi-dimensional hyperspace, which is built up using different hyperslices (dimensions). A hyperslice is the abstraction of a concern, which can be built up by many components.  This gives you the possibility of viewing the hyperspace (your system) differently in regards to different hyperslices (concerns); you have the possibility of looking at the system from the point of view (concern) that you currently want. 
</p>

<p>
I do not want to take any position in regards to if symmetric AOSD is a (or will be a) serious contender to asymmetric AOSD. I simply have not used the symmetric approach to solve real world problems enough yet, but I do believe that it is something worth exploring more. So, let's take a look at the proposal.
</p>

<h2> HyperBeans â€“ multi-dimensional POJOs </h2>

<p>
There is no the distinction between classes and aspects, e.g. no need for one concern to serve as "base", all there is is <i>HyperBeans</i>. <i>HyperBeans</i> are regular Plain Old Java Objects (POJOs), they are instantiated with <tt>new</tt> and you work with them just as with regular classes, no configuration file or similar is needed.
</p>

<p>
Similarly, there is no the distinction between methods and <i>advice</i>, there are just regular methods, which can be invoked explicitly (like regular methods) or implicitly (when a join point is being executed - like a regular <i>advice</i>).
</p>

<h2> Deployment and undeployment </h2>

<p>
<i>HyperBeans</i> are instantiated using the <tt>new</tt> keyword, which will call the constructor and instantiate the HyperBean just like any other POJO. However, the constructors can also control deployment of the HyperBean. 
</p>

<p>
Deployment of a HyperBean means that its "blessed" methods (<i>advice</i>) are weaved in, while undeployment means that the woven code is removed.   
</p>

<p>
You control deployment of a HyperBean by annotating (one or many of) its constructors with the <tt>@Deploy</tt> annotation. This example shows how to deploy a HyperBean as a singleton (more on other instantiation models later):
</p>

<pre>
public class POJO {

    @Deploy
    public POJO() {    	
    }

    ... // remaining methods omitted 
}
</pre>

<p>
Since there is no such thing as 'destructors' in Java, we are handling undeployment of HyperBeans by annotating a regular Java method (static or member) with the <tt>@Undeploy</tt> annotation. This means that when such a method is invoked, the HyperBean will be undeployed. It also give us the possibility of doing additional clean up (closing resources etc.) if necessary:

</p>

<pre>
public class POJO {

    @Undeploy
    public void close() {
        // clean up - close resources etc.
    }

    ... // remaining methods omitted 
}
</pre>

<h2> Instantiation models </h2>

<p>
You can control instantiation model (also called the deployment scope) of the HyperBean by adding a special argument to the constructor. This special argument defines the deployment scope for the HyperBean and needs to be annotated with the <tt>@Scope</tt> annotation. What this means is that the HyperBean will be deployed with the scope defined by the type of the argument.   
</p>

<p>
For example, adding the argument <tt>@Scope Thread scope</tt> to a constructor, (which is annotated with the <tt>@Deploy</tt> annotation), will deploy the HyperBean with the scope of this particular thread. 
</p>

<p>
Here are all the currently supported instantiation models:

<table border="1">
<tr>
	<th>Type annotated with @Scope</th>
	<th>Instantiation model</th>
</tr>
<tr>
	<td><tt>No argument with a @Scope annotation</tt></td>
	<td>Singleton</td>
</tr>
<tr>
	<td><tt>Thread</tt></td>
	<td>Per Thread</td>
</tr>
<tr>
	<td><tt>Class</tt></td>
	<td>Per Type</td>
</tr>
<tr>
	<td><tt>Instance</tt> (but not of type <tt>Class</tt> or <tt>Thread</tt>)</td>
	<td>Per Instance</td>
</tr>

</table>
</p>

Here are some examples:

<pre>
public class POJO {

    /** Singleton deployment */
    @Deploy
    public POJO() {    	
    }

    /** Per Type deployment */
    @Deploy
    public POJO(@Scope Class scope) {    	
    }

    /** Per Instance deployment */
    @Deploy
    public POJO(@Scope SomeType scope) {    	
    }

    /** Per Thread deployment */
    @Deploy
    public POJO(@Scope Thread scope) {    	
    }

    ... // remaining methods omitted 
}
</pre>

<p>
The current semantics for the <tt>@Scope</tt> annotation is that it:
<ul>
<li>
Narrows the scope for the matching. For example using the <i>Per Type</i> instantiation model will add an implicit <tt>&& within(scope)</tt> to the pointcuts defined in the HyperBean (same as in AspectJ).   
</li>
<li>
Controls the life cycle. The HyperBean will have the same life cycle as the instance annotated with the <tt>@Scope</tt> annotation.
</li>
<li>
Controls state management. Tied to the life cycle.
</li>
</ul>
</p>

<h2> Control flow management - no more cflow </h2>

<p>
There is no more any need for the <i>cflow</i> pointcut (as defined by <i>AspectJ</i>). Instead we suggest a simple programmatic model for control flow management of HyperBean deployment. I believe that the same functionality can be reached by a combination of the <i>Per Thread</i> instantiation model and the deployment/undeployment API. This approach has similarities with the work done in <i><a href="http://caesarj.org/">CaesarJ</a></i> and its concept of a <tt>deploy {..}</tt> block. Here is an example:
</p>

<p>
You have a HyperBean that can be deployed on a per-thread basis:

<pre>
class POJO {
    @Deploy
    public POJO(@Scope Thread scope) {    	
    }

    @Undeploy
    public void close() {
    }

    ... // remaining methods omitted 
}
</pre>
</p>

<p>
Then you can use the following idiom to achieve fine grained control flow (cflow) management:

<pre>
POJO hyperBean;
try {
    hyperBean = new POJO(Thread.currentThread()); // deploys the HyperBean to the current control flow ONLY
    
    ... // do stuff - the HyperBean is woven into this control flow ONLY

} finally {
    hyperBean.close(); // undeploy the HyperBean from the control flow
}
</pre>
</p>

<p>
If you don't want to have this be tangled with your application logic, you can of course put the block in an <i>advice</i>, (and have its HyperBean be a singleton and instantiated somewhere else):

<pre>
@Around(..)
public Object cflowAdvice(InvocationContext ctx) {
    POJO hyperBean;
    Object result;
    try {
        hyperBean = new POJO(Thread.currentThread()); 
        result = ctx.proceed();
    } finally {
         hyperBean.close(); 
    }
    return result;
}
</pre>

</p>

<h2> Cross-cutting methods - advice </h2>

<p>
So how do we define these "blessed" methods? They are defined using Java 5 annotations, in a similar fashion to <i>AspectWerkz</i>'s and <i>AspectJ 5</i>'s annotation style of development, but mixed with the API defined by the JVM support for AOP in <i>JRockit</i> (as described <a href="http://dev2dev.bea.com/pub/a/2005/08/jvm_aop_2.html">in this article</a> ).
</p>

<p>
Let's take a look at an example:
</p>
 
<pre>
public class POJO {
 
    @Before("call(Foo.new(..))")
    public void doSomething() {
        ... // do something before an instance of Foo is created
    }

    ... // remaining methods omitted 
}
</pre>

<p>
This is a regular POJO with one "blessed" method that performs some action before an instance of <tt>Foo</tt> is created.  There's really nothing special with this class apart from that one of its method is annotated with a special annotation borrowed from the annotation style syntax in <i>AspectJ</i>.  Now let's take a look at a (slightly) more interesting example, one that makes use of contextual information.
</p>

<pre>
public class POJO {
 
    @Before("call(@test.TraceMe * *.*(..))")
    public static void traceBefore(@CalleeMethod Method callee) {
        System.out.println("--> " + callee.toString());
    }
  
    @After("call(@test.TraceMe * *.*(..))")
    public static void traceAfter(@CalleeMethod Method callee) {
        System.out.println("< -- " + callee.toString());
    }

    ... // remaining methods omitted 
}
</pre>

<p>
This is a regular POJO with two different "blessed" methods (that are tracing 
invocations to all methods that are annotated with the <tt>@Trace</tt> annotation). Contextual information (like caller and callee method, caller and callee instance, parameters, return value etc.) is retrieved using annotated parameters borrowed from the <i>JRockit</i> API for AOP . 
</p>

<p>
Here is a list of the current set of defined annotations and their meaning:
</p>
<p>
<table border="1">
<tr>
	<th>Annotation</th>
	<th>Exposes</th>
</tr>
<tr>
	<td><tt>@CalleeMethod</tt>
	</td>
	<td>The callee method (method, constructor, static initializer)
	</td>
</tr>
<tr>
	<td><tt>@CallerMethod</tt>
	</td>
	<td>The caller method (method, constructor, static initializer)
	</td>
</tr>
<tr>
	<td><tt>@Callee</tt>
	</td>
	<td>The callee instance
	</td>
</tr>
<tr>
	<td><tt>@Caller</tt>
	</td>
	<td>The caller instance
	</td>
</tr>
<tr>
	<td><tt>@Arguments</tt>
	</td>
	<td>The invocation arguments (wrapped in an object array)
	</td>
</tr>
<tr>
	<td><tt>@Returning</tt>
	</td>
	<td>The return value (used in 'after returning advice')
	</td>
</tr>
<tr>
	<td><tt>@Throwing</tt>
	</td>
	<td>The exception thrown from a method (used in 'after throwing advice')
	</td>
</tr>
</table>
</p>

<p>
These annotated arguments (except caller and callee method) also works as 'filters', the same is true for all unannotated arguments which are treated as the regular arguments to the method (or the field value about to be set etc.). The methods can be either member or static (dependent on if you want to keep state in the instance or not).
</p>

<p>
Since some people might be curious how "around advice" (i.e. 'interception') is handled, below is an example of how to implement the same functionality as in the class above using an "around advice". Here we introduce the <tt>InvocationContext</tt> abstraction (similar to the <tt>ProceedingJoinPoint</tt> abstraction in <i>AspectJ</i>), which serves as the context on which we can invoke the <tt>proceed()</tt> method in order to continue with the execution flow.  
</p>

</pre><pre>
public class POJO {
 
    @Around("call(@test.TraceMe * *.*(..))")
    public Object trace(InvocationContext ctx, 
                        @CalleeMethod Method callee) {
        System.out.println("--> " + callee.toString());
        Object result = ctx.proceed();
        System.out.println("< -- " + callee.toString());
        return result;
    }

    ... // remaining methods omitted 
}
</pre>

<h2> Implementation </h2>

<p>
I have prototyped HyperBeans using the <a href="http://dev2dev.bea.com/pub/a/2005/08/jvm_aop_1.html">JVM support for AOP in JRockit</a>. The implementation was actually very simple and shows the power of the JRockit API (the JRockit prototype is <a href="http://forums.bea.com/bea/forum.jspa?forumID=600000004">available now</a> for those who wants to try it out).  
</p>
</pre>
