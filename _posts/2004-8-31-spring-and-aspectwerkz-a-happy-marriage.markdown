--- 
wordpress_id: 24
layout: post
title: Spring and AspectWerkz - A Happy Marriage
wordpress_url: http://jonasboner.com/?p=24
---
<p /> 
<a href="http://www.springframework.org/">The Spring Framework</a> is a very powerful library for J2EE development. It comes with an AOP implementation (based on proxies) that is in many cases sufficient in terms of what you need to do. However, there are many situations where you need a more full-blown AOP framework (such as <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a>) to do the job. 

<p /> 
On the other hand <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a> (even though it has a decent API for configuration and management) could sometimes benefit from more finegrained and expressive configuration and life-cycle management, which is one thing that <a href="http://www.springframework.org/">Spring</a> does very well.

<p /> 
In short, it is sometimes beneficial to use these two frameworks together and I will now show you a first step on how you can make that happen.

<p /> 
<a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a> has a very open architecture in regards to instantiation, configuration and management of the aspects. Here I will show you how you can make use of this to take control over your aspects using <a href="http://www.springframework.org/">Spring</a>. (The concepts are the same for <a href="http://picocontainer.org/">PicoContainer</a>, <a href="http://jakarta.apache.org/hivemind/index.html">HiveMind</a> or a home-grown IoC implementation.)

<p /> 
In <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a> instantiation, management and configuration of aspects is handled by an "aspect container" and to make it easier for users to provide their own custom implementation it provides the abstract <tt>org.codehaus.aspectwerkz.aspect.AbstractAspectContainer</tt>
class which handles all the nitty-gritty details. 
<p /> 
All we have to do is to extend the <tt>org.codehaus.aspectwerkz.aspect.AbstractAspectContainer</tt> class and implement the abstract <tt>Object createAspect()</tt> method.
<p /> 
So let us do that. Here is the implementation of our <tt>SpringAspectContainer</tt>:
<pre> 
public class SpringAspectContainer extends AbstractAspectContainer {

    public static final String SPRING_ASPECT_CONTAINER_CONFIG = "spring-bean-config.xml";

    /**
     * The Spring bean factory.
     */
    private XmlBeanFactory m_factory = null;

    /**
     * Creates a new aspect container strategy that uses the Spring framework to manage aspect instantiation and
     * configuaration.
     *
     * @param crossCuttingInfo the cross-cutting info
     */
    public SpringAspectContainer(final CrossCuttingInfo crossCuttingInfo) {
        super(crossCuttingInfo);
    }

    /**
     * Creates a new aspect instance.
     *
     * @return the new aspect instance
     */
    protected Object createAspect() {
        if (m_factory == null) {
            InputStream is = null;
            try {
                is = ClassLoader.getSystemResourceAsStream(SPRING_ASPECT_CONTAINER_CONFIG);
                m_factory = new XmlBeanFactory(is);
            } finally {
                try {
                    is.close();
                } catch (Throwable e) {
                    throw new WrappedRuntimeException(e);
                }
            }
        }

        // here we are letting Spring instantiate the aspect based on its name 
        // (the m_infoPrototype field is the CrossCuttingInfo instance passed to the base class) 
        return m_factory.getBean(m_infoPrototype.getAspectDefinition().getName());
    }
}
</pre> 

<p /> 
This is all that is needed implementation wise. Now we only have to define which aspects should be managed by our new container and configure the aspect in the Spring bean config file. 

<p /> 
To tell the <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a> system that we want to deploy a specific aspect in our custom aspect container we have to specify that in the regular <tt>aop.xml</tt> file like this:

<pre> 
&lt;aspect class="some.package.MyAspect" container="some.other.package.SpringAspectContainer"&gt;
    ...
&lt;/aspect&gt;
</pre> 

<p /> 
 For details on the <tt>aop.xml</tt> file (what it is, how it is used etc.) see the <a href="http://aspectwerkz.codehaus.org/startup_and_runtime_issues.html#Handling_several_Aspects_across_several_deployed_applications">online documentation</a>.

<p /> 
To configure the aspect we just configure it like any other <a href="http://www.springframework.org/">Spring</a> bean class:

<pre> 
&lt;?xml version="1.0" encoding="UTF-8"?&gt;

&lt;!DOCTYPE beans PUBLIC "-//SPRING//DTD BEAN//EN" "http://www.springframework.org/dtd/spring-beans.dtd"&gt;

&lt;beans&gt;
    &lt;bean id="some.package.MyAspect"
          class="some.package.MyAspect"
          singleton="false"
          init-method="intialize"&gt;
        &lt;property name="someProperty"&gt;
            ...
        &lt;/property&gt;
        ...
    &lt;/bean&gt;
    ...
&lt;/beans&gt;
</pre> 

<p /> 
For details on how to define your bean classes see the <a href="http://www.springframework.org/documentation.html">Spring documentation</a>. But here are some explainations:
<ul>
    <li>
     <b>id</b> - specifies the name of the aspect if a custom name is define you that else use the class name of the aspect (which is the default name). Mandatory.
    </li>
    <li>
    <b>class</b> - specifies the class name of the aspect. Mandatory.
    </li>
    <li>
    <b>singleton</b> - specifies if the aspect will be instantiated using the prototype pattern or not. Mandatory.
    </li>
    <li>
    <b>init-method</b> - the init-method is the method that you are using to initialize the aspect. This method will be called when all the properties have been set. Optional.
    </li>
    <li>
    <b>property</b> - the metadata that you want to pass to the aspect (see the Spring documentation for details on how how to define properties). Optional.
    </li>
</ul>

<p /> 
<a href="http://www.springframework.org/">Spring</a> has great support for passing in expressive metadata. It for example allows you to pass in lists, maps of for example strings, primitives or custom objects, and arrange them pretty much as you like.

<p /> 
Here is a more interesting example on how you can configure an aspect using Spring's properties. This aspect implements role-based security and is part of the <a href="http://docs.codehaus.org/display/AWARE">AWare</a> aspect library:

<pre> 
&lt;bean id="org.codehaus.aware.security.RoleBasedAccessProtocol"
    class="org.codehaus.aware.security.RoleBasedAccessProtocol"
    singleton="false"
    init-method="intialize"&gt;

    &lt;property name="type"&gt;
        &lt;value&gt;JAAS&lt;/value&gt;
    &lt;/property&gt;

    &lt;property name="roles"&gt;
        &lt;list&gt;
            &lt;value&gt;admin&lt;/value&gt;
            &lt;value&gt;jboner&lt;/value&gt;
        &lt;/list&gt;
    &lt;/property&gt;

    &lt;property name="permissions"&gt;
        &lt;list&gt;
            &lt;bean class="org.codehaus.aware.security.Permission"&gt;
                &lt;property name="role"&gt;
                    &lt;value&gt;jboner&lt;/value&gt;
                &lt;/property&gt;
                &lt;property name="className"&gt;
                    &lt;value&gt;org.codehaus.aware.security.SecurityHandlingTest&lt;/value&gt;
                &lt;/property&gt;
                &lt;property name="methodName"&gt;
                    &lt;value&gt;authorizeMe1&lt;/value&gt;
                &lt;/property&gt;
            &lt;/bean&gt;

           &lt;bean class="org.codehaus.aware.security.Permission"&gt;
                &lt;property name="role"&gt;
                    &lt;value&gt;jboner&lt;/value&gt;
                &lt;/property&gt;
                &lt;property name="className"&gt;
                    &lt;value>org.codehaus.aware.security.SecurityHandlingTest&lt;/value&gt;
                &lt;/property&gt;
                &lt;property name="methodName"&gt;
                    &lt;value&gt;authorizeMe2&lt;/value&gt;
                &lt;/property&gt;
            &lt;/bean&gt;
        &lt;/list&gt;
    &lt;/property&gt;

&lt;/bean&gt;
 
</pre> 

<p /> 

You can find the code for the <tt>SpringAspectContainer</tt> along with many other reusable aspects in the <a href="http://docs.codehaus.org/display/AWARE">AWare</a> library.  Which is a community-driven OSS library for reusable aspects for <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a>.

<p />
