#!/bin/ksh

OUT_FILE=tarball.bin

if test "$#" = 0
then
    echo "Usage $0 file0 .. fileN"
    exit 1
fi

(
cat <<'HERE'
#!/bin/ksh
#
# This is a self extracting tarball.
# Chmod +x the file to list or extract - don@hautsch.com
#

if test -n "$DOIT"
then
        TAR_OPTS=xvf
else
        TAR_OPTS=tvf
fi

base64 -d <<EOF | tar $TAR_OPTS -
HERE

tar cvf - "$@" | base64
date +'EOF'

cat <<'HERE'
if test -z "$DOIT"
then
        cat <<EOF

#
# This was a dry run, export DOIT to extract - don@hautsch.com
#
EOF

fi
HERE
) > $OUT_FILE

echo created $(whoami)@$(uname -n):$(pwd)/$OUT_FILE
