import java.io.BufferedReader;
import java.io.Console;
import java.io.File;
import java.io.InputStreamReader;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

public class Blowfish {
	/**
	 * Returns argv[0] decrypted string. The string has to be encrypted using
	 * -Dencrypt=t with the key in final static char [] SHORT_KEY or use the
	 * runnable BlowfishApp.jar JavaFX application to encrypt the string. If the
	 * decrypted string is in one of the following forms: string:uid or
	 * string:uid0,uid1,... then the "string" part is returned only if the
	 * user.name system property is in uid, uid0, uid1. To return the "string"
	 * part and uid list use -Drawoutput=t
	 * 
	 * Note if K > 16 chars then you need to include other jars for handling
	 * large keys
	 * 
	 * @author don@hautsch.com
	 *
	 */
	final static char[] P2 = { 'e', 'n', 'c', 'r', 'y', 'p', 't' };
	final static char[] P3 = { 'r', 'a', 'w', 'o', 'u', 't', 'p', 'u', 't' };
	final static char[] P4 = { '/', 'u', 's', 'r', '/', 'b', 'i', 'n', '/', 'w', 'h', 'o', 'a', 'm', 'i' };
	final static char[] P5 = { 'C', ':', '\\', 'W', 'i', 'n', 'd', 'o', 'w', 's', '\\', 'S', 'y', 's', 't', 'e', 'm', '3', '2', '\\', 'w', 'h', 'o', 'a', 'm', 'i' };
	final static String HEX_STRING = "0123456789ABCDEF";

	final static char[] K = { '{', '3', '3', '4', '6', 'A', '5', '3', '3', '-', '7', '4', '2', '3', '-', '4' };

	public static String whoAmI() {
		String ret_ = HEX_STRING;

		try {
			String s_ = new String(P4);
			File f = new File(s_);
			Process proc_ = Runtime.getRuntime().exec(f.exists() ? s_ : new String(P5));
			BufferedReader input = new BufferedReader(new InputStreamReader(proc_.getInputStream()));
			while ((s_ = input.readLine()) != null) {
				s_ = s_.trim();
				if (s_.isEmpty() == false) {
					int i_ = s_.indexOf('\\');

					if (i_ < 0)
						ret_ = s_;
					else if (i_ < s_.length() - 1)
						ret_ = s_.substring(i_+1);
				}
			}
			input.close();
		} catch (Exception err) {
			err.printStackTrace();
		}
		return ret_;
	}

	public static void main(String[] args) {
		String s_;

		if (System.getProperty(new String(P2)) != null) {
			Console console_ = System.console();

			if (console_ != null) {
				s_ = console_.readLine("String to encrypt: ");

				if (s_ != null && s_.isEmpty() == false) {
					System.out.println("String entered : '" + s_ + "'");
					System.out.println("String encrypted: '" + encrypt(s_) + "'");
				}
			}
		} else if (args != null && args.length == 1 && args[0].isEmpty() == false) {
			s_ = decrypt(args[0]);

			if (s_ != null && s_.isEmpty() == false) {
				String[] ret_ = s_.split("[:,]");

				if (System.getProperty(new String(P3)) != null) {
					System.out.println(s_);
				} else if (ret_.length == 1) {
					System.out.println(ret_[0]);
				} else if (ret_.length > 1) {
					s_ = whoAmI();

					for (int i_ = 1; i_ < ret_.length; i_++) {
						if (ret_[i_].equals(s_)) {
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
			String key_ = new String(K);
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
			String key_ = new String(K);
			SecretKeySpec keySpec_ = new SecretKeySpec(key_.getBytes(), "Blowfish");
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
