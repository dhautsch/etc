#!/usr/bin/python3.5

import sys
import urllib.request
import xml.etree.ElementTree as ET
from pprint import pprint

station_dict = {}

weather_data_tags_dict = {
    'observation_time' : '',
    'weather' : '',
    'temp_f' : '',
    'temp_c' : '',
    'dewpoint_f' : '',
    'dewpoint_c' : '',
    'relative_humidity' : '',
    'wind_string' : '',
    'visibility_mi' : '',
    'pressure_string' : '',
    'pressure_in' : '',
    'location' : ''
    }

url = "http://w1.weather.gov/xml/current_obs/index.xml"
request = urllib.request.urlopen(url)
content = request.read().decode()
xml_root = ET.fromstring(content)

for station_ in xml_root.findall('station') :
    if station_.find('state').text == 'MD':
        station_dict[station_.find('station_id').text] = station_.find('station_name').text

pprint(station_dict)
station_ = input("Input station id :")
if station_ not in station_dict :
    print(station_, "is unknown, exiting!")
    sys.exit(0)

url_general = "http://www.weather.gov/xml/current_obs/{}.xml"
url = url_general.format(station_)

request = urllib.request.urlopen(url)
content = request.read().decode()

xml_root = ET.fromstring(content)

for k in weather_data_tags_dict:
    elem_ = xml_root.find(k)
    if elem_ != None:
        weather_data_tags_dict[k] = xml_root.find(k).text

pprint(weather_data_tags_dict)
