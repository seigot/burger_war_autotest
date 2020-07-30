#!/bin/bash -x

cd ~/catkin_ws/src/burger_war

function do_game(){
    GAME_TIME=$1

    #start
    gnome-terminal -e "bash scripts/sim_with_judge.sh"
    sleep 30
    gnome-terminal -e "bash scripts/start.sh"
    sleep $GAME_TIME

    #get result
    python ../burger_war_autotest/get_score.py > out.log
    MY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
    ENEMY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
    DATE=`date --iso-8601=seconds`

    echo "$DATE, $MY_SCORE, $ENEMY_SCORE"
    
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
do_game 30

