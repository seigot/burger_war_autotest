#!/bin/bash -x

cd ~/catkin_ws/src/burger_war

echo "iteration, enemy_level, game_time(s), date, my_score, enemy_score, battle_result" > result.log

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
    python ~/catkin_ws/src/burger_war_autotest/get_score.py > out.log
    MY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
    ENEMY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
    DATE=`date --iso-8601=seconds`
    BATTLE_RESULT="LOSE"
    if [ $MY_SCORE -gt $ENEMY_SCORE ]; then
	BATTLE_RESULT="WIN"
    fi

    #output result
    echo "$ITERATION, $ENEMY_LEVEL, $GAME_TIME, $DATE, $MY_SCORE, $ENEMY_SCORE, $BATTLE_RESULT" >> result.log
    tail -1  result.log
    
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

# main loop
for ((i=0; i<${LOOP_TIMES}; i++));
do
    do_game ${i} 1 225 # 180 * 5/4 
    do_game ${i} 2 225 # 180 * 5/4 
    do_game ${i} 3 225 # 180 * 5/4
done
