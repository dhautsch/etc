#
# Hadoop word count in python
#

TOP=$(cd $(dirname $0) && pwd)
HADOOP_TOP=/user/r2udeh
#hadoop fs -rm -r -f -skipTrash $HADOOP_TOP/.Trash

HADOOP_INDIR=$HADOOP_TOP/input_dir
HADOOP_OUTDIR=$HADOOP_TOP/output_dir

#
# Cleanup input_dir and output_dir
#
for d in $HADOOP_INDIR $HADOOP_OUTDIR
do
        hadoop fs -rm -R -skipTrash $d
done

hadoop fs -mkdir $HADOOP_INDIR
hadoop fs -put /etc/services $HADOOP_INDIR

# RUN_OLD_WAY=t

if test -n "$RUN_OLD_WAY"
then
        #
        # OLD way is deprecated but still works
        #
        hadoop jar /usr/hdp/2.5.0.0-1133/hadoop-mapreduce/hadoop-streaming.jar \
        -file mapper.py -file reducer.py \
        -mapper mapper.py \
        -reducer reducer.py \
        -input $HADOOP_TOP/input_dir \
        -output $HADOOP_TOP/output_dir
else
        hadoop jar /usr/hdp/2.5.0.0-1133/hadoop-mapreduce/hadoop-streaming.jar \
        -files mapper.py,reducer.py \
        -mapper mapper.py \
        -reducer reducer.py \
        -input $HADOOP_TOP/input_dir \
        -output $HADOOP_TOP/output_dir
fi

hadoop fs -ls $HADOOP_TOP/output_dir
hadoop fs -cat $HADOOP_TOP/output_dir/part-00000

#!/usr/bin/env python
#
# mapper.py
#
"""A word count Mapper, using Python iterators and generators."""

import sys

def read_input(file):
    for line in file:
        # split the line into words
        yield line.split()

def main(separator='\t'):
    # input comes from STDIN (standard input)
    data = read_input(sys.stdin)
    for words in data:
        # write the results to STDOUT (standard output);
        # what we output here will be the input for the
        # Reduce step, i.e. the input for reducer.py
        #
        # tab-delimited; the trivial word count is 1
        for word in words:
            print '%s%s%d' % (word, separator, 1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python
#
# reducer.py
#
"""A word count Reducer, using Python iterators and generators."""

from itertools import groupby
from operator import itemgetter
import sys

def read_mapper_output(file, separator='\t'):
    for line in file:
        yield line.rstrip().split(separator, 1)

def main(separator='\t'):
    # input comes from STDIN (standard input)
    data = read_mapper_output(sys.stdin, separator=separator)
    # groupby groups multiple word-count pairs by word,
    # and creates an iterator that returns consecutive keys and their group:
    #   current_word - string containing a word (the key)
    #   group - iterator yielding all ["&lt;current_word&gt;", "&lt;count&gt;"] items
    for current_word, group in groupby(data, itemgetter(0)):
        try:
            total_count = sum(int(count) for current_word, count in group)
            print "%s%s%d" % (current_word, separator, total_count)
        except ValueError:
            # count was not a number, so silently discard this item
            pass

if __name__ == "__main__":
    main()
