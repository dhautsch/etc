import java.util.Hashtable;
import javax.naming.Context;
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
		Hashtable<String,Object> env = new Hashtable<String,Object>();
		env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		env.put(Context.SECURITY_AUTHENTICATION, "simple");
		env.put(Context.PROVIDER_URL, args[0]);
		env.put(Context.SECURITY_PRINCIPAL, args[1]);
		env.put(Context.SECURITY_CREDENTIALS, System.getenv(args[2]));
		try {
			DirContext ctx = new InitialDirContext(env);
			System.out.println("LOGIN SUCCESSFUL " + ctx.getAttributes(env.get(Context.SECURITY_PRINCIPAL).toString()));
			System.exit(0);
		} catch (Exception e) {
			System.out.println(e);
		}
		System.exit(1);
	}

}
