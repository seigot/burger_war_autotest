#!/bin/bash -x

cd $HOME/catkin_ws/src/burger_war_kit
CATKIN_WS_DIR=$HOME/catkin_ws
BURGER_WAR_KIT_REPOSITORY=$HOME/catkin_ws/src/burger_war_kit
BURGER_WAR_DEV_REPOSITORY=$HOME/catkin_ws/src/burger_war_dev
BURGER_WAR_AUTOTEST_LOG_REPOSITORY=$HOME/catkin_ws/src/burger_war_autotest
RESULTLOG=$BURGER_WAR_KIT_REPOSITORY/autotest/result.log
SRC_LOG=$RESULTLOG
TODAY=`date +"%Y%m%d"`
DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-${TODAY}.log
LATEST_GITLOG_HASH="xxxx"
LATEST_GITLOG_HASH_TXT="latest_gitlog_hash.txt"

LOOP_TIMES=100000

function do_game(){
    ITERATION=$1
    ENEMY_LEVEL=$2
    GAME_TIME=$3
    MY_SIDE=$4 # myside parameter currently doesn't work..
    if [ -z $MY_SIDE ]; then
	MY_SIDE="r"
    fi

    # change directory
    pushd ${BURGER_WAR_KIT_REPOSITORY}

    # start
    gnome-terminal -- bash scripts/sim_with_judge.sh # -s ${MY_SIDE}
    sleep 30
    gnome-terminal -- bash scripts/start.sh -l ${ENEMY_LEVEL} # -s ${MY_SIDE}

    # wait game finish
    sleep $GAME_TIME

    # get result
    timeout 30s python autotest/get_score.py > out.log
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

    # output result
    ## result log name
    pushd ${BURGER_WAR_DEV_REPOSITORY}
    USER_NAME=`git remote -v | head -1 | cut -d/ -f 4`
    BRANCH_NAME=`git branch | cut -d' ' -f2`
    popd
    RESULTLOG=$BURGER_WAR_KIT_REPOSITORY/autotest/result-${USER_NAME}-${BRANCH_NAME}.log

    ## output
    echo "$ITERATION, $ENEMY_LEVEL, $GAME_TIME, $DATE, $MY_SCORE, $ENEMY_SCORE, $BATTLE_RESULT, $MY_SIDE" >> $RESULTLOG
    tail -1 $RESULTLOG
    
    # stop
    # wait stop until all process is end
    bash scripts/stop.sh -s true
    sleep 10

    popd
}

function do_catkin_build(){

    # catkin build
    pushd $CATKIN_WS_DIR
    catkin clean -y
    catkin build
    source $HOME/.bashrc
    source ~/catkin_ws/devel/setup.bash
    popd
}

function check_latest_hash(){

    pushd $BURGER_WAR_KIT_REPOSITORY
    git pull
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    popd

    # check latest hash
    pushd $BURGER_WAR_DEV_REPOSITORY
    git pull
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    LATEST_GITLOG_HASH=`cat $LATEST_GITLOG_HASH_TXT`
    if [ -z "${LATEST_GITLOG_HASH}" ]; then
	LATEST_GITLOG_HASH="xxx"
    fi 
    if [ "$GITLOG_HASH" != "$LATEST_GITLOG_HASH" ];then
	TODAY=`date +"%Y%m%d%I%M%S"`
	## result log name
	pushd ${BURGER_WAR_DEV_REPOSITORY}
	USER_NAME=`git remote -v | head -1 | cut -d/ -f 4`
	BRANCH_NAME=`git branch | cut -d' ' -f2`
	popd
	RESULTLOG=$BURGER_WAR_KIT_REPOSITORY/autotest/result-${USER_NAME}-${BRANCH_NAME}.log
	## update result log
	if [ ! -e ${RESULTLOG} ]; then
	    echo "iteration, enemy_level, game_time(s), date, my_score, enemy_score, battle_result, my_side" > ${RESULTLOG}
	fi
	echo "#--> latest commit:${GITLOG_HASH} ${TODAY} in burger_war_dev" >> ${RESULTLOG}
	echo ${GITLOG_HASH} > ${LATEST_GITLOG_HASH_TXT}
	do_catkin_build
    fi
    popd
}

function do_result_analyzer(){
    INPUTFILE=$1
    OUTPUTFILE=$2
    ANALYZE_FILE_NAME="result_tmp.log"

    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY
    # preprocess
    LATEST_COMMIT_STR=`cat ${INPUTFILE} | grep "latest commit" | tail -1`             # get string
    LATEST_COMMIT_LINE_N=`grep "$LATEST_COMMIT_STR" -n ${INPUTFILE} | cut -d':' -f 1` # get line from string
    tail +${LATEST_COMMIT_LINE_N} ${INPUTFILE} > $ANALYZE_FILE_NAME                                 # get file from line
    # analyze
    python result_analyzer.py > ${OUTPUTFILE}                                         # get analyze matrix
    popd
}

function do_push(){

    pushd ${BURGER_WAR_DEV_REPOSITORY}
    USER_NAME=`git remote -v | head -1 | cut -d/ -f 4`
    BRANCH_NAME=`git branch | cut -d' ' -f2`
    popd

    SRC_LOG=$BURGER_WAR_KIT_REPOSITORY/autotest/result-${USER_NAME}-${BRANCH_NAME}.log
    DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-${USER_NAME}-${BRANCH_NAME}-${TODAY}.log

    # result log push
    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result
    git pull
    cp $SRC_LOG $DST_LOG
    git add $DST_LOG
    git commit -m "result.log update"
    git push
    popd

    # result analyze push
    RESULT_ANALYZER_DIR=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result_analyzer
    mkdir -p $RESULT_ANALYZER_DIR
    pushd $RESULT_ANALYZER_DIR
    TARGET_HASH_ID=`cat ${SRC_LOG} | grep "latest commit" | tail -1 | cut -d':' -f2 | cut -d' ' -f1`
    TODAY=`cat ${SRC_LOG} | grep "latest commit" | tail -1 | cut -d':' -f2 | cut -d' ' -f2`
    RESULT_ANALYZE_DST_LOG=result_analyzer-${USER_NAME}-${BRANCH_NAME}-${TODAY}-${TARGET_HASH_ID}.log
    do_result_analyzer $SRC_LOG ${RESULT_ANALYZER_DIR}/${RESULT_ANALYZE_DST_LOG}
    git add $RESULT_ANALYZE_DST_LOG
    git commit -m "result_analyzer.log update"
    git push
    popd
}

function prepare_user_directory(){

    local UNAME=${1}
    local CURRENT_UNAME=`echo ${UNAME} | cut -d@ -f1`
    local CURRENT_BRANCH=`echo ${UNAME} | cut -d@ -f2`
    TMP_BURGER_WAR_DEV_DIRECTORY=${HOME}/tmp/burger_war_dev

    cd ~
    # save current directory
    if [ -d ${BURGER_WAR_DEV_REPOSITORY} ]; then
	pushd ${BURGER_WAR_DEV_REPOSITORY}
	OLD_USER_NAME=`git remote -v | head -1 | cut -d/ -f 4`
	OLD_BRANCH_NAME=`git branch | cut -d' ' -f2`
	TMP_DIRECTORY="${TMP_BURGER_WAR_DEV_DIRECTORY}.${OLD_USER_NAME}.${OLD_BRANCH_NAME}"
	popd
	mv ${BURGER_WAR_DEV_REPOSITORY} ${TMP_DIRECTORY}
    fi

    TMP_DIRECTORY="${TMP_BURGER_WAR_DEV_DIRECTORY}.${CURRENT_UNAME}.${CURRENT_BRANCH}"
    if [ -d ${TMP_DIRECTORY} ]; then
	mv ${TMP_DIRECTORY} ${BURGER_WAR_DEV_REPOSITORY}
    else
	cd ${CATKIN_WS_DIR}/src
	echo "git clone https://github.com/${CURRENT_UNAME}/burger_war_dev -b ${CURRENT_BRANCH}"
	git clone https://github.com/${CURRENT_UNAME}/burger_war_dev -b ${CURRENT_BRANCH}
    fi
    do_catkin_build
}

UNAME=( # uname@branch
    KoutaOhishi@develop
    KoutaOhishi@main
    #seigot
)

# main loop
for ((i=0; i<${LOOP_TIMES}; i++));
do
    for uname in "${UNAME[@]}"
    do
	prepare_user_directory ${uname}
	check_latest_hash
	do_game ${i} 1 240 # 180 * 5/4 
	do_game ${i} 2 240 # 180 * 5/4 
	do_game ${i} 3 240 # 180 * 5/4
	#do_game ${i} 1 240 "b" # 180 * 5/4 # only enemy level1,2,3 works r side
	#do_game ${i} 2 240 "b" # 180 * 5/4 # 
	#do_game ${i} 3 240 "b" # 180 * 5/4 # 
	do_game ${i} 4 240 # 180 * 5/4
	do_game ${i} 5 240 # 180 * 5/4
	do_game ${i} 6 240 # 180 * 5/4
	do_game ${i} 7 240 # 180 * 5/4
	do_game ${i} 8 240 # 180 * 5/4
	do_game ${i} 9 240 # 180 * 5/4
	do_game ${i} 10 240 # 180 * 5/4
	do_game ${i} 11 240 # 180 * 5/4
	do_game ${i} 12 240 # 180 * 5/4
	do_push
    done
done
