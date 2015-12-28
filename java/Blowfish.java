package com.hautsch;

import java.io.Console;
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

public class Blowfish {

	/**
	 * Returns argv[0] decrypted string. The string has to be encrypted using -Dencrypt=t
	 * with the key in final static char [] SHORT_KEY or use the runnable BlowfishApp.jar
	 * JavaFX application to encrypt the string.
	 * If the decrypted string is in one of the following forms:
	 *                            string:uid
	 *                            string:uid0,uid1,...
	 * then the "string" part is returned only if the user.name system property is in uid, uid0, uid1.
	 * @author don@hautsch.com
	 *
	 */

	final static String USER_NAME_PROP_ENCRYPTED = "9CB2C03E317C71F114022CA6BAD43AB3"; // "user.name" encrypted
	final static String OPTION_PROP_ENCRYPTED = "9C590C9ED0EAC0D5"; // "encrypt"
	final static String HEX_STRING = "0123456789ABCDEF";
	final static char[] SHORT_KEY = { '{', '3', '3', '4', '6', 'A', '5', '3',
		'3', '-', '7', '4', '2', '3', '-', '4' };

	public static void main(String[] args) {
		String minusDencryptedIsSet_ = System.getProperty(decrypt(OPTION_PROP_ENCRYPTED));

		if (minusDencryptedIsSet_ != null) {
			Console console_ = System.console();

			if (console_ != null) {
				String s_ = console_.readLine("String to encrypt: ");

				if (s_ != null && s_.isEmpty() == false) {
					System.out.println("String entered : '" + s_ + "'");
					System.out.println("String encrypted: '" + encrypt(s_) + "'");
				}
			}
		} else if (args != null && args.length == 1
				&& args[0].isEmpty() == false) {
			String s_ = decrypt(args[0]);

			if (s_ != null && s_.isEmpty() == false) {
				String[] ret_ = s_.split("[:,]");

				if (ret_.length == 1) {
					System.out.println(ret_[0]);
				} else if (ret_.length > 1) {
					String userName_ = System.getProperty(decrypt(USER_NAME_PROP_ENCRYPTED));

					for (int i_ = 1; i_ < ret_.length; i_++) {
						if (ret_[i_].equals(userName_)) {
							System.out.println(ret_[0]);
							break;
						}
					}
				}
			}
		}

		System.exit(0);
	}

	public static String decrypt(String s) {
		try {
			String key_ = new String(SHORT_KEY);
			SecretKeySpec keySpec_ = new SecretKeySpec(key_.getBytes(), "Blowfish");
			Cipher cipher_ = Cipher.getInstance("Blowfish");

			cipher_.init(Cipher.DECRYPT_MODE, keySpec_);

			byte[] decrypted = cipher_.doFinal(convertHexadecimal2Binary(s.getBytes()));

			return new String(decrypted);
		} catch (Exception e) {
			return null;
		}
	}

	public static String encrypt(String s) {
		try {
			String key_ = new String(SHORT_KEY);
			SecretKeySpec keySpec_ = new SecretKeySpec(key_.getBytes(),"Blowfish");
			Cipher cipher_ = Cipher.getInstance("Blowfish");

			cipher_.init(Cipher.ENCRYPT_MODE, keySpec_);

			return new String(convertBinary2Hexadecimal(cipher_.doFinal(s.getBytes())));

		} catch (Exception e) {
			return null;
		}
	}


	public static byte[] convertHexadecimal2Binary(byte[] hex) {
		int block_ = 0;
		byte[] data_ = new byte[hex.length / 2];
		int index_ = 0;
		boolean next_ = false;

		for (int i_ = 0; i_ < hex.length; i_++) {
			block_ <<= 4;

			int pos_ = HEX_STRING.indexOf(Character.toUpperCase((char) hex[i_]));

			if (pos_ > -1)
				block_ += pos_;

			if (next_) {
				data_[index_] = (byte) (block_ & 0xff);
				index_++;
				next_ = false;
			} else
				next_ = true;
		}

		return data_;
	}

	private static String convertBinary2Hexadecimal(byte[] binary) {
		StringBuffer buffer_ = new StringBuffer();
		int block_ = 0;

		for (int i_ = 0; i_ < binary.length; i_++) {
			block_ = binary[i_] & 0xFF;

			buffer_.append(HEX_STRING.charAt(block_ >> 4));

			buffer_.append(HEX_STRING.charAt(binary[i_] & 0x0F));
		}

		return buffer_.toString();
	}
}
