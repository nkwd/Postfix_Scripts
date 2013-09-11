#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

MLDATADIR=/home/postfix/mldata
MLNAME=$1
DOMAIN=$2
# �����ʼ��б��С
# 5M
#LIMIT_SIZE=5242880
# 10M
LIMIT_SIZE=10485760
# 20M
#LIMIT_SIZE=20967520
#�����ȴ�ʱ�䣬��λ����
LOCKWAIT=300

#����ļ����б��Ƿ�Ϊ����״̬
#��������򷵻�һ�������ź�
#��qmail���ʼ���Ϊ�����Ժ��ٴ���
if [ -f $MLDATADIR/$DOMAIN/$MLNAME/lock ]; then
	ERRINFO="$0 said: $MLNAME@$DOMAIN is lock,retry"
	LOCKTIME=1
	while [ -f $MLDATADIR/$DOMAIN/$MLNAME/lock ]; do
		#ERRINFO=$ERRINFO"."
		sleep 1
		if [ $LOCKTIME -gt "$LOCKWAIT" ]; then
			#���ʼ����¶���һ����ʱ�ļ���
			TMPMAIL="$MLDATADIR/$DOMAIN/$MLNAME/tmp/$HOSTNAME.$MLNAME.$DOMAIN.$SUBTIME.$NUM."`head -c32 /dev/urandom | sha1`
			sed '/^Return-Path:/Id' > $TMPMAIL
			#���ʼ��ָ���ʼ�ͷ(header)���ʼ���(body)��������
			sed '/^$/q' $TMPMAIL > $TMPMAIL.header
			BAKTO=`grep '^From: ' $TMPMAIL.header | sed 's/From:/To:/I'`
			cat << BAKMAIL | sendmail -i -t -f $MLNAME@$DOMAIN
From: $MLNAME@$DOMAIN
$BAKTO
Subject: �ʼ��б�${MLNAME}@${DOMAIN}��æ֪ͨ��
Content-Type: multipart/mixed;
 boundary="020806040501030605070803"

--020806040501030605070803
Content-Type: text/plain; charset=gb2312
Content-Transfer-Encoding: 8bit

�𾴵ķ����ˣ����ã�
    ���������ʼ��б�${MLNAME}@${DOMAIN}���ڷ�æ�����Ժ����ԡ�
����ԭʼ�ʼ��뿴������лл��


--020806040501030605070803
Content-Type: message/rfc822;
 name="$MLNAME@$DOMAIN.eml"
Content-Transfer-Encoding: 8bit
Content-Disposition: attachment;
 filename="$MLNAME@$DOMAIN.eml"

`cat $TMPMAIL`


--020806040501030605070803--
BAKMAIL
			ERRINFO=$ERRINFO" $LOCKTIME times,retry is fail!bak to from."
			logger -p mail.info -t MailList "$ERRINFO"
			rm $TMPMAIL $TMPMAIL.header
			exit 0
		fi
		LOCKTIME=`expr $LOCKTIME + 1`
	done
	ERRINFO=$ERRINFO" $LOCKTIME times,unlock."
	logger -p mail.info -t MailList "$ERRINFO"
fi
#����ʼ�������б��ֹ�����б�ͬʱ����
echo 1 > $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "Write lock file fail!!!" ; exit 1) || exit 1
#����ļ����к��Ƿ��ǽ���ĵ�һ��
#�����������ںͱ�������ڲ����Ͼ͸�λΪ��һ��
#�������������д�������ļ�
OLDYTIME=`cat $MLDATADIR/$DOMAIN/$MLNAME/year`
YTIME=`date '+%Y'`
if [ "$YTIME" != "$OLDYTIME" ]; then
	echo $YTIME > $MLDATADIR/$DOMAIN/$MLNAME/year
fi
OLDSUBTIME=`cat $MLDATADIR/$DOMAIN/$MLNAME/today`
SUBTIME=`date '+%m%d'`
if [ "$SUBTIME" != "$OLDSUBTIME" ]; then
	echo $SUBTIME > $MLDATADIR/$DOMAIN/$MLNAME/today
	echo 1 > $MLDATADIR/$DOMAIN/$MLNAME/number
fi
#��ȡ�ʼ����к�
#���µ����кű��浽�ļ�
NUM=`cat $MLDATADIR/$DOMAIN/$MLNAME/number`
if [ "$NUM" = "" ]; then
	NUM=1
fi
TIME=`date '+%Y/%m/%d %H:%M:%S'`
#����return-path���ʼ�
USER=$MLNAME
HOST=$DOMAIN
#��ȡ�б���������û�������TO�ı���
#����б�Ϊ����ֱ���˳��ó���
#ͬʱ�������ʼ��б�
TO=`cat $MLDATADIR/$DOMAIN/$MLNAME/mluser`
if [ "$TO" = "" ]; then
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "Delete lock file fail!!!" ; exit 1) || exit 1
	logger -p mail.info -t MailList "$0 said: no mail address at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
HOSTNAME=`hostname`
#���ʼ����¶���һ����ʱ�ļ���
TMPMAIL="$MLDATADIR/$DOMAIN/$MLNAME/tmp/$HOSTNAME.$MLNAME.$DOMAIN.$SUBTIME.$NUM."`head -c32 /dev/urandom | sha1`
sed '/^Return-Path:/Id' > $TMPMAIL
#���ʼ��ָ���ʼ�ͷ(header)���ʼ���(body)��������
sed '/^$/q' $TMPMAIL > $TMPMAIL.header
# �����ʼ��б��С
MAIL_SIZE=$(ls -l $TMPMAIL | awk '{print $5}')
if [ "$MAIL_SIZE" -gt "$LIMIT_SIZE" ]; then
	BAKTO=`grep '^From: ' $TMPMAIL.header | sed 's/From:/To:/I'`
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit
	logger -p mail.info -t MailList "$0 said: This mail size $MAIL_SIZE,is large."
	TU=B
	if [ "$LIMIT_SIZE" -gt "1023" ]; then
		LIMIT_SIZE="$(expr $LIMIT_SIZE / 1024)"
		TU=K
	fi
	if [ "$LIMIT_SIZE" -gt "1023" ]; then
		LIMIT_SIZE="$(expr $LIMIT_SIZE / 1024)"
		TU=M
	fi
	LIMIT_SIZE=${LIMIT_SIZE}$TU
	cat << BAKMAIL | sendmail -i -t -f $MLNAME@$DOMAIN
From: $MLNAME@$DOMAIN
$BAKTO
Subject: �Բ������շ����ʼ�̫��
Content-Type: multipart/mixed;
 boundary="020806040501030605070803"

--020806040501030605070803
Content-Type: text/plain; charset=gb2312
Content-Transfer-Encoding: 8bit

�𾴵ķ����ˣ����ã�
    ������${MLNAME}@${DOMAIN}�ʼ��б���ʼ���С������${LIMIT_SIZE}����
�޸ĺ����·��͡�
    ����ԭʼ�ʼ��뿴������лл��

--020806040501030605070803
Content-Type: message/rfc822;
 name="$MLNAME@$DOMAIN.eml"
Content-Transfer-Encoding: 8bit
Content-Disposition: attachment;
 filename="$MLNAME@$DOMAIN.eml"

`cat $TMPMAIL`


--020806040501030605070803--
BAKMAIL
	rm -f $TMPMAIL $TMPMAIL.header
	exit 0
fi
#���ʼ��ָ���ʼ�ͷ(header)���ʼ���(body)��������
sed '1,/^$/d' $TMPMAIL > $TMPMAIL.body
MID=`cat $TMPMAIL.header | grep ' id ' | head -1 | awk -F' id ' '{print $2}' | tr -d ';'`
#��ֹ�ʼ���ѭ�����������ʼ�����������maillist���
#����Ϊ��ѭ�����Զ�����
#ͬʱ�������ʼ��б�
NOLOOP=`grep -c "^Maillist: $MLNAME@$DOMAIN Serial" $TMPMAIL.body`
#NOLOOP=`grep -c "^From: MAILER-DAEMON@" $TMPMAIL.body`
if [ "$NOLOOP" -gt "1" ]; then
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
	rm -f $TMPMAIL $TMPMAIL.header $TMPMAIL.body
	logger -p mail.info -t MailList "$MID: $0 said: drop loop mail at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
#��ȡ�ʼ��Ƿ���շǱ��������ʼ�
PUB=`cat $MLDATADIR/$DOMAIN/$MLNAME/public`
#����ʼ��Ƿ��Ǳ���������
#�ж�������շǱ������ʼ��ı�־Ϊ0��ֱ����������
#ͬʱ�������ʼ��б�
FROM=`grep '^From: ' $TMPMAIL.header`
ALLOWDOMAIN=`cat $MLDATADIR/$DOMAIN/$MLNAME/allowdomain $MLDATADIR/$DOMAIN/ml_conf/allowdomain | tr -s "\n" "|" | sed 's/\|$//'`
PUBOK=`echo $FROM | egrep -o $ALLOWDOMAIN`
if [ "$PUBOK" = "" ] && [ "$PUB" = "0" ]; then
	logger -p mail.info -t MailList "$MID: Target domain not match $PUBOK"
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
	mv $TMPMAIL $MLDATADIR/$DOMAIN/$MLNAME/dropmail/
	rm -f $TMPMAIL.header $TMPMAIL.body
	logger -p mail.info -t MailList "$MID: $0 said: drop Internet mail at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
echo `expr $NUM + 1` > $MLDATADIR/$DOMAIN/$MLNAME/number
#�����ʼ��б�
rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
#��ȡ�Ƿ���ʼ���������ʼ����
CHSUB=`cat $MLDATADIR/$DOMAIN/$MLNAME/chsub`
#�����Ǵ����ʼ�ͷ��û��������ʼ��б������滻�ʼ�����
NOCHSUB=`grep -c "^Maillist: " $TMPMAIL.header`
if [ "$CHSUB" = "1" ] && [ "$NOCHSUB" -lt "1" ]; then
	sed -i '' "s/: \[${MLNAME}:\(.*\)\] /: /" $TMPMAIL.header
	sed -i '' "s/^Subject: /&\[$MLNAME:$SUBTIME-$NUM\] /" $TMPMAIL.header
fi
#���ʼ������ʼ��б���
sed -i '' "/^Message-ID:/Ii\\
Maillist: $MLNAME@$DOMAIN Serial\[$SUBTIME-$NUM\] $TIME\\
" $TMPMAIL.header
#��������ʼ���ɾ�����˵��ʼ�
cat $TMPMAIL.header $TMPMAIL.body > $TMPMAIL
rm -f $TMPMAIL.header $TMPMAIL.body
#�����ʼ�
cat $TMPMAIL | sendmail -f $MLNAME@$DOMAIN $TO
#��ȡ�ʼ��Ƿ���Ҫ���ݵ�״̬
ARCHIVE=`cat $MLDATADIR/$DOMAIN/$MLNAME/archive`
#������ݱ�־���򱸷��ʼ�            
if [ "$ARCHIVE" = "1" ]; then
	mv $TMPMAIL $MLDATADIR/$DOMAIN/$MLNAME/archived/
else
	#ɾ����ʱ�ʼ�
	rm -f $TMPMAIL
fi
logger -p mail.info -t MailList "$MID: $0 said: ok at $MLNAME@$DOMAIN[$NUM]."

