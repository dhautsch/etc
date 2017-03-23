#!/usr/bin/python

import pdb
import json
from pprint import pprint as pp

JSON = """
{
	"columns" : [
		{
			"name" : "ID_1",
			"type" : "NUMERIC",
			"precision" : "5",
			"scale" : "0",
			"nullable" : "1"
		}
		,{
			"name" : "ADDRESS_1",
			"type" : "CHAR",
			"precision" : "10",
			"scale" : "0",
			"nullable" : "1"
		}
		,{
			"name" : "ADDRESS_2",
			"type" : "CHAR",
			"precision" : "10",
			"scale" : "0",
			"nullable" : "1"
		}
		,{
			"name" : "ID_2",
			"type" : "NUMERIC",
			"precision" : "5",
			"scale" : "0",
			"nullable" : "1"
		}
	]
}
"""

#pdb.set_trace()

OBJ = json.JSONDecoder().decode(JSON)
for aref_ in OBJ['columns'] :
	print(aref_['name'])
