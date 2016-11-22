#!/usr/bin/python

import sys
import fileinput
import os
import subprocess
from string import Template
from subprocess import *

BNAME = os.path.basename(__file__)
INSTALLEDDIR = os.path.abspath(os.path.dirname(__file__))
DECRYPT = os.environ['HOME'] + '/etlsupp/bin/decrypt'
SQLPLUS = os.environ['HOME'] + '/etlsupp/bin/sqlplus'
CONFIG  = os.environ['HOME'] + '/etlsupp/config.properties'
PROP = 'com.hautsch.team_db_conn'
CONNECT = ''

os.chdir(INSTALLEDDIR)
CWD = os.getcwd()

if CWD != INSTALLEDDIR :
	print "Chdir to ", INSTALLEDDIR, " failed!!!"
	sys.exit(1)

for line_ in fileinput.input(CONFIG) :
	if line_.startswith(PROP) :
		a_ = line_.split('=')
		CONNECT = a_[1].strip()
		break

if len(CONNECT) < 1 :
	print "Cannot get " + PROP + " from " + CONFIG
	sys.exit(1)

CONNECT = Popen([DECRYPT, CONNECT], stdout=PIPE).communicate()[0].strip()
if len(CONNECT) < 1 :
	print "Cannot decrypt " + PROP + " from " + CONFIG
	sys.exit(1)

SQL = Template("""
set heading off;
set LINESIZE 1000;
set pagesize 1000;
set feedback off;
set echo off;
connect $CONNECT;
With parts as (select table_name, partition_name, get_high_value_as_date(table_name, partition_name) as DT
from user_tab_partitions
where table_name like 'A22_%_PART')
select  'alter table ' || table_name || ' drop partition ' || partition_name || ' /* ' || to_char(dt, 'YYYY-MM-DD') || ' */ ;' stmt
from parts where dt < (sysdate-31*3)
order by 1;
quit;
""").substitute(locals())

SUBPROCESS = subprocess.Popen([SQLPLUS, "-s", "/NOLOG"], stdout=PIPE, stdin=PIPE)
SUBPROCESS.stdin.write(SQL)
OUTPUT = SUBPROCESS.communicate()[0]

print OUTPUT

SQL = Template("""
connect $CONNECT;
$OUTPUT
quit;
""").substitute(locals())

SUBPROCESS = subprocess.Popen([SQLPLUS, "-s", "/NOLOG"], stdout=PIPE, stdin=PIPE)
SUBPROCESS.stdin.write(SQL)
OUTPUT = SUBPROCESS.communicate()[0]

print OUTPUT

sys.exit(0)
