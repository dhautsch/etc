//
// This program reads emails Microsoft Exchange Server (O365)
// It can download the attachments from mailbox by setting below
// parameters for who sent,what attachment,where to download
// HTTP_PROXY           - proxy to use if defined
// FROM_ADDRESS         - sender email address 
// ATTACHMENT_REGEX     - attachment name, you can set to whatever
//                        "string" you want to look for, can give multiple
//                        strings with PIPE(|) delimited
// DOWNLOAD_DIR         - download directory
// NUMBER_EMAILS_FETCH  - number of emails to scan  [default:500]
// EXCHG_USER           - your email address
// EXCHG_PASSWORD       - your AD password
//
// Need following jars
// httpcore-4.4.jar HttpComponents Apache HttpCore
// httpclient-4.4.jar HttpComponents Apache HttpClient
// commons-codec-1.9.jar org.apache.commons.codec
// commons-lang3-3.1.jar org.apache.commons.lang3
// commons-logging-1.2.jar org.apache.commons.logging
// joda-time-2.8.jar org.joda.time
// ews-java-api-2.0.jar com.microsoft.ews-java-api


import java.net.URI;
import org.apache.commons.lang3.StringUtils;
import java.util.*;
import java.io.*;
import java.lang.Integer.*;
import java.util.regex.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;

import com.fasterxml.jackson.databind.ObjectMapper;

import microsoft.exchange.webservices.data.*;
import microsoft.exchange.webservices.data.search.*;
import microsoft.exchange.webservices.data.credential.*;
import microsoft.exchange.webservices.data.core.*;
import microsoft.exchange.webservices.data.property.complex.*;
import microsoft.exchange.webservices.data.core.service.folder.*;
import microsoft.exchange.webservices.data.core.service.item.*;
import microsoft.exchange.webservices.data.core.enumeration.misc.*;
import microsoft.exchange.webservices.data.core.enumeration.property.*;

public class Driver {

	private static ExchangeService _service;
	private Integer NUMBER_EMAILS_FETCH = 500;
	private static String o365URI = "https://outlook.office365.com/EWS/Exchange.asmx";
	private static String PSWD = System.getenv("EXCHG_PASSWORD");
	private static String USER = System.getenv("EXCHG_USER");
	private static String DOWNLOAD_DIR = System.getenv("DOWNLOAD_DIR");
	private static String FROM_ADDRESS = System.getenv("FROM_ADDRESS");
	private static String ATTACHMENT_REGEX = System.getenv("ATTACHMENT_REGEX");
	private static Boolean INCLUDE_BODY = false;
	public Pattern _attachmentRegex;
	private static DateFormat _dfUTC = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");

	static {
		try {
	        _dfUTC.setTimeZone(TimeZone.getTimeZone("UTC"));
	        _service = new ExchangeService();
			_service.setUrl(new URI(o365URI));
			if (StringUtils.isNotBlank(System.getenv("HTTP_PROXY"))) {
				_service.setWebProxy(new WebProxy(System.getenv("HTTP_PROXY")));
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public Driver() {
		ExchangeCredentials credentials = new WebCredentials(USER, PSWD);
		_service.setCredentials(credentials);

		INCLUDE_BODY = StringUtils.isNotBlank(System.getenv("INCLUDE_BODY"));

		if (StringUtils.isNotBlank(System.getenv("NUMBER_EMAILS_FETCH")))
			NUMBER_EMAILS_FETCH = Integer.parseInt(System.getenv("NUMBER_EMAILS_FETCH").toString());
		if (StringUtils.isNotBlank(System.getenv("ATTACHMENT_REGEX"))) {
			ATTACHMENT_REGEX = System.getenv("ATTACHMENT_REGEX").toString();
			_attachmentRegex = Pattern.compile(ATTACHMENT_REGEX);
		}
		if (StringUtils.isNotBlank(System.getenv("FROM_ADDRESS")))
			FROM_ADDRESS = System.getenv("FROM_ADDRESS").toString();
	}

	public Map<String, String> readEmailItem(ItemId itemId) {
		Map<String, String> ret_;
		List<String> ls_ = new ArrayList<String>();
		Map<String, String> msg_ = new HashMap<String, String>();
		Boolean downloadMode_ = StringUtils.isNotBlank(DOWNLOAD_DIR) && StringUtils.isNotBlank(ATTACHMENT_REGEX)
				&& StringUtils.isNotBlank(FROM_ADDRESS);
		
		try {
			Item item_ = Item.bind(_service, itemId, PropertySet.FirstClassProperties);
			EmailMessage em_ = EmailMessage.bind(_service, item_.getId());
			msg_.put("emailItemId", em_.getId().toString());
			msg_.put("subject", em_.getSubject().toString());
			msg_.put("fromAddress", em_.getFrom().getAddress().toString());
			msg_.put("senderName", em_.getSender().getName().toString());
			Date dateTimeCreated = em_.getDateTimeCreated();
			msg_.put("SendDate", _dfUTC.format(dateTimeCreated));
			Date dateTimeRecieved = em_.getDateTimeReceived();
			msg_.put("RecievedDate", _dfUTC.format(dateTimeRecieved));
			msg_.put("Size", em_.getSize() + "");
			msg_.put("emailHeader", String.join("\n", ls_));
			msg_.put("attachmentCount", "0");

			for (InternetMessageHeader imh_ : em_.getInternetMessageHeaders().getItems()) {
				ls_.add(imh_.getValue());
			}

			if (INCLUDE_BODY)
				msg_.put("emailBody", em_.getBody().toString());

			if (em_.getHasAttachments() && em_.getAttachments().getItems().size() > 0) {
				AttachmentCollection attachmentsCol_ = em_.getAttachments();
				msg_.put("attachmentCount", "" + em_.getAttachments().getItems().size());
				
				ls_ = new ArrayList<String>();
				
				for (int i = 0; i < attachmentsCol_.getCount(); i++) {
					ls_.add(attachmentsCol_.getPropertyAtIndex(i).getName());
				}
				msg_.put("attachmentNames", String.join(";", ls_));
				
				if (downloadMode_) {
					if (msg_.get("fromAddress").equals(FROM_ADDRESS)) {
						attachmentsCol_ = em_.getAttachments();

						ls_ = new ArrayList<String>();

						for (int i = 0; i < attachmentsCol_.getCount(); i++) {
							Attachment attachment_ = attachmentsCol_.getPropertyAtIndex(i);
							Matcher matcher_ = _attachmentRegex.matcher(attachment_.getName());
							if (attachment_ instanceof FileAttachment && matcher_.find()) {
								String pSep_ = System.getProperty("path.separator");
								FileAttachment fa_ = (FileAttachment) attachment_;
								File f_ = new File(DOWNLOAD_DIR + pSep_ + fa_.getName());
								if (f_.exists()) {
									ls_.add("Attachment [" + DOWNLOAD_DIR + pSep_ + fa_.getName()
									+ "] downloaded already !!!");
								} else {
									ls_.add("Saving the attachment [" + fa_.getName() + "]");
									fa_.load(DOWNLOAD_DIR + pSep_ + fa_.getName());
								}
							}
						}

						if (ls_.isEmpty() == false) {
							msg_.put("downloadMsg", String.join("\n", ls_));
							ret_ = msg_;
						}
					}
				}
				else {
					ret_ = msg_;
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
		return msg_;
	}

	private void validateParams(String args[]) {
		if (args.length != 0 || StringUtils.isBlank(USER) || StringUtils.isBlank(PSWD)) {
			System.err.println("Usage:\n\tjava ExchangeEmail");
			System.err.println("\nset env EXCHG_USER to email_address of the account you want to read emails.");
			System.err.println("set  env EXCHG_PASSWORD with the password of the account you want to read.");
			System.err.println("set  env NUMBER_EMAILS_FETCH to read first n emails [default:500].");
			System.err.println("set  env FROM_ADDRESS to sender email address [default:key@yoyodyne.com].");
			System.err.println("set  env ATTACHMENT_REGEX to keywords of attachment files,delimited by '|' for multiple.");
			System.err.println("set  env DOWNLOAD_DIR if you want to download attachments[default:/tmp].");
			System.err.println("set  env HTTP_PROXY if exchange server is external.");
			System.err.println("set  env INCLUDE_BODY to include email body.");
			System.exit(1);
		}
	}

	public static void main(String[] args) {
		DateFormat df_ = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		Map<String, Object> o_ = new HashMap<String, Object>();
		List<Map<String, String>> l_ = new ArrayList<Map<String, String>>();

		o_.put("startTime", _dfUTC.format(new Date()));
		System.err.println("Starting " + o_.get("startTime"));

		Driver ee_ = new Driver();

		ee_.validateParams(args);

		
		try {
			Folder folder_ = Folder.bind(_service, WellKnownFolderName.Inbox);
			FindItemsResults<Item> results_ = _service.findItems(folder_.getId(), new ItemView(ee_.NUMBER_EMAILS_FETCH));
			o_.put("inboxCount", "" + results_.getTotalCount());
			
			System.err.println("Inbox msgCount is " + o_.get("inboxCount"));

			int i_ = 1;
			for (Item item_ : results_) {
				Map<String, String> msg_ = ee_.readEmailItem(item_.getId());
				if (i_++ % 25 != 0)
					System.err.print(".");
				else
					System.err.println("");

				if (msg_ != null) {
					l_.add(msg_);
				}
			}
			
			o_.put("messages", l_);
			o_.put("endTime", _dfUTC.format(new Date()));
			System.err.println("\nFinished " + o_.get("startTime"));

			ObjectMapper mapper_ = new ObjectMapper();
			System.out.println(mapper_.writerWithDefaultPrettyPrinter().writeValueAsString(o_));
		} catch (Exception e) {
			e.printStackTrace();
		}

	}
}
