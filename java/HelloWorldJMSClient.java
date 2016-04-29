/*
 * JBoss, Home of Professional Open Source

 * Copyright 2014, Red Hat, Inc. and/or its affiliates, and individual
 * contributors by the @authors tag. See the copyright.txt in the
 * distribution for a full listing of individual contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * From
 *	helloworld-jms/src/main/java/org/jboss/as/quickstarts/jms/HelloWorldJMSClient.java
 * at
 *	http://github.com/jboss-developer/jboss-eap-quickstarts/tree/6.2.x
 */

/*
	Modified for our environment by don@hautsch.com 2016-04-28.
	
	Add javax.jms.jar and jboss-client.jar to you build path.
	
	Added
		env.put("jboss.naming.client.connect.options.org.xnio.Options.SASL_POLICY_NOPLAINTEXT", "false");
	which helped to get around ApplicationRealm being setup on the remoting port
		<subsystem xmlns="urn:jboss:domain:remoting:1.1">
		<connector name="remoting-connector" socket-binding="remoting" security-realm="ApplicationRealm"/>
		</subsystem>
	in standalone-full-ha.xml
	
Additionally, I had to make following additions to standalone-full-ha.xml
so this external client would work
                  <journal-min-files>2</journal-min-files>

                  <connectors>
- <netty-connector name="netty" socket-binding="messaging"/>
- <netty-connector name="netty-throughput" socket-binding="messaging-throughput">
- <param key="batch-delay" value="50"/>
- </netty-connector>
                      <in-vm-connector name="in-vm" server-id="0"/>
                  </connectors>

                  <acceptors>
- <netty-acceptor name="netty" socket-binding="messaging"/>
- <netty-acceptor name="netty-throughput" socket-binding="messaging-throughput">
- <param key="batch-delay" value="50"/>
- <param key="direct-deliver" value="false"/>
- </netty-acceptor>
                      <in-vm-acceptor name="in-vm" server-id="0"/>
                  </acceptors>

...

                  </address-settings>

                  <jms-connection-factories>
- <connection-factory name="RemoteConnectionFactory">
- <connectors>
- <connector-ref connector-name="netty"/>
- </connectors>
- <entries>
- <entry name="RemoteConnectionFactory"/>
- <entry name="java:jboss/exported/jms/RemoteConnectionFactory"/>
- </entries>
- </connection-factory>
                      <connection-factory name="InVmConnectionFactory">
                          <connectors>
                              <connector-ref connector-name="in-vm"/>

...

          <socket-binding name="remoting" port="4400"/>
          <socket-binding name="txn-recovery-environment" port="4700"/>
          <socket-binding name="txn-status-manager" port="4800"/>
- <socket-binding name="messaging" port="5445"/>
- <socket-binding name="messaging-throughput" port="5455"/>
          <outbound-socket-binding name="mail-smtp">
              <remote-destination host="localhost" port="25"/>
          </outbound-socket-binding>
 */
package org.jboss.as.quickstarts.jms;

import java.util.logging.Logger;
import java.util.Properties;

import javax.jms.Connection;
import javax.jms.ConnectionFactory;
import javax.jms.Destination;
import javax.jms.MessageConsumer;
import javax.jms.MessageProducer;
import javax.jms.Session;
import javax.jms.TextMessage;
import javax.naming.Context;
import javax.naming.InitialContext;

public class HelloWorldJMSClient {
	private static final Logger log = Logger.getLogger(HelloWorldJMSClient.class.getName());

	// Set up all the default values
	private static final String DEFAULT_MESSAGE = "Hello, World!";
	private static final String DEFAULT_MESSAGE_COUNT = "1";
	private static final String DEFAULT_USERNAME = "REPLACE WITH USER ID or use jvm -Dusername=UID";
	private static final String DEFAULT_PASSWORD = "REPLACE WITH PASSWORD or use jvm -Dpassword=PASSWORD";
	private static final String INITIAL_CONTEXT_FACTORY = "org.jboss.naming.remote.client.InitialContextFactory";
//	private static final String PROVIDER_URL = "remote://dlwh-ap150:4401,remote://dlwh-ap151:4401";
//	private static final String DEFAULT_DESTINATION = "queue/crf.mdm.inbound.jms.queue";
	private static final String DEFAULT_CONNECTION_FACTORY = "jms/RemoteConnectionFactory";
	private static final String PROVIDER_URL = "remote://dlwh-ap153:4401";
	private static final String DEFAULT_DESTINATION = "queue/siperian.sif.jms.queue";

	public static void main(String[] args) throws Exception {

		ConnectionFactory connectionFactory = null;
		Connection connection = null;
		Session session = null;
		MessageProducer producer = null;
		MessageConsumer consumer = null;
		Destination destination = null;
		TextMessage message = null;
		Context context = null;

		try {
			// Set up the context for the JNDI lookup
			final Properties env = new Properties();
			env.put(Context.INITIAL_CONTEXT_FACTORY, INITIAL_CONTEXT_FACTORY);
			env.put(Context.PROVIDER_URL,
					System.getProperty(Context.PROVIDER_URL, PROVIDER_URL));
			env.put(Context.SECURITY_PRINCIPAL,
					System.getProperty("username", DEFAULT_USERNAME));
			env.put(Context.SECURITY_CREDENTIALS,
					System.getProperty("password", DEFAULT_PASSWORD));
			env.put("jboss.naming.client.connect.options.org.xnio.Options.SASL_POLICY_NOPLAINTEXT", "false");
			
			context = new InitialContext(env);

			// Perform the JNDI lookups
			String connectionFactoryString = System.getProperty(
					"connection.factory", DEFAULT_CONNECTION_FACTORY);
			log.info("Attempting to acquire connection factory \""
					+ connectionFactoryString + "\"");
			connectionFactory = (ConnectionFactory) context
					.lookup(connectionFactoryString);
			log.info("Found connection factory \"" + connectionFactoryString
					+ "\" in JNDI");

			String destinationString = System.getProperty("destination",
					DEFAULT_DESTINATION);
			log.info("Attempting to acquire destination \"" + destinationString
					+ "\"");
			destination = (Destination) context.lookup(destinationString);
			log.info("Found destination \"" + destinationString + "\" in JNDI");

			// Create the JMS connection, session, producer, and consumer
			connection = connectionFactory.createConnection(
					System.getProperty("username", DEFAULT_USERNAME),
					System.getProperty("password", DEFAULT_PASSWORD));
			
			session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
			producer = session.createProducer(destination);
			consumer = session.createConsumer(destination);
			connection.start();

			int count = Integer.parseInt(System.getProperty("message.count",
					DEFAULT_MESSAGE_COUNT));
			String content = System.getProperty("message.content",
					DEFAULT_MESSAGE);

			log.info("Sending " + count + " messages with content: " + content);

			// Send the specified number of messages
			for (int i = 0; i < count; i++) {
				message = session.createTextMessage(content);
				producer.send(message);
			}

			log.info("Receiving messages");

			// Then receive the same number of messages that were sent
			for (int i = 0; i < count; i++) {
				message = (TextMessage) consumer.receive(10000);
				if (message != null) {
					log.info("Received message with content " + message.getText());
				}
			}

			log.info("Exiting");

		} catch (Exception e) {
			log.severe(e.getMessage());
			throw e;
		} finally {
			if (context != null) {
				context.close();
			}

			// closing the connection takes care of the session, producer, and
			// consumer
			if (connection != null) {
				connection.close();
			}
		}
	}
}
