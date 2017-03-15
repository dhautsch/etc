import java.sql.*;

//
// export JDBC_URL=jdbc:netezza://host:5480/TEST_DB?user=scott&password=tiger
// export JDBC_DRIVER=org.netezza.Driver
// export JDBC_URL=jdbc:oracle:thin:scott/tiger@//host:1521/SID
// export JDBC_DRIVER=oracle.jdbc.OracleDriver
// export JAVA_HOME=<PARENT_DIRS>/java
// PATH=$JAVA_HOME/bin:$PATH
// export CLASSPATH=<PARENT_DIRS>/nzjdbc3.jar:<PARENT_DIRS>/ojdbc6.jar:.
// javac JDBCExample.java
// java  JDBCExample
//

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.*;

class JDBCExample {
	private static boolean isDateTimeColumn(int columnType) {
		return (columnType == Types.TIMESTAMP) || (columnType == Types.DATE) || (columnType == Types.TIME);
	}

	public static void main(String args[]) {
		Connection conn_ = null;
		Statement stmt_ = null;
		String colDelim_ = "|";

		try {
			boolean printUsage_ = false;
			String nullStr_ = null;
			boolean getMeta_ = false;
			boolean doDump_ = false;
			Path p_ = args.length > 1 ? Paths.get(args[args.length - 1]) : null;

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
			
			if (argCnt_ != 1
					|| getMeta_ == false && doDump_ == false
					|| getMeta_ == true && doDump_ == true
					|| p_ == null
					|| Files.isReadable(p_) == false)
				printUsage_ = true;
			
			if (printUsage_) {
				System.out.println("Usage : " + JDBCExample.class.getName()
						+ "--action=(dump|meta) [--col-delim=colDelim --null-str=STR] pathToSqlFile");
				System.out.println("\t--dump : data to stdout.");
				System.out.println("\t--meta : metadata to stdout.");
				System.out.println("\tpathToSqlFile : path to file containing sql.");
				System.out.println("\t--col-delim : optional character for column delimiter in decimal. Defaults to |.");
				System.out.println("\t--null-str : optional string to output for nulls.");
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

			String sql_ = new String(Files.readAllBytes(p_));

			stmt_ = conn_.createStatement();

			sql_ = "SELECT t.* FROM (" + sql_.replace(";", "") + ") t";

			if (getMeta_)
				sql_ = sql_ + " WHERE 1 = 2";

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

			while (rs_.next()) {
				for (int i_ = 1; i_ <= md_.getColumnCount(); i_++) {
					if (nullStr_ != null && rs_.getObject(i_) == null)
						System.out.print(nullStr_);
					else
						System.out.print(rs_.getString(i_));

					if (i_ < md_.getColumnCount())
						System.out.print(colDelim_);
				}
				System.out.println();
			}

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
