import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class Ps {

        public static void main(String[] args) {
                // TODO Auto-generated method stub
                System.out.println("user.name = " + System.getProperty("user.name"));

                RuntimeMXBean b_ = ManagementFactory.getRuntimeMXBean();
                String name = b_.getName();
                Map<String, String> m_ = b_.getSystemProperties();

                String[] pid_ = name.split("@");
                System.out.println("Process ID for this app = " + pid_[0]);
                List<String> processes = listRunningProcesses();
                Iterator<String> it = processes.iterator();

                while (it.hasNext()) {
                        String ps_ = it.next();
                        String[] a_ = ps_.split("\\s+");
                        if (a_[1].equals(pid_[0])) {
                                System.out.println("User ID for this app = " + a_[0]);
                                System.out.println(ps_);
                        }
                }
        }

        public static List<String> listRunningProcesses() {
                List<String> processes = new ArrayList<String>();
                try {
                        String line;
                        Process p = Runtime.getRuntime().exec("ps -ef");
                        BufferedReader input = new BufferedReader(new InputStreamReader(p.getInputStream()));
                        while ((line = input.readLine()) != null) {
                                if (!line.trim().equals("")) {
                                        processes.add(line);
                                }
                        }
                        input.close();
                } catch (Exception err) {
                        err.printStackTrace();
                }
                return processes;
        }
}
