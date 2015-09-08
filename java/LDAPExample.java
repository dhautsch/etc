package com.hautsch;

import javax.naming.*;
import javax.naming.directory.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Hashtable;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class LDAPExample {
	private static DirContext _ctx;
	private static final Pattern _uidPat = Pattern.compile("uid=(\\w+)");
	private static final String _ldapData = "ldapData";
	private static final String _groupElem = "group";
	private static final String _userAttrs[] = { "cn", "employeeType", "uid",
		"mail", "telephonenumber", "fmApplicationCode",
		"fmApplicationName", "fmofficelocation", "fmfloor", "roomnumber",
		"manager", "fmmanageruid" };

	private static final String _ldapSearchGroup = "ou=group,ou=corporate,dc=bogus,dc=com";
	private static final String _ldapSearchGroupKey = "cn";
	private static final String _ldapSearchPeople = "ou=people,ou=corporate,dc=bogus,dc=com";
	private static final String _ldapSearchPeopleKey = "uid";
	private static final String _uniqMember = "uniqueMember";
	private static final String _memberUid = "memberUid";
	private static final String _fmPrimaryOwner = "fmPrimaryOwner";
	private static final List<String> _groupAttrs = Arrays.asList(
			"fmGroupType", "fmApplicationCode", "fmApplicationName", "manager",
			_fmPrimaryOwner, _memberUid, _uniqMember);

	public static Boolean initCtx() {
		// lookup group user
		// /bin/ldapsearch -h enterprise-ldap -b
		// "ou=group,ou=corporate,dc=bogus,dc=com"
		// cn=LG-EJB-LE-USERS
		//
		// lookup user
		// /bin/ldapsearch -h enterprise-ldap -b
		// "ou=people,ou=corporate,dc=bogus,dc=com" uid=puck

		Boolean ret_ = false;

		Hashtable<String, Object> env = new Hashtable<String, Object>(11);

		env.put(Context.INITIAL_CONTEXT_FACTORY,
				"com.sun.jndi.ldap.LdapCtxFactory");

		env.put(Context.PROVIDER_URL, "ldap://enterprise-ldap:389/");

		// Use anonymous authentication
		env.put(Context.SECURITY_AUTHENTICATION, "none");

		try {
			_ctx = new InitialDirContext(env);
			ret_ = true;
		} catch (NamingException e) {
			e.printStackTrace();
		}

		return ret_;
	}

	public static String cleanStr(String s) {
		return s != null ? s.trim() : "";
	}

	public static void printUsers(String element, ArrayList<String> groupPeople)

	throws NamingException {
		String element_ = cleanStr(element);

		if (element_.isEmpty() == false && groupPeople != null)
			for (Integer i_ = 0; i_ < groupPeople.size(); i_++) {
				for (Attributes userAttrs_ : searchLDAP(
						_ldapSearchPeople,
						_ldapSearchPeopleKey.concat("=").concat(
								groupPeople.get(i_)))) {

					for (String s_ : _userAttrs) {
						Attribute attr_ = userAttrs_.get(s_);

						if (attr_ != null) {
							System.out.println("<" + element_ + "_" + s_ + i_
									+ ">" + attr_.get().toString() + "</"
									+ element_ + "_" + s_ + i_ + ">");
						}
					}
				}
			}
	}

	public static ArrayList<Attributes> searchLDAP(String name, String filter) {
		ArrayList<Attributes> ret_ = new ArrayList<Attributes>();
		String name_ = cleanStr(name);
		String filter_ = cleanStr(filter);

		if (name_.isEmpty() == false && filter_.isEmpty() == false) {
			SearchControls cntls_ = new SearchControls();

			cntls_.setSearchScope(SearchControls.SUBTREE_SCOPE);

			try {
				NamingEnumeration<SearchResult> results_ = _ctx.search(name_,
						filter_, cntls_);

				while (results_.hasMore()) {
					SearchResult searchResult = (SearchResult) results_.next();

					ret_.add(searchResult.getAttributes());
				}
			} catch (NamingException e) {
				e.printStackTrace();
			}
		}

		return ret_;
	}

	public static ArrayList<String> getAttributes(Attributes attributes,
			String attrID) throws NamingException {
		ArrayList<String> ret_ = new ArrayList<String>();
		String attrID_ = cleanStr(attrID);

		if (attributes != null && attrID_.isEmpty() == false) {
			Attribute a_ = attributes.get(attrID_);

			for (int i_ = 0; a_ != null && i_ < a_.size(); i_++) {
				String s_ = a_.get(i_).toString();

				if (s_ != null && s_.isEmpty() == false)
					ret_.add(s_);
			}
		}

		return ret_;
	}

	public static String wrapBegElem(String s) {
		return "<" + cleanStr(s) + ">";
	}

	public static String wrapEndElem(String s) {
		return "</" + cleanStr(s) + ">";
	}

	public static void main(String[] xxargs) {
		try {
			if (xxargs != null && xxargs.length > 0 && initCtx()) {
				ArrayList<String> args_ = new ArrayList<String>();
				Integer groupCnt_ = 0;

				args_.addAll(Arrays.asList(xxargs));

				Collections.sort(args_);

				System.out.println(wrapBegElem(_ldapData));

				for (int i_ = 0; i_ < args_.size(); i_++) {
					String group_ = "";

					for (Attributes groupAttrs_ : searchLDAP(
							_ldapSearchGroup,
							_ldapSearchGroupKey.concat("=").concat(
									args_.get(i_)))) {

						String groupElem_ = _groupElem.concat(groupCnt_
								.toString());

						String groupCnElem_ = groupElem_.concat("_").concat(
								_ldapSearchGroupKey);

						if (!group_.equals(args_.get(i_))) {
							group_ = args_.get(i_);

							System.out.println(wrapBegElem(groupElem_ + " "
									+ _ldapSearchGroupKey + "='"
									+ args_.get(i_) + "'"));

							System.out.println(wrapBegElem(groupCnElem_)
									+ group_ + wrapEndElem(groupCnElem_));
						}

						ArrayList<String> groupPeople_ = new ArrayList<String>();

						for (String attrId_ : _groupAttrs) {
							for (String s_ : getAttributes(groupAttrs_, attrId_)) {
								String elem_ = groupElem_.concat("_" + attrId_);

								if (attrId_.equals(_fmPrimaryOwner)) {
									Matcher matcher_ = _uidPat.matcher(s_);
									String uid_ = "";

									if (matcher_.find()) {
										uid_ = matcher_.group(1);

										groupPeople_.add(uid_);

										System.out.println(wrapBegElem(elem_)
												+ uid_ + wrapEndElem(elem_));

									}
								} else if (attrId_.equals(_uniqMember)) {
									Matcher matcher_ = _uidPat.matcher(s_);

									if (matcher_.find()) {
										groupPeople_.add(matcher_.group(1));
									}
								} else if (attrId_.equals(_memberUid)) {
									groupPeople_.add(s_);
								} else {
									System.out.println(wrapBegElem(elem_) + s_
											+ wrapEndElem(elem_));
								}
							}
						}

						Collections.sort(groupPeople_);

						printUsers(groupElem_.concat("_member"), groupPeople_);

						System.out.println(wrapEndElem(groupElem_));

						groupCnt_++;
					}
				}

				System.out.println("<people_group>");

				printUsers("people_member", args_);

				System.out.println("</people_group>");

				System.out.println(wrapEndElem(_ldapData));

				_ctx.close();
			}

		} catch (NamingException e) {
			e.printStackTrace();
		}
	}
}
