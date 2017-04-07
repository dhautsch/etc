import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintStream;
import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.zip.GZIPOutputStream;
import java.util.Date;
import java.util.TimeZone;

//
//export JDBC_URL=jdbc:netezza://host:5480/TEST_DB?user=scott&password=tiger
//export JDBC_DRIVER=org.netezza.Driver
//export JDBC_URL=jdbc:oracle:thin:scott/tiger@//host:1521/SID
//export JDBC_DRIVER=oracle.jdbc.OracleDriver
//export JAVA_HOME=<PARENT_DIRS>/java
//PATH=$JAVA_HOME/bin:$PATH
//export CLASSPATH=<PARENT_DIRS>/nzjdbc3.jar:<PARENT_DIRS>/ojdbc6.jar:.
//javac JDBCExample.java
//java  JDBCExample
//

class JDBCExample {
	private static boolean isDateTimeColumn(int columnType) {
		return (columnType == Types.TIMESTAMP) || (columnType == Types.DATE) || (columnType == Types.TIME);
	}

	public static String qquote(String s) {
		return "\042" + (s == null ? "" : s) + "\042";
	}

	public static void main(String args[]) {
		Connection conn_ = null;
		Statement stmt_ = null;

		try {
			String colDelim_ = "|";
			String sql_ = null;
			GZIPOutputStream gzipOut_ = null;
			boolean printUsage_ = false;
			InputStream in_ = System.in;
			String nullStr_ = null;
			String flagfile_ = null;
			boolean gzip_ = false;
			Date startTS_ = new Date();
			int argCnt_ = args.length;

			for (String s_ : args) {
				if (s_.equals("--gzip")) {
					gzip_ = true;
					argCnt_--;
				}
				else if (s_.startsWith("--null-str=")) {
					nullStr_ = s_.replaceFirst("--null-str=", ""); 
					argCnt_--;
				}
				else if (s_.startsWith("--flagfile=")) {
					String[] l_ = s_.split("=");

					argCnt_--;

					if (l_.length == 2) {
						flagfile_ = l_[1];
					} else {
						printUsage_ = true;
					}
				}
				if (s_.startsWith("--sqlfile=")) {
					String[] l_ = s_.split("=");

					argCnt_--;

					if (l_.length == 2 && (l_[1].equals("stdin") || l_[1].equals("-"))) {
						in_ = System.in;
					} else if (l_.length == 2) {
						in_ = new FileInputStream(l_[1]);
					} else {
						printUsage_ = true;
					}
				}
				else if (s_.startsWith("--col-delim=")) {
					try {
					char c_ = (char) Integer.parseInt(s_.replaceFirst("--col-delim=", "")); 
					colDelim_ = String.valueOf(c_);
					argCnt_--;
					} catch (NumberFormatException e_) {
						printUsage_ = true;
					}
				}
			}

			if (argCnt_ != 0)
				printUsage_ = true;
			
			if (printUsage_) {
				System.err.println("Usage : " + JDBCExample.class.getName()
						+ "[--sqlfile=(path|stdin|-) --flagfile=path --col-delim=colDelim --null-str=STR --gzip]");
				System.err.println("\t--sqlfile=(path|stdin|-) : OPTIONAL. Path to file containing sql, default to stdin.");
				System.err.println("\t--flagfile=path : OPTIONAL. Write meta data and extracted count to file.");
				System.err.println("\t--col-delim : OPTIONAL. Character for column delimiter in decimal. Defaults to |.");
				System.err.println("\t--null-str : OPTIONAL. String to output for nulls.");
				System.err.println("\t--gzip : OPTIONAL. Gzip output.");
				System.err.println();
				System.err.println("export JDBC_DRIVER=org.netezza.Driver");
				System.err.println("export JDBC_URL=jdbc:netezza://HOST:PORT/DB?user=USER&password=PASS");
				System.err.println();
				System.err.println("export JDBC_DRIVER=oracle.jdbc.OracleDriver");
				System.err.println("export JDBC_URL=jdbc:oracle:thin:USER/PASS@//HOST:PORT/SID");
				System.exit(0);
			}

			Class.forName(System.getenv("JDBC_DRIVER"));

			conn_ = DriverManager.getConnection(System.getenv("JDBC_URL"));

			for (SQLWarning warn = conn_.getWarnings(); warn != null; warn = warn.getNextWarning()) {
				System.err.println("SQL Warning:");
				System.err.println("State  : " + warn.getSQLState());
				System.err.println("Message: " + warn.getMessage());
				System.err.println("Error  : " + warn.getErrorCode());
			}

			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			byte[] buffer = new byte[8 * 1024];

			int bytesRead;
			while ((bytesRead = in_.read(buffer)) > 0) {
				baos.write(buffer, 0, bytesRead);
			}
			sql_ = baos.toString();

			stmt_ = conn_.createStatement();

			sql_ = sql_.replace(";", "");

			long extractCnt_ = 0;
			ResultSet rs_ = stmt_.executeQuery(sql_);
			ResultSetMetaData md_ = rs_.getMetaData();

			String nl_ = System.getProperty("line.separator");


			if (gzip_)
				gzipOut_ = new GZIPOutputStream(System.out);

			while (rs_.next()) {
				StringBuilder sb_ = new StringBuilder();
				
				for (int i_ = 1; i_ <= md_.getColumnCount(); i_++) {
					if (nullStr_ != null && rs_.getObject(i_) == null)
						sb_.append(nullStr_);
					else
						sb_.append(rs_.getString(i_));

					if (i_ < md_.getColumnCount())
						sb_.append(colDelim_);
				}
				sb_.append(nl_);

				String s_ = sb_.toString();

				if (gzip_) {
					byte b_[] = s_.getBytes();
					gzipOut_.write(b_, 0, b_.length);
				}
				else
					System.out.print(s_);

				extractCnt_++;
			}

			if (gzip_)
				gzipOut_.close();

			if (flagfile_ != null) {
				int random_ = (int )(Math.random() * 50 + 1);
				String tmp_ = flagfile_ + random_;
				PrintStream out_ = new PrintStream(tmp_);
				Date endTS_ = new Date();

				out_.println("{");
				out_.println("\t" + qquote("fields") + ": [");

				for (int i_ = 1; i_ <= md_.getColumnCount(); i_++) {
					String name_ = md_.getColumnLabel(i_);
					String typeName_ = md_.getColumnTypeName(i_);
					int nullable_ = md_.isNullable(i_);
					int precision_ = md_.getPrecision(i_);
					int scale_ = md_.getScale(i_);

					out_.print("\t\t");

					out_.println("{");
					out_.println("\t\t\t" + qquote("metadata") + ": { ");
					out_.println("\t\t\t\t" + qquote("name") + ": " + qquote(name_));
					out_.println("\t\t\t},");
					out_.println("\t\t\t" + qquote("name") + ": " + qquote(name_) + ",");
					out_.println("\t\t\t" + qquote("nullable") + ": "
							+ (nullable_ == DatabaseMetaData.columnNullable ? "true" : "false") + ",");

					if (typeName_.equals("INTEGER") || typeName_.equals("TIMESTAMP")) {
						typeName_ = typeName_.toLowerCase();
						out_.println("\t\t\t" + qquote("type") + ": " + qquote(typeName_));
					}
					else if (typeName_.equals("DATE")) {
						out_.println("\t\t\t" + qquote("type") + ": " + qquote("timestamp"));
					}
					else if (typeName_.equals("BIGINT")) {
						out_.println("\t\t\t" + qquote("type") + ": " + qquote("long"));
					}
					else if (typeName_.startsWith("VARCHAR") || typeName_.equals("CHAR")) {
						out_.println("\t\t\t" + qquote("type") + ": " + qquote("string"));
					}
					else if (typeName_.equals("NUMERIC") || typeName_.equals("NUMBER")) {
						out_.println("\t\t\t" + qquote("type") + ": "
								+ qquote("decimal("+ precision_ + "," + scale_ + ")"));
					}
					else {
						out_.println("\t\t\t" + qquote("type") + ": " + qquote(typeName_) + ",");
						out_.println("\t\t\t" + qquote("precision") + ": " + precision_ + ",");
						out_.println("\t\t\t" + qquote("scale") + ": " + scale_);
					}
					out_.print("\t\t}");
					if (i_ > 0 && i_ < md_.getColumnCount())
						out_.print(",");
					out_.println();
				}
				out_.println("\t],");
				out_.println("\t" + qquote("extract_cnt") + ": " + extractCnt_ + ",");
				out_.println("\t" + qquote("start_secs") + ": " + startTS_.getTime() / 1000l + ",");
				out_.println("\t" + qquote("end_secs") + ": " + endTS_.getTime() / 1000l + ",");
				out_.println("\t" + qquote("run_secs") + ": " + (endTS_.getTime() - startTS_.getTime())/ 1000l + ",");

				SimpleDateFormat sdf_ = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
				sdf_.setTimeZone(TimeZone.getTimeZone("GMT"));

				out_.println("\t" + qquote("start_ts") + ": " + qquote(sdf_.format(startTS_) + "Z") + ",");
				out_.println("\t" + qquote("end_ts") + ": " + qquote(sdf_.format(endTS_) + "Z"));
				out_.println("}");
				out_.close();

				File tmpFile_ = new File(tmp_);

				tmpFile_.renameTo(new File(flagfile_));
			}
			
			// Close the result set, statement and the connection
			rs_.close();
			stmt_.close();
			conn_.close();
		} catch (SQLException se_) {
			System.err.println("SQL Exception:");

			while (se_ != null) {
				System.err.println("State  : " + se_.getSQLState());
				System.err.println("Message: " + se_.getMessage());
				System.err.println("Error  : " + se_.getErrorCode());

				se_ = se_.getNextException();
			}
		} catch (Exception e_) {
			System.err.println(e_);
		} finally {
			// finally block used to close resources
			try {
				if (stmt_ != null)
					stmt_.close();
			} catch (SQLException se2) {
			}
			try {
				if (conn_ != null)
					conn_.close();
			} catch (SQLException se) {
				se.printStackTrace();
			}
		}
	}
}
