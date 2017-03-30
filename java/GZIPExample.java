import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

public class GZIPExample {

	public static void main(String[] args) {
		Boolean printUsage_ = false;
		Boolean compress_ = false;
		Boolean decompress_ = false;
		InputStream in_ = System.in;
		OutputStream out_ = System.out;
		String infile_ = null;
		String outfile_ = null;
		int argCnt_ = args.length;

		for (String s_ : args) {
			if (s_.equals("--action=compress")) {
				argCnt_--;

				if (decompress_)
					printUsage_ = true;
				else
					compress_ = true;
			}

			if (s_.equals("--action=decompress")) {
				argCnt_--;

				if (compress_)
					printUsage_ = true;
				else
					decompress_ = true;
			}

			if (s_.startsWith("--infile=")) {
				String[] l_ = s_.split("=");

				argCnt_--;

				if (l_.length == 2 && (l_[1].equals("stdin") || l_[1].equals("-"))) {
					in_ = System.in;
				} else if (l_.length == 2) {
					infile_ = l_[1];
				} else {
					printUsage_ = true;
				}
			}

			if (s_.startsWith("--outfile=")) {
				String[] l_ = s_.split("=");

				argCnt_--;

				if (l_.length == 2 && (l_[1].equals("stdout") || l_[1].equals("-"))) {
					out_ = System.out;
				} else if (l_.length == 2) {
					outfile_ = l_[1];
				} else {
					printUsage_ = true;
				}
			}

		}

		if (argCnt_ != 0)
			printUsage_ = true;

		if (printUsage_) {
			System.err.println("Usage : " + GZIPExample.class.getName()
					+ "--action=(compress|decompress) [--infile=(path|stdin|-) --outfile=(path|stdout|-)]");
			System.err.println("\t--infile=(path|stdin|-) : OPTIONAL. Read from path or stdin, defaults to stdin.");
			System.err.println("\t--outfile=(path|stdout|-) : OPTIONAL. Write to path or stdout, defaults to stdout.");
			System.exit(0);
		}

		try {
			byte[] buffer_ = new byte[8 * 1024];
			int len_;

			if (infile_ != null)
				in_ = new FileInputStream(infile_);
			if (outfile_ != null)
				out_ = new FileOutputStream(outfile_);

			if (compress_) {
				GZIPOutputStream gzipOut_ = new GZIPOutputStream(out_);
				while ((len_ = in_.read(buffer_)) != -1) {
					gzipOut_.write(buffer_, 0, len_);
				}

				gzipOut_.close();
				out_.close();
				in_.close();
			} else {
				GZIPInputStream gzipIn_ = new GZIPInputStream(in_);

				while ((len_ = gzipIn_.read(buffer_)) != -1) {
					out_.write(buffer_, 0, len_);
				}
				gzipIn_.close();
				out_.close();
			}

		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}
