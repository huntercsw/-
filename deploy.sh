#!/bin/bash

# Node list
NODE_LIST="192.168.0.30 192.168.0.40"

# Shell enviroment variables
SHELL_NAME="deploy.sh"
SHELL_DIR="/home/www/"
SHELL_LOG="${SHELL_DIR}/${SHELL_NAME}.log"
CURRENT_DATA=$(date "+%Y-%m-%d")
CURRENT_TIME=$(date "+%H-%M-%S")
CURRENT_USER=$(whoami)

# Code enviroment variables
PROJECT_NAME="web"
CODE_DIR="/deploy/code/web"
CONFIG_DIR="/deploy/config/web"
TAR_DIR="/deploy/tar"
TMP_DIR="/deploy/tmp"

# Lock file
# 确保该部署进程不能被多人调用
LOCK_FILE="/tmp/deploy.lock"

function add_progress_lock(){
    touch ${LOCK_FILE}
}
function release_progress_lock(){
    rm -f ${LOCK_FILE}
}

# log setting
function write_log(){
    LOG_INFO=$1
    echo "${CURRENT_DATA}/${CURRENT_TIME} : ${SHELL_NAME} : ${CURRENT_USER}: ${LOG_INFO}" >> ${SHELL_LOG}
}


function choose_deploy_method(){
    echo $"Usage: $0 [deploy | rollback]"
}

function code_get(){
    write_log "get code"
    cd ${CODE_DIR} && echo "git pull"
    cp -r ${CODE_DIR} ${TMP_DIR}/
}

function code_compile(){
    echo code_compile
}

function code_config(){
    write_log "upload config file"
    PROJECT_VERSION=1.0.0
    /bin/cp -r ${CONFIG_DIR}/base/* ${TMP_DIR}/${PROJECT_NAME}/
    PKG_NAME="${PROJECT_NAME}"_"${PROJECT_VERSION}"_"${CURRENT_DATA}-${CURRENT_TIME}"
    cd ${TMP_DIR} && mv ${PROJECT_NAME} ${PKG_NAME}
}

function code_tar(){
    write_log "make project package : ${PKG_NAME}"
    cd ${TMP_DIR} && tar czf ${PKG_NAME}.tar.gz ${PKG_NAME}
}

function code_upload(){
    for node in $NODE_LIST;do
        scp ${TMP_DIR}/${PKG_NAME}.tar.gz $node:/opt/webroot/
        write_log "upload project package to ${node}"
    done
}

function remove_node_from_cluster(){
    write_log "remove node from cluster"
}

function code_unconpress(){
    for node in $NODE_LIST;do
        ssh $node "cd /opt/webroot && tar -xf ${PKG_NAME}.tar.gz"
    done
}

function scp_special_configuration_to_special_node(){
    write_log "scp special configuration to special node"
    scp ${CONFIG_DIR}/other/special.conf 192.168.0.30:/opt/webroot/${PKG_NAME}/
}

function code_deploy(){
# the core of deploy automatically is ***creare soft link of project packackage to base dir***
# if you need rollback, just delete old soft link and create a new soft link to project package which version is needed
# 自动化部署的精髓就是创建一个项目包的软连接指向nginx的root目录下面，这样在回滚的时候效率十分高且简单。（仅需删除原来的软连接，重新建立新的软连接即可）
# 部署的时候一般会对主机进行分组，一组一组部署
    for node in ${NODE_LIST};do
        ssh $node "rm -f /webroot/web && ln -s /opt/webroot/${PKG_NAME} /webroot/web"
    done
}

function code_test(){
# 每部署完一组后，需要进行测试，url为该组的url列表
    PREVIOUS_PRODUCT_URL="http://x.x.x.x:xx"
    curl -s --head ${PREVIOUS_PRODUCT_URL} | grep "200 OK"
    if [ $? -ne 0 ];then
        if [ -f ${LOCK_FILE} ];then
            release_progress_lock;
        fi
        write_log "${PREVIOUS_PRODUCT_URL} test error"
        echo "PREVIOUS_PRODUCE_URL Test error" && exit
    fi
}

function add_node_to_cluster(){
    echo add_node_to_cluster
}

function rollback(){
    if [ -z $1 ];then
        release_progress_lock;
        echo "param error" && exit
    fi

    ROLLBACK_TO=$1
    ROLLBACK_NODE_LIST="192.168.0.30 192.168.0.40"
    
    case ${ROLLBACK_TO} in
        list)
            ls -l /opt/webroot/*.tar.gz
        ;;
        *)
            for node in ROLLBACK_NODE_LIST;do
                 ssh ${node} "if [ -d /opt/webroot/${ROLLBACK_TO} ];then rm -f /webroot/web && ln-s /opt/webroot/${ROLLBACK_TO} /webroot/web;else echo "${node} no ${ROLLBACK_TO}" fi"
            done
    esac

}

function main(){
    # set a lock file , makesure only one deploy process is running at the same time
    if [ -f ${LOCK_FILE} ];then
        echo "Deploy is running" && exit;
    fi

    DEPLOY_METHOD=$1
    ROLLBACK_VERSION=$2
    case $DEPLOY_METHOD in
        deploy)
                add_progress_lock;
                code_get;
                code_compile;
                code_config;
                code_tar;
                code_upload;
                remove_node_from_cluster;
                code_unconpress;
                scp_special_configuration_to_special_node;
                code_deploy;
                code_test;
                add_node_to_cluster;
                ;;
        rollback)
                add_progress_lock;
                rollback ${ROLLBACK_VERSION};
                ;;
        *)
                choose_deploy_method;
    esac
}

main $1 $2
if [ -f ${LOCK_FILE} ];then
    release_progress_lock;
fi


