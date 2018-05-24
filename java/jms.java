// http://middlewaremagic.com/jboss/?p=334
import javax.management.*;
import java.io.*;
import java.util.*;
import java.rmi.*;
import javax.naming.*;
import java.io.*;
public class ManageJMSQueue
   {
      private MBeanServerConnection server=null;
	private String _url;
	private String _queue;
	private String _user;
	private String _pass;

      public ManageJMSQueue()
      {
            try{
            Hashtable<String,String> ht=new Hashtable<String,String>();
            ht.put(Context.INITIAL_CONTEXT_FACTORY,"org.jboss.security.jndi.JndiLoginInitialContextFactory");
            ht.put(Context.PROVIDER_URL, _url);
            ht.put(Context.SECURITY_PRINCIPAL, _user);
            ht.put(Context.SECURITY_CREDENTIALS, _pass);
            System.out.println("nt 1- Gotting InitialContext...... ");
            Context ctx = new InitialContext(ht);
            System.out.println("nt 2- Got InitialContext: "+ctx);
            server = (MBeanServerConnection) ctx.lookup("jmx/invoker/RMIAdaptor");
            }
            catch(Exception e)
            {
                System.out.println("nnt Exception inside ManageJMSQueue..."+e);
            }
      }
 
      public void monitorJMS() throws Exception
      {
           ObjectName objectName=new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue");
           System.out.println("nnServerPeer = "+ (javax.management.ObjectName)server.getAttribute(objectName, new String("ServerPeer")));
           System.out.println("QueueName = "+ (String)server.getAttribute(new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue"), new String("Name")));
           System.out.println("JNDI Name = "+ (String)server.getAttribute(new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue"), new String("JNDIName")));
           System.out.println("FullSize = "+ (Integer)server.getAttribute(new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue"), new String("FullSize")));
      }
 
     public void listAllJMS_Messages() throws Exception
      {
           ObjectName objectName=new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue");
           List<org.jboss.jms.message.JBossTextMessage> messages=(List<org.jboss.jms.message.JBossTextMessage>)server.invoke(objectName, "listAllMessages" , null, null);
           int count=0;
           for(org.jboss.jms.message.JBossTextMessage msg : messages)
                    System.out.println((++count)+"t"+msg.getText());
      }
 
     public void removeAllJMS_Messages() throws Exception
      {
           String queueName=(String)server.getAttribute(new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue"), new String("Name"));
           System.out.println("nt Removing all JMS Messages from Queue: "+queueName);
           server.invoke(new ObjectName("jboss.messaging.destination:name=DLQ,service=Queue"), "removeAllMessages" , null, null);
           System.out.println("nt All the Messages are removed from JMS Queue: "+queueName);
      }
 
     public static void main(String ar[]) throws Exception
       {

		_url = ar[0];
		_queue = ar[1];
		_user  = ar[2];
		_pass  = System.getenv(ar_[3]);

            ManageJMSQueue ref=new ManageJMSQueue();
            ref.monitorJMS();
            System.out.println("nt Following Messages Are present inside the JMS Queue:");
            ref.listAllJMS_Messages();
            BufferedReader br=new BufferedReader(new InputStreamReader(System.in));
            System.out.print("nn Please Specify (yes/no) to delete all the messages from JMS Queue ? ");
            String answer="";
            if((answer=br.readLine()).equals("yes"))
                             ref.removeAllJMS_Messages();
            br.close();
       }
  }
