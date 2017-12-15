#!/bin/bash

# this script sync changed files to server

username="username"
hostname="remote.example.com"
remote_war_path="/opt/IBM/WebSphere/AppServer/profiles/AppSrv01/installedApps/localhostNode01Cell/example.ear/example.war"

revision_from="$1"
revision_to="$2"
summarize_file="/tmp/sync_to_server.$1-$2"

svn diff -r $1:$2 --summarize  > $summarize_file

# https://www.ibm.com/developerworks/community/blogs/IBMzOS/entry/20150502?lang=en
# use ssh master mode. so later scp resue the ssh conection.
ssh -M -N -f ${username}@${hostname}

function copy_jsp {
    local local_file=$1
    # rm begining WebRoot
    local remote_file=${local_file#*WebRoot}
    scp  $local_file ${username}@${hostname}:${remote_war_path}$remote_file
}

function copy_java {
    local local_file=$1
    local_file=${local_file/.java/.class}
    local_file=${local_file#*src}
    # rm begining src
    local remote_file="/WEB-INF/classes"${local_file#*src}
    scp  build/classes$local_file ${username}@${hostname}:${remote_war_path}$remote_file
}

function copy_xml {
    local local_file=$1
    if [[ $local_file == "WebRoot/"* ]]; then
        remote_file=${local_file#*WebRoot}
    elif [[ $local_file == "src/"* ]]; then
        local_file=${local_file#*src}
        # rm begining WebRoot
        remote_file="/WEB-INF/classes"${local_file#*src}
    fi
    scp  build/classes$local_file ${username}@${hostname}:${remote_war_path}$remote_file
}

function process_line {
    local line=$1
    local action=`echo $line | awk '{print $1}'`
    local path=`echo $line | awk '{print $2}'`

    if [[ $action == "M" ]] || [[ $action == "A" ]]; then
        if [[ ${path} == *.jsp ]]; then
            copy_jsp ${path}
        elif [[ ${path} == *.java ]]; then
            copy_java ${path}
        elif [[ ${path} == *.xml ]]; then
            copy_xml ${path}
        else
            echo "SKIP $path"
        fi
    else
        echo "TODO action==$action"
    fi
}

while read LINE
do
      process_line "${LINE}"
done  < ${summarize_file}

ssh -o ControlMaster=no ${username}@${hostname} -O exit