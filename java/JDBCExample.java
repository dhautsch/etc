import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.*;
import java.util.zip.GZIPOutputStream;

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

	public static void main(String args[]) {
		Connection conn_ = null;
		Statement stmt_ = null;

		try {
			String colDelim_ = "|";
			String sql_ = null;
			GZIPOutputStream gzipOut_ = null;
			boolean printUsage_ = false;
			String nullStr_ = null;
			boolean getMeta_ = false;
			boolean gzip_ = false;
			boolean doDump_ = false;
			Path p_ = null;

			int argCnt_ = args.length;
			
			for (String s_ : args) {
				if (s_.equals("--action=meta")) {
					getMeta_ = true;
					argCnt_--;
				}
				else if (s_.equals("--action=dump")) {
					doDump_ = true;
					argCnt_--;
				}
				else if (s_.equals("--gzip")) {
					gzip_ = true;
					argCnt_--;
				}
				else if (s_.startsWith("--null-str=")) {
					nullStr_ = s_.replaceFirst("--null-str=", ""); 
					argCnt_--;
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

			if (printUsage_ == false && argCnt_ == 1) {
				p_ = Paths.get(args[args.length-1]);
				argCnt_--;
				
				if (Files.isReadable(p_) == false)
					printUsage_ = true;
			}
			
			if (printUsage_ == false
					&& (argCnt_ != 0
						|| getMeta_ == false && doDump_ == false
						|| getMeta_ == true && doDump_ == true)
					)
				printUsage_ = true;
			
			if (printUsage_) {
				System.out.println("Usage : " + JDBCExample.class.getName()
						+ "--action=(dump|meta) [--col-delim=colDelim --null-str=STR pathToSqlFile]");
				System.out.println("\t--action=dump : data to stdout.");
				System.out.println("\t--action=meta : metadata to stdout.");
				System.out.println("\tpathToSqlFile : OPTIONAL. Path to file containing sql, default to stdin.");
				System.out.println("\t--col-delim : OPTIONAL. Character for column delimiter in decimal. Defaults to |.");
				System.out.println("\t--null-str : OPTIONAL. String to output for nulls.");
				System.out.println("\t--gzip : OPTIONAL. String to output for nulls.");
				System.out.println();
				System.out.println("export JDBC_DRIVER=org.netezza.Driver");
				System.out.println("export JDBC_URL=jdbc:netezza://HOST:PORT/DB?user=USER&password=PASS");
				System.out.println();
				System.out.println("export JDBC_DRIVER=oracle.jdbc.OracleDriver");
				System.out.println("export JDBC_URL=jdbc:oracle:thin:USER/PASS@//HOST:PORT/SID");
				System.exit(0);
			}

			Class.forName(System.getenv("JDBC_DRIVER"));

			conn_ = DriverManager.getConnection(System.getenv("JDBC_URL"));

			for (SQLWarning warn = conn_.getWarnings(); warn != null; warn = warn.getNextWarning()) {
				System.out.println("SQL Warning:");
				System.out.println("State  : " + warn.getSQLState());
				System.out.println("Message: " + warn.getMessage());
				System.out.println("Error  : " + warn.getErrorCode());
			}

			if (p_ != null)
				sql_ = new String(Files.readAllBytes(p_));
			else {
				ByteArrayOutputStream baos = new ByteArrayOutputStream();
				byte[] buffer = new byte[8*1024];

				int bytesRead;
				while ((bytesRead = System.in.read(buffer)) > 0) {
				    baos.write(buffer, 0, bytesRead);
				}
				sql_ = baos.toString();
			}

			stmt_ = conn_.createStatement();

			sql_ = sql_.replace(";", "");

			if (getMeta_)
				sql_ = "SELECT t.* FROM (" + sql_ + ") t WHERE 1 = 2";

			ResultSet rs_ = stmt_.executeQuery(sql_);
			ResultSetMetaData md_ = rs_.getMetaData();

			if (getMeta_) {
				System.out.println("{");
				System.out.println("\t\042columns\042 : [");

				for (int i = 1; i <= md_.getColumnCount(); i++) {
					String name_ = md_.getColumnLabel(i);
					String typeName_ = md_.getColumnTypeName(i);
					int nullable_ = md_.isNullable(i);
					int precision_ = md_.getPrecision(i);
					int scale_ = md_.getScale(i);

					System.out.print("\t\t");

					if (i > 1)
						System.out.print(",");

					System.out.println("{");
					System.out.println("\t\t\t\042name\042 : \042" + name_ + "\042,");
					System.out.println("\t\t\t\042type\042 : \042" + typeName_ + "\042,");
					System.out.println("\t\t\t\042precision\042 : \042" + precision_ + "\042,");
					System.out.println("\t\t\t\042scale\042 : \042" + scale_ + "\042,");
					System.out.println("\t\t\t\042nullable\042 : \042"
							+ (nullable_ == DatabaseMetaData.columnNullable ? 1 : 0) + "\042");
					System.out.println("\t\t}");
				}
				System.out.println("\t]");
				System.out.println("}");
			}

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
			}

			if (gzip_)
				gzipOut_.close();
			
			// Close the result set, statement and the connection
			rs_.close();
			stmt_.close();
			conn_.close();
		} catch (SQLException se_) {
			System.out.println("SQL Exception:");

			while (se_ != null) {
				System.out.println("State  : " + se_.getSQLState());
				System.out.println("Message: " + se_.getMessage());
				System.out.println("Error  : " + se_.getErrorCode());

				se_ = se_.getNextException();
			}
		} catch (Exception e_) {
			System.out.println(e_);
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
