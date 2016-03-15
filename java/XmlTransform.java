import java.io.FileInputStream;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;

//
// Uses jars org.apache.xalan org.apache.xml.serializer
//
public class XmlTransform {

	public static void main(String[] args) {

		if (args.length < 2) {
			System.err.println("XSLFilePath (XMLFilePath|-)");
			System.err.println("\tXMLFilePath|- : path to XML file or - to read from stdin");
			System.exit(1);
		}
		
		// Set the property to use xalan processor
		System.setProperty("javax.xml.transform.TransformerFactory",
				"org.apache.xalan.processor.TransformerFactoryImpl");

		// try with resources
		try {
			FileInputStream xsl = new FileInputStream(args[0]);
			StreamResult result = new StreamResult(System.out);
			StreamSource xmlSource = null;

			if (args[1].equals("-")) {
				xmlSource = new StreamSource(System.in);
			}
			else {
				xmlSource = new StreamSource(new FileInputStream(args[1]));
			}

			// Instantiate a transformer factory
			TransformerFactory tFactory = TransformerFactory.newInstance();

			// Use the TransformerFactory to process the stylesheet source and
			// produce a Transformer
			StreamSource styleSource = new StreamSource(xsl);
			Transformer transformer = tFactory.newTransformer(styleSource);

			// Use the transformer and perform the transformation
			transformer.transform(xmlSource, result);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
