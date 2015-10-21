package com.hautsch;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.StringWriter;

import java.util.ArrayList;
import java.util.HashMap;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpression;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;

import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.w3c.dom.ls.DOMImplementationLS;
import org.w3c.dom.ls.LSSerializer;

public class XmlPath {
	private Document _xmlDocument = null;
	private final static String _lineSeparatorProp = "line.separator";

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		XmlPath xmlPath_ = null;
		boolean printUsage_ = false;

		if (args.length == 3) {
			String action_ = args[0].toLowerCase();
			boolean getXml_ = action_.equals("getxml");

			if (getXml_ || action_.equals("getvalue")) {
				String out_ = "";
				ArrayList<Node> al_ = null;

				xmlPath_ = new XmlPath();

				if (args[1].equals("-"))
					xmlPath_.setXmlDocument(System.in);
				else
					xmlPath_.setXmlDocument(new File(args[1]));

				al_ = xmlPath_.xpathToNodeList(args[2]);

				for (int i_ = 0; i_ < al_.size(); i_++)
					if (getXml_) {
						if (out_.isEmpty())
							out_ = "<DATA>";

						out_ = out_.concat(nodeToXML(al_.get(i_)));
					} else {
						String tag_ = nodeToTag(al_.get(i_));
						HashMap<String, String> attrMap_ = nodeToAttributes(al_
								.get(i_));

						if (al_.size() > 1)
							tag_ = tag_.concat("[" + i_ + "]");

						out_ = out_.concat(tag_ + "="
								+ nodeToValue(al_.get(i_))
								+ System.getProperty(_lineSeparatorProp));

						for (String k_ : attrMap_.keySet())
							out_ = out_
									.concat(tag_ + "." + k_ + "="
											+ attrMap_.get(k_)
											+ System.getProperty(_lineSeparatorProp));
					}

				if (isNotBlank(out_)) {
					if (getXml_)
						out_ = prettyPrintXml(out_.concat("</DATA>")
								+ System.getProperty(_lineSeparatorProp));

					System.out.print(out_);
				}
			}
		} else {
			printUsage_ = true;
		}

		if (printUsage_)
			System.err.println("(getXML|getValue) filePath XPath");

	}

	public static boolean isNotBlank(String s) {
		return s != null && s.trim().isEmpty() == false;
	}

	public static String nodeToXML(Node n) {
		String ret_ = "";

		if (n != null) {
			DOMImplementationLS lsImpl = (DOMImplementationLS) n
					.getOwnerDocument().getImplementation()
					.getFeature("LS", "3.0");
			LSSerializer serializer = lsImpl.createLSSerializer();

			serializer.getDomConfig().setParameter("xml-declaration", false);

			ret_ = serializer.writeToString(n);
		}
		return ret_;
	}

	public static String nodeToTag(Node n) {
		String ret_ = "";

		if (n != null)
			ret_ = n.getNodeName();

		return ret_;
	}

	public static String nodeToValue(Node n) {
		String ret_ = "";

		if (n != null)
			ret_ = n.getTextContent().trim();

		return ret_;
	}

	public static HashMap<String, String> nodeToAttributes(Node n) {
		HashMap<String, String> ret_ = new HashMap<String, String>();

		if (n != null) {
			NamedNodeMap nnm_ = n.getAttributes();

			if (nnm_ != null) {
				ret_ = new HashMap<String, String>();

				for (int j_ = 0; j_ < nnm_.getLength(); j_++) {
					Attr attr_ = (Attr) nnm_.item(j_);
					ret_.put(attr_.getNodeName(), attr_.getNodeValue());
				}
			}
		}
		return ret_;
	}

	public static ArrayList<Node> xpathToNodeList(Document doc, String xpath) {
		ArrayList<Node> ret_ = new ArrayList<Node>();

		if (doc != null && isNotBlank(xpath))
			try {
				XPath xPath_ = XPathFactory.newInstance().newXPath();
				XPathExpression xPathExpr_;

				xPathExpr_ = xPath_.compile(xpath);
				NodeList nl_ = (NodeList) xPathExpr_.evaluate(doc,
						XPathConstants.NODESET);
				for (int i_ = 0; i_ < nl_.getLength(); i_++)
					ret_.add(nl_.item(i_));

			} catch (XPathExpressionException e) {
				e.printStackTrace();
			}

		return ret_;
	}

	public ArrayList<Node> xpathToNodeList(String xpath) {
		return xpathToNodeList(getXmlDocument(), xpath);
	}

	public String xpathFirstNodeValue(String xpath) {
		String ret_ = "";
		ArrayList<Node> al_ = xpathToNodeList(getXmlDocument(), xpath);

		if (al_.isEmpty() == false) {
			ret_ = nodeToValue(al_.get(0));
			if (isNotBlank(ret_) == false)
				ret_ = "";
		}
		return ret_;
	}

	public Document getXmlDocument() {
		return _xmlDocument;
	}

	public void setXmlDocument(InputStream is) {
		if (is != null)
			_xmlDocument = documentFromStream(is);
		else
			setXmlDocument("");
	}

	public void setXmlDocument(File file) {
		_xmlDocument = null;
		if (file != null)
			try {
				setXmlDocument(new FileInputStream(file));
			} catch (Exception e) {
				e.printStackTrace();
			}
		else {
			setXmlDocument("");
		}
	}

	public void setXmlDocument(String xml) {
		_xmlDocument = null;

		if (xml != null)
			try {
				setXmlDocument(new ByteArrayInputStream(xml.getBytes("UTF-8")));
			} catch (Exception e) {
				e.printStackTrace();
			}
		else {
			setXmlDocument("");
		}
	}

	public static Document documentFromStream(InputStream is) {
		Document ret_ = null;

		if (is != null)
			try {
				ret_ = DocumentBuilderFactory.newInstance()
						.newDocumentBuilder().parse(is);
			} catch (Exception e) {
				e.printStackTrace();
			}
		return ret_;
	}

	public static String prettyPrintXml(String xml) {
		String ret_ = "";

		if (xml != null)
			try {
				ByteArrayInputStream bais_ = new ByteArrayInputStream(
						xml.getBytes("UTF-8"));

				ret_ = prettyPrintXml(documentFromStream(bais_));
			} catch (Exception e) {
				e.printStackTrace();
			}

		return ret_;
	}

	public static boolean prettyPrintXml(Document doc, StreamResult sr) {
		boolean ret_ = false;
		if (doc != null && sr != null)
			try {
				TransformerFactory tf = TransformerFactory.newInstance();
				
				tf.setAttribute("indent-number", 2);
				
				Transformer transformer = tf.newTransformer();

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
				transformer.transform(new DOMSource(doc), sr);
				ret_ = true;
			} catch (Exception e) {
				e.printStackTrace();
			}
		return ret_;
	}

	public static String prettyPrintXml(Document doc) {
		String ret_ = "";

		if (doc != null) {
			StringWriter w_ = new StringWriter();

			if (prettyPrintXml(doc, new StreamResult(w_)))
				ret_ = w_.getBuffer().toString();
		}
		return ret_;
	}

}
