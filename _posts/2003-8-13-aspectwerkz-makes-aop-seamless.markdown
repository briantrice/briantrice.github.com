--- 
wordpress_id: 13
layout: post
title: AspectWerkz makes AOP seamless
wordpress_url: http://jonasboner.com/?p=13
---
<p>
Today me and <a href="http://blogs.codehaus.org/people/avasseur/">Alex</a> released the 0.8 version of <a href="http://aspectwerkz.codehaus.org">AspectWerkz</a>.
</p>

<p>
This new release have been tested and verified to work for servlets and all types of EJBs under WebLogic Server 7 and 8.1 using both online and offline mode. 
</p>

<p>
JMangler has been thrown out for a completely new and customized solution that apart from solving some of the shortcomings and bugs in JMangler also provides completely new and interesting possibilities. Here are the options currently supported for online mode:
</p>

<p>
		<ul>
                   <li>
                        HotSwap<br/>
                        A first JVM launchs your target application in a second JVM.
                        The first JVM hooks AspectWerkz in the second one just before the <i>main class</i> (and all dependencies) gets loaded,
                        and then connects to the stdout / stderr / stdin stream ot the
                        second JVM to make them appear as usual thru the first JVM.<br/>
                    </li>
                    <li>
                        Transparent bootclasspath<br/>
                        For JVM or java version like 1.3 which don't support <i>class replacement at runtime (HotSwap)</i>, this option
                        allows for same mechanism by putting an enhanced class loader in the target
                        application VM bootclasspath.<br/>
                    </li>
                    <li>
                        Native HotSwap<br/>
                        A native C JVM extension running in the target application VM handles the replacement of the
                        class loader by the enhanced one.<br/>
                    </li>
                    <li>
                        Remote HotSwap<br/>
                        The application VM is launched <i>suspended</i>. The replacement of the enhanced class loader is done
                        thru a separate manual process, which can easily be scripted.<br/>
                    </li>
                    <li>
                        Prepared bootclasspath<br/>
                        The enhanced class loader is builded and packaged as a jar file in a first separate manual process, which can easily be scripted.
                        The application VM is launched with options to use this enhanced class loader.<br/>
                    </li>
                    <li>
			Auto detection of java 1.3 and java 1.4
                    </li>
                </ul>
</p>

<p>
Some of the other new features are:
</p>

<p>
                    <ul>
                        <li>
                            JDK 1.3 compatibility.
                        </li>
                        <li>
                            Runtime attributes -> XML compiler (no more metaData dir and meta-data compilers needed, one aspectwerkz.xml per application).
                        </li>
                        <li>
                            Offline compiler refactored. Now support rollback on error facility.
                        </li>
                        <li>
                            Released under a BSD-style license.
                        </li>
                        <li>
                            Non-reentrancy option for join points.
                        </li>
                        <li>
                            Definition validator.
                        </li>
                        <li>
                            Documentation updated and reorganized.
                        </li>
                    </ul>

</p>

<p>
The new release can be downloaded from <a href="http://aspectwerkz.codehaus.org/releases.html">here</a>.
</p>
<p>
A more detailed paper describing the new online architecture can be downloaded from <a href="http://aspectwerkz.codehaus.org/downloads">here</a>
</p>.
