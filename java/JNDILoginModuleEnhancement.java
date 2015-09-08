/*

The credentials can be encrypted using the siperian-common.jar, see
Password Encryption in the MDM Configuration Guide.

The AD here is not open so we need to login to AD to do search and authentication.

We do not need to use the java.naming.security.principal and java.naming.security.credentials
to access AD, the user logging in credentials will be used by default by the plugin. If you do want
to use the java.naming.security.principal it is simply the uid because we are using @COMPANY.COM
as postfix.

There are two groups in the SearchFilter.postfix string: SG_LE_SYSADMIN and SG_PROD_SYSADMIN

you can add more by adding
      (memberof=CN=AD_GROUP,OU=PermissionGroups,OU=Groups,DC= COMPANY,DC=COM)
after )(|( from the string beginning and replacing AD_GROUP with the desired group.

This is stored in the database and the column allows a max of 4k chars.

java.naming.security.credentials=470C89E86F3B4563
java.naming.security.principal=a22devl
SearchFilter.postfix=)(|(memberof=CN=SG_LE_SYSADMIN,OU=PermissionGroups,OU=Groups,DC=COMPANY,DC=COM)(memberof=CN=SG_PROD_SYSADMIN,OU=PermissionGroups,OU=Groups,DC=COMPANY,DC=COM)))
SearchFilter.prefix=(&(objectClass=user)(sAMAccountName=
SearchTreeScope=DC=COMPANY,DC=COM
java.naming.factory.initial=com.sun.jndi.ldap.LdapCtxFactory
java.naming.provider.url=ldap://AD.COMPANY.COM:389 
username.postfix=@COMPANY.COM 

 */

package com.siperian.common.security;

import com.siperian.common.SipRuntimeException;
import com.siperian.common.util.StringUtil;
import java.io.IOException;
import java.util.Hashtable;
import java.util.Map;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.InitialDirContext;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import javax.security.auth.Subject;
import javax.security.auth.callback.Callback;
import javax.security.auth.callback.CallbackHandler;
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.PasswordCallback;
import javax.security.auth.callback.UnsupportedCallbackException;
import javax.security.auth.login.FailedLoginException;
import javax.security.auth.login.LoginException;
import javax.security.auth.spi.LoginModule;

import org.apache.log4j.Logger;

/**
 * This code originally was provided by INFA GCS but it has been refactored.
 * 
 * The original is in OrigJNDILoginModuleEnhancement.java
 * 
 * 
 * 
 * @author don@hautsch.com
 * 
 * @version 2015-06-30
 */

public class JNDILoginModuleEnhancement implements LoginModule {

	private static final Logger _log = Logger
			.getLogger(JNDILoginModuleEnhancement.class);

	private CallbackHandler _callbackHandler;
	private Map _options;
	private String _serviceAccount;
	private boolean _principalExists = false;
	private boolean _credentialsExists = false;
	private boolean _SearchTreeScopeExists = false;
	private static final String _usernamePrefix = "username.prefix";
	private static final String _usernamePostfix = "username.postfix";
	private static final String _principle = "java.naming.security.principal";
	private static final String _url = "java.naming.provider.url";
	private static final String _nameCallback = "nameCallback";
	private static final String _credentials = "java.naming.security.credentials";
	private static final String _SearchTreeScope = "SearchTreeScope";
	private static final String _SearchFilterPrefix = "SearchFilter.prefix";
	private static final String _SearchFilterPostfix = "SearchFilter.postfix";

	public void initialize(Subject subject, CallbackHandler handler,
			Map sharedState, Map options) {

		_callbackHandler = handler;

		_options = options;

		_principalExists = _options.containsKey(_principle);

		_credentialsExists = _options.containsKey(_credentials);

		_SearchTreeScopeExists = _options.containsKey(_SearchTreeScope);

		if (_principalExists)
			_serviceAccount = _options.get(_principle).toString();
	}

	public boolean login() throws LoginException {
		NameCallback nameCallback_ = new NameCallback("Name:");

		PasswordCallback passwordCallback_ = new PasswordCallback("Password:", false);

		try {
			_callbackHandler.handle(new Callback[] { nameCallback_,
					passwordCallback_ });

		} catch (IOException ioe_) {
			throw new SipRuntimeException("SIP-10331", null, _callbackHandler,
					ioe_);
		} catch (UnsupportedCallbackException uce_) {
			throw new SipRuntimeException("SIP-10332", null, _callbackHandler,
					uce_);
		}

		int connectCnt_ = _principalExists ? 2 : 1;

		Hashtable options_ = new Hashtable();

		options_.putAll(_options);

		options_.put(_nameCallback, nameCallback_.getName());

		options_.put("java.naming.security.authentication", "simple");

		if (_principalExists) {
			if (_principalExists != _credentialsExists) {
				String msg_ = _credentials
						+ " not defined for Service Account.";

				_log.error(msg_);

				throw new FailedLoginException(msg_);
			}

			if (_principalExists != _SearchTreeScopeExists) {
				String msg_ = _SearchTreeScope
						+ " not defined for Service Account.";

				_log.error(msg_);

				throw new FailedLoginException(msg_);
			}
		}

		for (int i_ = 1; i_ <= connectCnt_; i_++) {
			if (i_ < connectCnt_) {
				options_.put(_principle, makePrinciple(options_.get(_principle)
						.toString()));

				try {
					String s_ = options_.get(_credentials).toString();

					String decryptedPW_ = StringUtil.blowfishDecrypt(s_);

					options_.put(_credentials, decryptedPW_);
				} catch (Exception e_) {
					String msg_ = "Failed to decrypt the Service Account "
							+ _credentials + " password.";

					FailedLoginException fle_ = new FailedLoginException(msg_);

					fle_.initCause(e_);

					_log.error(msg_);

					throw fle_;
				}
			} else {
				options_.put(_principle, makePrinciple(nameCallback_.getName()));

				options_.put(_credentials,

				new String(passwordCallback_.getPassword()));

				passwordCallback_.clearPassword();

				if (_principalExists)
					options_.remove(_SearchTreeScope);
			}

			InitialDirContext jndi_ = null;

			try {
				jndi_ = new InitialDirContext(options_);

				search(options_, jndi_);

				if (i_ == connectCnt_)
					_log.info("JNDI login successful of "
							+ options_.get(_principle) + " to "
							+ options_.get(_url));

			} catch (NamingException ne_) {
				String msg_ = "JNDI login failed of "
						+ options_.get(_principle) + " to "
						+ options_.get(_url);

				FailedLoginException fle_ = new FailedLoginException(msg_);

				fle_.initCause(ne_);

				if (i_ < connectCnt_)
					_log.error("Check Service Account " + _principle + " "
							+ _credentials + " " + msg_);

				throw fle_;
			} finally {
				if (jndi_ != null)
					try {
						jndi_.close();
					} catch (NamingException ne_) {
						_log.warn(
								"Ignoring failure closing JNDI connection to "
										+ options_.get(_url), ne_);
					}
			}
		}

		return true;
	}

	private void search(Hashtable options, InitialDirContext jndi)
			throws LoginException {
		if (options.containsKey(_SearchTreeScope) == false)
			return;

		String searchTreeScope_ = options.get(_SearchTreeScope).toString();

		SearchControls ctrl_ = new SearchControls();

		String[] returnedAttributes_ = { "*" };

		ctrl_.setReturningAttributes(returnedAttributes_);

		ctrl_.setSearchScope(SearchControls.SUBTREE_SCOPE);

		String userName_ = options.get(_nameCallback).toString();

		String searchFilterPrefixStr_ = options.get(_SearchFilterPrefix)
				.toString();

		String searchFilterPostfixStr_ = options.get(_SearchFilterPostfix)
				.toString();

		String searchFilter_ = (searchFilterPrefixStr_ != null) ? searchFilterPrefixStr_
				+ userName_
				: userName_;

		searchFilter_ = (searchFilterPostfixStr_ != null) ? searchFilter_
				+ searchFilterPostfixStr_ : searchFilter_;

		try {
			NamingEnumeration<SearchResult> searchResult_ = jndi.search(

			searchTreeScope_, searchFilter_, ctrl_);

			int n_ = 0;

			while (searchResult_.hasMoreElements()) {
				searchResult_.nextElement();

				n_++;
			}

			if (n_ < 1) {
				throw new FailedLoginException("JNDI login failed of "
						+ options.get(_principle) + " to " + options.get(_url));
			}

			_log.debug("search result count is " + n_ + " for "
					+ (_principalExists ? (_principle + "=" + _serviceAccount + " ")
							: "") + "filter: " + searchFilter_);
		} catch (NamingException ne_) {
			String msg_ = "Check configuration. SearchFilter is "
					+ searchFilter_;

			FailedLoginException fle_ = new FailedLoginException(msg_);

			fle_.initCause(ne_);

			ne_.printStackTrace();

			_log.error(ne_ + " " + msg_);

			throw fle_;
		}
	}

	public boolean commit() throws LoginException {
		return true;
	}

	public boolean abort() throws LoginException {
		return true;
	}

	public boolean logout() throws LoginException {
		return true;
	}

	private String makePrinciple(String username) {
		String username_ = username;

		if (_options.containsKey(_usernamePrefix))
			username_ = _options.get(_usernamePrefix) + username_;

		if (_options.containsKey(_usernamePostfix))
			username_ = username_ + _options.get(_usernamePostfix);

		return username_;
	}
}
