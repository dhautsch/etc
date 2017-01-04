#!/usr/bin/ksh -x

TMP_DIR=$HOME/tmp-$$-$(date +%Y%m%d%H%M%S)
URL=http://sharepoint/oursite
SP_LIST=Bogus

mkdir -p $TMP_DIR
trap 'rm -rf $TMP_DIR' EXIT

if cd $TMP_DIR
then
        GET_SP_LIST="$HOME/etc/perl/get_sp_list_items.pl -usetmp $TMP_DIR"
        DIGEST=$($GET_SP_LIST -digest $URL|perl -lane 'print $1 if m!d:FormDigestValue.*\047([^\047]+)\047!')
        echo $DIGEST

        $GET_SP_LIST $URL ${SP_LIST}|perl -lane 'print $1 if m!d:ID[^0-9]+(\d+)!'|tail -2 > ids.txt

        echo "{ '__metadata': { 'type': 'SP.Data.${SP_LIST}ListItem' }, 'Title': 'Updated-$$' }" > update_data.txt
        echo "{ '__metadata': { 'type': 'SP.Data.${SP_LIST}ListItem' }, 'Title': 'New_bogus-$$' }" > create_data.txt

        $GET_SP_LIST -create "$DIGEST" -data "$(cat create_data.txt)" $URL $SP_LIST

        $GET_SP_LIST -create "$DIGEST" -data "@create_data.txt" $URL $SP_LIST

        ID=$(head -1 ids.txt)

        test -n "$ID" && $GET_SP_LIST -update "$DIGEST" -id $ID -data "@update_data.txt" $URL $SP_LIST

        ID=$(tail -1 ids.txt)

        test -n "$ID" && $GET_SP_LIST -update "$DIGEST" -id $ID -data "$(cat update_data.txt)" $URL $SP_LIST

        test -n "$ID" && $GET_SP_LIST -delete "$DIGEST" -id $ID $URL $SP_LIST
fi

exit 0
