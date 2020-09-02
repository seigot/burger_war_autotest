#!/bin/bash -x

cd $HOME/catkin_ws/src/burger_war

BURGER_WAR_REPOSITORY=$HOME/catkin_ws/src/burger_war
BURGER_WAR_AUTOTEST_LOG_REPOSITORY=$HOME/catkin_ws/src/burger_war_autotest
RESULTLOG=$BURGER_WAR_REPOSITORY/autotest/result.log
SRC_LOG=$RESULTLOG 
DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-20200830.log
LATEST_GITLOG_HASH="xxxx"

RESULT_LOG_HEADER_STR="iteration, enemy_level, game_time(s), date, my_score, enemy_score, battle_result, my_side"
echo ${RESULT_LOG_HEADER_STR} > $RESULTLOG

LOOP_TIMES=10000

function do_game(){
    ITERATION=$1
    ENEMY_LEVEL=$2
    GAME_TIME=$3
    MY_SIDE=$4
    if [ -z $MY_SIDE ]; then
	MY_SIDE="r"
    fi

    #start
    gnome-terminal -e "bash scripts/sim_with_judge.sh -s ${MY_SIDE}"
    sleep 30
    gnome-terminal -e "bash scripts/start.sh -l ${ENEMY_LEVEL} -s ${MY_SIDE}"

    #wait game finish
    sleep $GAME_TIME

    #get result
    timeout 30s python ~/catkin_ws/src/burger_war/autotest/get_score.py > out.log
    if [ $MY_SIDE == "r" ]; then
	MY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
	ENEMY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
    else
	# MY_SIDE != r, means mybot works enemy side..
	MY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
	ENEMY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
    fi
    DATE=`date --iso-8601=seconds`
    BATTLE_RESULT="LOSE"
    if [ $MY_SCORE -gt $ENEMY_SCORE ]; then
	BATTLE_RESULT="WIN"
    fi

    #output result
    echo "$ITERATION, $ENEMY_LEVEL, $GAME_TIME, $DATE, $MY_SCORE, $ENEMY_SCORE, $BATTLE_RESULT, $MY_SIDE" >> $RESULTLOG
    tail -1 $RESULTLOG
    
    #stop
    PROCESS_ID=`ps -e -o pid,cmd | grep start.sh | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep sim_with_judge.sh | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep judgeServer.py | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep visualizeWindow.py | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    sleep 30
}

function check_latest_hash(){
    # check latest hash
    pushd $BURGER_WAR_REPOSITORY
    git pull
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    if [ "$GITLOG_HASH" != "$LATEST_GITLOG_HASH" ];then
	echo "#--> latest commit:$GITLOG_HASH" >> $RESULTLOG
	LATEST_GITLOG_HASH=$GITLOG_HASH
    fi
    popd
}

function do_push(){

    # add result
    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result
    git pull
    cp $SRC_LOG $DST_LOG
    git add $DST_LOG

    # add analyzed result
    pushd $BURGER_WAR_REPOSITORY
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    popd
    RESULT_ANALYZER_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result_analyzer/result_analyzer_${GITLOG_HASH}.log
    local RESULT_TMP_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result_tmp.log
    echo ${RESULT_LOG_HEADER_STR} > ${RESULT_TMP_LOG}
    cat $DST_LOG | sed -n '/'$GITLOG_HASH'/,$p' > ${RESULT_TMP_LOG}
    python $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result_analyzer.py > ${RESULT_ANALYZER_LOG}
    rm {RESULT_TMP_LOG}
    git add ${RESULT_ANALYZER_LOG}

    # commit,push
    git commit -m "result.log update"
    git push

    #prepare
    bash prepare.sh
    popd
}

# main loop
for ((i=0; i<${LOOP_TIMES}; i++));
do
    check_latest_hash
    #do_game ${i} 1 225 # 180 * 5/4 
    #do_game ${i} 2 225 # 180 * 5/4 
    #do_game ${i} 3 225 # 180 * 5/4
    do_game ${i} 1 225 "b" # 180 * 5/4 # only enemy level1,2,3 works r side
    do_game ${i} 2 225 "b" # 180 * 5/4 # 
    do_game ${i} 3 225 "b" # 180 * 5/4 # 
    do_game ${i} 4 225 # 180 * 5/4
    do_game ${i} 5 225 # 180 * 5/4
    do_game ${i} 6 225 # 180 * 5/4
    do_game ${i} 7 225 # 180 * 5/4
    do_game ${i} 8 225 # 180 * 5/4
    do_push
done
