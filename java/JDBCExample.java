import java.sql.*;

//
// Following env vars and select is for netezza
//
// export JDBC_URL=jdbc:netezza://host:5480/TEST_DB
// export JDBC_DRIVER=org.netezza.Driver
// export JDBC_USER=scott
// export JDBC_PASS=tiger
// export JAVA_HOME=<PARENT_DIRS>/java
// PATH=$JAVA_HOME/bin:$PATH
// export CLASSPATH=<PARENT_DIRS>/nzjdbc3.jar:.
// javac JDBCExample.java
// java  JDBCExample
//

public class JDBCExample {
	public static void main(String[] args) {
		Connection conn_ = null;
		Statement stmt_ = null;
		try {
			// STEP 2: Register JDBC driver
			Class.forName(System.getenv("JDBC_DRIVER"));

			// STEP 3: Open a connection
			System.out.println("Connecting to database...");
			conn_ = DriverManager.getConnection(System.getenv("JDBC_URL"), System.getenv("JDBC_USER"),
					System.getenv("JDBC_PASS"));

			// STEP 4: Execute a query
			System.out.println("Creating statement...");
			stmt_ = conn_.createStatement();
			String sql_ = "select count(*) as cnt from _v_table";
			ResultSet rs_ = stmt_.executeQuery(sql_);

			// STEP 5: Extract data from result set
			while (rs_.next()) {
				// Retrieve by column name
				int cnt_ = rs_.getInt("cnt");

				// Display values
				System.out.println(sql_ + ": " + cnt_);
			}
			// STEP 6: Clean-up environment
			rs_.close();
			stmt_.close();
			conn_.close();
		} catch (SQLException se) {
			// Handle errors for JDBC
			se.printStackTrace();
		} catch (Exception e) {
			// Handle errors for Class.forName
			e.printStackTrace();
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
		System.out.println("Goodbye!");
	}
}
