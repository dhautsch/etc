package com.hautsch;

import java.io.File;
import java.io.FileInputStream;
import java.util.Enumeration;
import java.util.Properties;

public class PropertyConvert {

	public static void main(String[] args) {
		if (args.length == 2)
			try {
				File src_ = new File(args[0]);

				if (src_.exists()) {
					Properties props_ = new Properties();
					FileInputStream is_ = new FileInputStream(src_);

					props_.load(is_);

					if (args[1].toLowerCase().equals("toperl")) {
						int cnt_ = 0;

						Enumeration<?> e = props_.propertyNames();
						while (e.hasMoreElements()) {
							String key = (String) e.nextElement();
							String value = props_.getProperty(key);

							if (cnt_ < 1)
								System.out.println("$VAR1 = {");
							else
								System.out.print(",");

							key = key.replace("'", "\\'");
							value = value.replace("'", "\\'");

							System.out.println("'" + key + "' => '" + value
									+ "'");
							cnt_++;
						}

						if (cnt_ > 0)
							System.out.println("};");
					} else if (args[1].toLowerCase().equals("toxml")) {
						props_.storeToXML(System.out, null);
					}
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
	}

}
