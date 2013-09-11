#!/bin/sh

PATH=/bin:/sbin/:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LOGGER='logger -p mail.info -t watchmail'

if [ "$1" = "test" ]; then
	SENDMAIL='echo sendmail'
else
	SENDMAIL=sendmail
fi
FROMDOMAIN='@domain.com|@domain2.com'
WATCHMAIL='jiancha@domain.com'
#���б��ʼ����ᱻ���
SKIPFROM='xxx1@domainc.om|xxx2@domain.com'
#���б���Ϊ�����ռ��˲��ᱻ���
SKIPTO='liuhg@domain.com'
#���б��ʼ�����Ϊ�ռ��ˡ������˶����ᱻ���
SKIPGOD='xx1@domain.com|xx2@domain.com'
ALLOWML='mlxxx1@domain.com|mlxxx2@domain.com'

WATCHDIR=/home/postfix/watchdata
MLDATADIR=/home/postfix/mldata
TIME=`date '+%Y%m%d.%H.%M.%S'`
TMPMAIL="$TIME.mail."`od -vAn -N4 -tu4 < /dev/urandom | tr -d ' ,\n'`

cleartmp()
{
	rm -f $WATCHDIR/tmp/$TMPMAIL $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body
}

if [ ! -d $WATCHDIR ]; then
	mkdir -p $WATCHDIR/new $WATCHDIR/cur $WATCHDIR/tmp
	chown -R nobody:nobody $WATCHDIR
	chmod -R 700 $WATCHDIR
fi
cat > $WATCHDIR/tmp/$TMPMAIL
#���ʼ��ָ���ʼ�ͷ(header)���ʼ���(body)��������
sed '/^$/q' $WATCHDIR/tmp/$TMPMAIL > $WATCHDIR/tmp/$TMPMAIL.header
sed '1,/^$/d' $WATCHDIR/tmp/$TMPMAIL > $WATCHDIR/tmp/$TMPMAIL.body

MID=`cat $WATCHDIR/tmp/$TMPMAIL.header | grep ' id ' | head -1 | awk -F' id ' '{print $2}' | tr -d ';'`
LOGGER="logger -p mail.info -t watchmail:$MID"
# skip loop
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^Subject: \[WATCH\]'`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip loop mail at watchmail." | $LOGGER
	exit 0
fi

#������������������б����ֱ������
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^From:|^Reply-To:' | egrep -i "${SKIPFROM}|${SKIPGOD}"`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip from mail address at watchmail." | $LOGGER
	exit 0
fi

#��������б�ĵ�ַ���ռ������ֱ������������������ڳ�����Ͳ�����
TOGO=`perl -ne 'if (/^Cc:|^To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header`
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^To:' | awk -F, '{print $1}' | egrep -i "$SKIPTO"`
if [ "$TOGO" = "" ] && [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip only to mail address at watchmail." | $LOGGER
	exit 0
fi
#��������˺ͻظ���ַ�������Ա���˾�����ʾ�ս������ʼ�������BCC
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^From:|^Reply-To:' | egrep -i "$FROMDOMAIN"`
if [ "$GO" = "" ]; then
	cleartmp;
	echo "Skip internet mail address at watchmail." | $LOGGER
	exit 0
fi
#���TO����CC������ʼ��б������������BCC
SKIPMAIL="${SKIPGOD}|${ALLOWML}"
for DOMAIN in `echo $FROMDOMAIN | tr -s '|' ' ' | tr -d '@'`; do
	if [ -d $MLDATADIR/$DOMAIN ]; then
		CHKMLLIST=`ls -d $MLDATADIR/$DOMAIN/*`
		CHKMLLIST=`basename $CHKMLLIST | awk '{print $1"@'$DOMAIN'"}'`
		if [ "$CHKMLLIST" != "" ]; then
			SKIPMAIL="${SKIPMAIL}|"`echo $CHKMLLIST | tr ' ' '|'`
		fi
	fi
done
GO=`perl -ne 'if (/^Cc:|^To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header | egrep -i "$SKIPMAIL"`
#GO=`perl -ne '/^Cc:|^To:/i../[\w\-]+@[\w\-]+\..*>$/ and print' $WATCHDIR/tmp/$TMPMAIL.header | egrep -i "$SKIPMAIL"`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip To and Cc have god,maillist,allowml mail at watchmail." | $LOGGER
	exit 0
fi
#������еĵ�ַ��ȫ�����Լ���˾�ĵ�ַ����ֻ����������������BCC
GO=`perl -ne 'if (/^Cc:|^To:|^From:|^Reply-To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header | egrep -v -i "$FROMDOMAIN"`
#GO=`perl -ne '/^Cc:|^To:|^From:|^Reply-To:/i../[\w\-]+@[\w\-]+\..*>$/ and print' $WATCHDIR/tmp/$TMPMAIL.header | egrep -v -i "$FROMDOMAIN"`
if [ "$GO" = "" ]; then
#	sed -i '' 's/^Subject: /Subject: [WATCH] /' $WATCHDIR/tmp/$TMPMAIL.header
	grep -i '^Subject: ' $WATCHDIR/tmp/$TMPMAIL.header > /dev/null && perl -i -pe 's/^Subject: /Subject: [WATCH] /i' $WATCHDIR/tmp/$TMPMAIL.header || perl -i -pe 's/^From: /Subject: [WATCH]\nFrom: /i' $WATCHDIR/tmp/$TMPMAIL.header
	cat $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body > $WATCHDIR/new/$TMPMAIL
	#cat $WATCHDIR/new/$TMPMAIL | $SENDMAIL -f watch liuhg@ematchina.com
	cleartmp;
	echo "Skip to all EAT mail at watchmail." | $LOGGER
	exit 0
fi
#sed -i '' 's/^Subject: /Subject: [WATCH] /' $WATCHDIR/tmp/$TMPMAIL.header
grep -i '^Subject: ' $WATCHDIR/tmp/$TMPMAIL.header > /dev/null && perl -i -pe 's/^Subject: /Subject: [WATCH] /i' $WATCHDIR/tmp/$TMPMAIL.header || perl -i -pe 's/^From: /Subject: [WATCH]\nFrom: /i' $WATCHDIR/tmp/$TMPMAIL.header
cat $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body | $SENDMAIL -f watch $WATCHMAIL
cleartmp;
echo "Send this mail to jiancha at watchmail." | $LOGGER
exit 0

