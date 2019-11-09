import java.net.URI;
import org.apache.commons.lang3.StringUtils;
import java.util.*;
import java.io.*;
import java.lang.Integer.*;
import java.util.regex.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;

import com.fasterxml.jackson.core.JsonProcessingException;
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

public class MSMailDriver {
	private ExchangeService _service = null;
	private Folder _folder = null;

	private Integer NUMBER_EMAILS_FETCH = 500;
	private static String o365URI = "https://outlook.office365.com/EWS/Exchange.asmx";
	private static String CONN = System.getenv("EXCHG_CONN");
	private static String DOWNLOAD_DIR = System.getenv("DOWNLOAD_DIR");
	private static String FROM_ADDRESS = System.getenv("FROM_ADDRESS");
	private static String ATTACHMENT_REGEX = System.getenv("ATTACHMENT_REGEX");
	private static Boolean INCLUDE_BODY = false;
	public Pattern _attachmentRegex;
	private static DateFormat _dfUTC = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
	private static DateFormat _dfLOCAL = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

	static {
		_dfUTC.setTimeZone(TimeZone.getTimeZone("UTC"));
	}

	public MSMailDriver(String args[]) {
		if (args.length != 0 || StringUtils.isBlank(CONN)) {
			System.err.println("Usage: java MSMailDriver");
			System.err.println("This program reads emails Microsoft Exchange Server (O365)");
			System.err.println("ENV EXCHG_CONN to USER/PASS@yoyodyne.com of the account you want to read emails.");
			System.err.println("ENV NUMBER_EMAILS_FETCH to read first n emails [default:500].");
			System.err.println("ENV FROM_ADDRESS to filter sender email address [default:key@yoyodyne.com].");
			System.err.println("ENV ATTACHMENT_REGEX to keywords of attachment files,delimited by '|' for multiple.");
			System.err.println("ENV DOWNLOAD_DIR if you want to download attachments[default:/tmp].");
			System.err.println("ENV PROXY_URL if exchange server is external.");
			System.err.println("ENV INCLUDE_BODY to include email body.");
		}
		else {
			Matcher m_ = Pattern.compile("^([^/]+)/([^@]+)@(.*)").matcher(CONN);
	
			if (m_.find()) {
				try {
					ExchangeService o_ = new ExchangeService();
					o_.setUrl(new URI(o365URI));
					if (StringUtils.isNotBlank(System.getenv("PROXY_URL"))) {
						o_.setWebProxy(new WebProxy(System.getenv("PROXY_URL")));
					}
	
					ExchangeCredentials credentials_ = new WebCredentials(m_.group(1) + "@" + m_.group(3), m_.group(2));
	
					o_.setCredentials(credentials_);
	
					INCLUDE_BODY = StringUtils.isNotBlank(System.getenv("INCLUDE_BODY"));
	
					if (StringUtils.isNotBlank(System.getenv("NUMBER_EMAILS_FETCH")))
						NUMBER_EMAILS_FETCH = Integer.parseInt(System.getenv("NUMBER_EMAILS_FETCH").toString());
					if (StringUtils.isNotBlank(System.getenv("ATTACHMENT_REGEX"))) {
						ATTACHMENT_REGEX = System.getenv("ATTACHMENT_REGEX").toString();
						_attachmentRegex = Pattern.compile(ATTACHMENT_REGEX);
					}
					if (StringUtils.isNotBlank(System.getenv("FROM_ADDRESS")))
						FROM_ADDRESS = System.getenv("FROM_ADDRESS").toString();
	
					_service = o_;
				} catch (Exception e) {
					e.printStackTrace();
				}
			} else {
				System.err.println("ENV EXCHG_CONN FORMAT NOT USER/PASS@DOMAIN");
			}
		}
	}

	public Map<String, Object> readEmailItem(ItemId itemId) throws Exception {
		Map<String, Object> ret_ = new HashMap<String, Object>();

		if (itemId != null) {
			List<String> ls_ = new ArrayList<String>();
			Boolean downloadMode_ = StringUtils.isNotBlank(DOWNLOAD_DIR) && StringUtils.isNotBlank(ATTACHMENT_REGEX)
					&& StringUtils.isNotBlank(FROM_ADDRESS);
			Item item_ = Item.bind(_service, itemId, PropertySet.FirstClassProperties);
			EmailMessage em_ = EmailMessage.bind(_service, item_.getId());

			ret_.put("emailItemId", em_.getId().toString());
			ret_.put("to", em_.getToRecipients());
			ret_.put("cc", em_.getCcRecipients());
			ret_.put("subject", em_.getSubject().toString());
			ret_.put("fromAddress", em_.getFrom().getAddress().toString());
			ret_.put("senderName", em_.getSender().getName().toString());
			ret_.put("createDate", _dfUTC.format(em_.getDateTimeCreated()));
			ret_.put("receivedDate", _dfUTC.format(em_.getDateTimeReceived()));
			ret_.put("sentDate", _dfUTC.format(em_.getDateTimeSent()));
			ret_.put("size", em_.getSize() + "");
			ret_.put("emailHeader", StringUtils.join(ls_, "\n"));
			ret_.put("attachmentCount", "0");

			for (InternetMessageHeader imh_ : em_.getInternetMessageHeaders().getItems()) {
				ls_.add(imh_.getValue());
			}

			if (INCLUDE_BODY)
				ret_.put("emailBody", em_.getBody().toString());

			if (em_.getHasAttachments() && em_.getAttachments().getItems().size() > 0) {
				AttachmentCollection attachmentsCol_ = em_.getAttachments();
				ret_.put("attachmentCount", "" + em_.getAttachments().getItems().size());

				ls_ = new ArrayList<String>();

				for (int i = 0; i < attachmentsCol_.getCount(); i++) {
					ls_.add(attachmentsCol_.getPropertyAtIndex(i).getName());
				}
				ret_.put("attachmentNames", StringUtils.join(ls_, ";"));

				if (downloadMode_) {
					if (ret_.get("fromAddress").equals(FROM_ADDRESS)) {
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
							ret_.put("downloadMsg", StringUtils.join(ls_, "\n"));
						}
					}
				}
			}
		}
		return ret_;
	}

	public ExchangeService getService() {
		return _service;
	}

	public Folder getFolder() {
		return _folder;
	}

	public void setFolder(WellKnownFolderName name) throws Exception {
		if (_service != null) {
			_folder = Folder.bind(_service, name);
		}
	}

	public FindItemsResults<Item> getItems(ItemView itemView) throws Exception {
		FindItemsResults<Item> ret_ = null;

		if (_folder != null) {
			ret_ = _service.findItems(_folder.getId(), itemView);
		}

		return ret_;
	}

	public static void main(String[] args) {
		int exit_ = 1;
		
		try {
			Map<String, Object> o_ = new HashMap<String, Object>();

			o_.put("startTime", _dfUTC.format(new Date()));

			MSMailDriver ee_ = new MSMailDriver(args);

			if (ee_.getService() != null) {
				WellKnownFolderName folderName_ = WellKnownFolderName.Inbox;

				ee_.setFolder(folderName_);
				FindItemsResults<Item> items_ = ee_.getItems(new ItemView(ee_.NUMBER_EMAILS_FETCH));

				if (items_ != null) {
					int i_ = 1;
					List<Map<String, Object>> l_ = new ArrayList<Map<String, Object>>();

					o_.put("folder", folderName_.toString());
					o_.put("itemCount", "" + items_.getTotalCount());
					o_.put("messages", l_);

					for (Item item_ : items_) {
						Map<String, Object> msg_ = ee_.readEmailItem(item_.getId());

						if (false) {
							if (i_++ % 25 != 0)
								System.err.print(".");
							else
								System.err.println("");
						}

						if (msg_ != null) {
							l_.add(msg_);
						}
					}

					o_.put("endTime", _dfUTC.format(new Date()));

					System.out.println(new ObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsString(o_));

					exit_ = 0;
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		}

		System.exit(exit_);
	}
}
