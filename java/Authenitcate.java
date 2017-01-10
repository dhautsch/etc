import java.util.Hashtable;
import javax.naming.Context;
import javax.naming.NamingException;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;

public class Authenitcate {

	public static void main(String[] args) {
		//
		// java Authenticate ldap://ldap_host:389 uid=USERID,ou=people,ou=corporate,dc=companyName,dc=com PASSWORD_ENV_VAR
		// 		PASSWORD_ENV_VAR: the environment variable that contains the password.
		//
		if (args.length != 3) {
			System.out.println("Usage: Authenticate PROVIDER_URL SECURITY_PRINCIPLE PASSWORD_ENV_VAR");
			System.exit(1);
		}
		DirContext ctx_ = null;
		Hashtable<String,Object> env_ = new Hashtable<String,Object>();
		env_.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		env_.put(Context.SECURITY_AUTHENTICATION, "simple");
		env_.put(Context.PROVIDER_URL, args[0]);
		env_.put(Context.SECURITY_PRINCIPAL, args[1]);
		env_.put(Context.SECURITY_CREDENTIALS, System.getenv(args[2]));
		try {
			ctx_ = new InitialDirContext(env_);
			System.out.println("LOGIN SUCCESSFUL " + ctx_.getAttributes(env_.get(Context.SECURITY_PRINCIPAL).toString()));
			System.exit(0);
		} catch (Exception e) {
			System.out.println(e);
		}
		finally {
			if (ctx_ != null) try { ctx_.close(); } catch (NamingException e) {}
		}
		System.exit(1);
	}

}
