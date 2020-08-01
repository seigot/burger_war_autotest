
#!/bin/bash

BURGER_WAR_REPOSITORY=$HOME/catkin_ws/src/burger_war
BURGER_WAR_AUTOTEST_LOG_REPOSITORY=$HOME/catkin_ws/src/burger_war_autotest
SRC_LOG=$BURGER_WAR_REPOSITORY/autotest/result.log
DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-20200801.log
LATEST_GITLOG_HASH=""

function check_latest_hash(){
    # check latest hash
    pushd $BURGER_WAR_REPOSITORY
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    if [ $GITLOG_HASH -ne $LATEST_GITLOG_HASH ];then
	echo $GITLOG_HASH
	LATEST_GITLOG_HASH=$GITLOG_HASH
    fi
    popd
}

function do_push(){

    # push
    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result
    cp $SRC_LOG $DST_LOG
    git add $DST_LOG
    git commit -m "result.log update"
    git push
    popd
}

LOOP_TIMES=200
for ((i=0; i<${LOOP_TIMES}; i++));
do
    check_latest_hash
    do_push
    sleep 300
done
