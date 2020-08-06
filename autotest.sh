#!/bin/bash -x

cd $HOME/catkin_ws/src/burger_war

BURGER_WAR_REPOSITORY=$HOME/catkin_ws/src/burger_war
BURGER_WAR_AUTOTEST_LOG_REPOSITORY=$HOME/catkin_ws/src/burger_war_autotest
RESULTLOG=$BURGER_WAR_REPOSITORY/autotest/result.log
SRC_LOG=$RESULTLOG 
DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-20200803.log
LATEST_GITLOG_HASH="xxxx"

echo "iteration, enemy_level, game_time(s), date, my_score, enemy_score, battle_result" > $RESULTLOG

LOOP_TIMES=1

function do_game(){
    ITERATION=$1
    ENEMY_LEVEL=$2
    GAME_TIME=$3

    #start
    gnome-terminal -e "bash scripts/sim_with_judge.sh"
    sleep 30
    gnome-terminal -e "bash scripts/start.sh -l ${ENEMY_LEVEL}"

    #wait game finish
    sleep $GAME_TIME

    #get result
    timeout 30s python ~/catkin_ws/src/burger_war/autotest/get_score.py > out.log
    MY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
    ENEMY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
    DATE=`date --iso-8601=seconds`
    BATTLE_RESULT="LOSE"
    if [ $MY_SCORE -gt $ENEMY_SCORE ]; then
	BATTLE_RESULT="WIN"
    fi

    #output result
    echo "$ITERATION, $ENEMY_LEVEL, $GAME_TIME, $DATE, $MY_SCORE, $ENEMY_SCORE, $BATTLE_RESULT" >> $RESULTLOG
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

    # push
    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result
    git pull
    cp $SRC_LOG $DST_LOG
    git add $DST_LOG
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
    do_game ${i} 1 225 # 180 * 5/4 
    do_game ${i} 2 225 # 180 * 5/4 
    do_game ${i} 3 225 # 180 * 5/4
    do_push
done
