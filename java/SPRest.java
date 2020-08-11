import java.io.InputStream;
import java.io.OutputStream;
import java.io.StringWriter;
import java.net.Authenticator;
import java.net.HttpURLConnection;
import java.net.PasswordAuthentication;
import java.net.URL;
import java.net.URLConnection;
import java.util.HashMap;
import java.util.ArrayList;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.w3c.dom.Node;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

public class SPRest {
	static class MyAuthenticator extends Authenticator {
		public PasswordAuthentication getPasswordAuthentication() {
			// I haven't checked getRequestingScheme() here, since for NTLM
			// and Negotiate, the usrname and password are all the same.
			// System.err.println("Feeding username and password for " +
			// getRequestingScheme());
			String user_ = "DOMAIN\\uid";
			String pass_ = "PASSWORD";
			
			return (new PasswordAuthentication(user_, pass_.toCharArray()));
		}
	}

	public static void main(String[] args) throws Exception {
		Authenticator.setDefault(new MyAuthenticator());
		String metaDataUrl_ = "https://yoyodyne.sharepoint.com/sites/etl/_api/lists/getbytitle('Tasks')";
		String itemsUrl_ = metaDataUrl_ + "/items";
		Document doc_;
		ArrayList<HashMap<String, String>> al_;
		
		// Get List Meta Data
		doc_ = get(metaDataUrl_);
		al_ = getItems(doc_);

		for (int i_ = 0; i_ < al_.size(); i_++) {
			for (String k_ : al_.get(i_).keySet()) {
				System.out.println("MetaData[" + i_ + "]." + k_ + "='"
						+ al_.get(i_).get(k_) + "'");
			}
		}
		
		// Get List Items
		doc_ = get(itemsUrl_);
		al_ = getItems(doc_);

		for (int i_ = 0; i_ < al_.size(); i_++) {
			for (String k_ : al_.get(i_).keySet()) {
				System.out.println("Item[" + i_ + "]." + k_ + "='"
						+ al_.get(i_).get(k_) + "'");
			}
		}

		String data_ = "{ "
						+ " '_metadata': { 'type': 'SP.Data.TasksListItem' }"
						+ ", 'Title': 'Added by rest api'"
						+ ", 'Priority': '(2) Normal'"
						+ ", 'Status': 'Not Started'"
						+ ", 'AssignedToId': '3093'"
						+ ", 'StartDate':'2014-01-29T08:00:00Z', 'DueDate':'2014-01-31T08:00:00Z',"
						+ " }";

		doc_ = post(itemsUrl_, data_);
		
		System.out.println(prettyPrintXml(doc_));
	}

	public static ArrayList<HashMap<String, String>> getItems(Document doc) {
		ArrayList<HashMap<String, String>> al_ = new ArrayList<HashMap<String, String>>();

		if (doc != null) {
			Element root = doc.getDocumentElement();
			NodeList nl_ = root.getElementsByTagName("m:properties");

			int cnt_ = nl_.getLength();

			for (int i_ = 0; i_ < cnt_; i_++) {
				Node n_ = nl_.item(i_);
				NodeList itemProps_ = n_.getChildNodes();
				int itemPropCnt_ = itemProps_.getLength();
				HashMap<String, String> h_ = new HashMap<String, String>();

				for (int j_ = 0; j_ < itemPropCnt_; j_++) {
					String k_ = itemProps_.item(j_).getNodeName();
					String v_ = itemProps_.item(j_).getTextContent();

					h_.put(k_, v_);
				}
				al_.add(h_);
			}
		}
		return al_;
	}

	public static Document get(String url) {
		Document doc_ = null;
		try {
			URL url_ = new URL(url);
			URLConnection conn_ = url_.openConnection();

			conn_.setRequestProperty("Accept",
					"application/atom+xml;charset=UTF-8");

			InputStream is_ = conn_.getInputStream();

			if (is_ != null)
				doc_ = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(is_);

		} catch (Exception e) {
			e.printStackTrace();
		}
		return doc_;
	}

	public static Document post(String url, String data) {
		Document doc_ = null;

		try {
			URL url_ = new URL(url);
			HttpURLConnection conn_ = (HttpURLConnection) url_.openConnection();
			conn_.setDoOutput(true);
			conn_.setRequestMethod("POST");
			conn_.setRequestProperty("Content-Type", "application/json;odata=verbose");
			conn_.setRequestProperty("Content-Length", String.valueOf(data.length()));
			conn_.setRequestProperty("Accept", "application/atom+xml;charset=UTF-8");

			OutputStream os_ = conn_.getOutputStream();
			os_.write(data.getBytes());
			os_.flush();

			if (false && conn_.getResponseCode() != HttpURLConnection.HTTP_CREATED) {
				throw new RuntimeException("Failed : HTTP error code : "
						+ conn_.getResponseCode());
			}

			InputStream is_ = conn_.getInputStream();
			doc_ = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(is_);

			conn_.disconnect();

		} catch (Exception e) {
			e.printStackTrace();
		}

		return doc_;
	}

	public static String prettyPrintXml(Document doc) {
		String ret_ = "";

		if (doc != null)
			try {
				TransformerFactory tf = TransformerFactory.newInstance();

				tf.setAttribute("indent-number", 2);
				Transformer transformer = tf.newTransformer();
				StringWriter w_ = new StringWriter();

				transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION,
						"no");
				transformer.setOutputProperty(OutputKeys.METHOD, "xml");
				transformer.setOutputProperty(OutputKeys.INDENT, "yes");
				transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
				/*
				 * transformer.setOutputProperty(
				 * "{http://xml.apache.org/xslt}indent-amount", "4");
				 */
				// new OutputStreamWriter(out, "UTF-8")));
				transformer.transform(new DOMSource(doc), new StreamResult(w_));
				System.out.print(w_.getBuffer().toString());
				ret_ = w_.getBuffer().toString();
			} catch (Exception e) {
				e.printStackTrace();
			}
		return ret_;
	}
}
