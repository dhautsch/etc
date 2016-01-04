import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public class SortListOfStrings {

	public static void main(String[] args) {
		ArrayList<String> words_ = new ArrayList<String>(50);
		words_.add("once");
		words_.add("upon");
		words_.add("a");
		words_.add("time");
		
		Collections.sort(words_);
		
		for (String s_ : words_) {
			System.out.println(s_);
		}
		
		Map<String,String> countryNames_ = new HashMap<String,String>(50);
		countryNames_.put("GB", "Great Britain");
		countryNames_.put("FR", "France");
		countryNames_.put("IT", "Italy");
		countryNames_.put("FW", "Far Far Away");
		
		Map<String, String> sortedCountryNames_ = new TreeMap<String, String>(countryNames_);
		
		for (String s_ : sortedCountryNames_.keySet()) {
			System.out.println(s_ + " -> " + sortedCountryNames_.get(s_));
		}
	}

}
