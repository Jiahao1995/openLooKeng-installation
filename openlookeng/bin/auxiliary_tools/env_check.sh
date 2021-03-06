##
 # Copyright (C) 2018-2020. Huawei Technologies Co., Ltd. All rights reserved.
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 ##
#!/bin/bash
declare architecture=x86
res=`arch|grep x86|wc -l`
if [[  $res > 0 ]]
then
    architecture=x86
else
    architecture=arrch64
fi
export resource_url=$wget_url/auto-install/third-resource/$architecture
export architecture
function check_sshpass()
{
    curl -IL $wget_url &> /dev/null
    offline=$?
    echo "[INFO] Checking sshpass installation..."
    ret_str=`sshpass |awk -F':' '{print $1}' |sed -n '1p'`
    if [[ "${ret_str}" == "Usage" ]]
    then
        echo "[INFO] sshpass is already installed."
        return 0
    fi
    echo "[INFO] Sshpass is not installed. Start to install it right now..."
    if [[ $offline == 0 ]]
    then
        curl -fsSL -o /opt/sshpass-1.06.tar.gz $resource_url/sshpass-1.06.tar.gz
        curl -fsSL -o /opt/sshpass-1.06-2.el7.x86_64.rpm $resource_url/sshpass-1.06-2.el7.x86_64.rpm
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz doesn't exit."
            return 1
        fi
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06.tar.gz ]]
        then
            echo "[ERROR] $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm doesn't exit."
            return 1
        fi
        cp $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm /opt
        cp $OPENLOOKENG_DEPENDENCIES_PATH/sshpass-1.06-2.el7.x86_64.rpm /opt
    fi
    gcc_str=`gcc -v 2>&1 |awk 'NR==1{ gsub(/"/,""); print $1 }'`
    if [[ "${gcc_str}" == "Using" ]] || [[ ! -f /opt/sshpass-1.06-2.el7.x86_64.rpm ]]
    then
        tar -zxvf /opt/sshpass-1.06.tar.gz>/dev/null 2>&1
        cd /opt/sshpass-1.06 >/dev/null 2>&1
        ./configure >/dev/null 2>&1
        make >/dev/null 2>&1
        make install >/dev/null 2>&1
        cd - >/dev/null 2>&1
    else
        rpm -ivh /opt/sshpass-1.06-2.el7.x86_64.rpm >/dev/null 2>&1
    fi
    ret_str=`sshpass |awk -F':' '{print $1}' |sed -n '1p'`
    if [[ "${ret_str}" == "Usage" ]]
    then
        echo  "[INFO] sshpass install successed"
    else
        echo "[ERROR] sshpass install failed"
        return 1
    fi

}

function java_check(){
    curl -IL $wget_url &> /dev/null
    offline=$?

    IFS=',' read -ra host_array <<< "${PASSLESS_NODES}"
    for ip in ${host_array[@]}
    do
        echo "[INFO] Check jdk installation on $ip..."
        if [[ "${ip}" =~ "${local_ips_array[@]}" ]] || [[ "${ip}" == "localhost" ]]
        then
            bash $OPENLOOKENG_BIN_THIRD_PATH/install_java.sh $offline $resource_url
        else
            . $OPENLOOKENG_BIN_THIRD_PATH/cpresource_remote.sh $ip $OPENLOOKENG_BIN_THIRD_PATH/install_java.sh /opt
            . $OPENLOOKENG_BIN_THIRD_PATH/execute_remote.sh $ip "bash /opt/install_java.sh $offline $resource_url;rm -f /opt/install_java.sh;exit"
        fi
    done
}
function memory_check()
{
    if [[ $JVM_MEM -lt 4 ]]
    then
        echo "[ERROR] There is not enough memory for openLooKeng to install. OpenLooKeng requires more than 4GB JVM memory."
        return 1
    fi
}
function check_node_reacheable()
{
    if [[ ! -z $ALL_NODES ]]
    then
        IFS=',' read -ra host_array <<< "${ALL_NODES}"
        for ip in "${host_array[@]}"
        do
            if [[ ! " ${local_ips_array[@]} " =~ " ${ip} " ]];then
                ping -c3 -W3 ${ip}  >/dev/null 2>&1
                if [ $? -eq 0 ]
                then
                    echo "[INFO] The IP address: ${ip} can be reachable"
                else
                    echo "[ERROR] The IP address: ${ip} can not be reachable"
                    return 1
                fi
            fi
        done
    fi
}
function download_cli()
{
    curl -IL $wget_url &> /dev/null
    offline=$?
    if [[ ! -d $OPENLOOKENG_DEPENDENCIES_PATH ]]
    then
        mkdir -p $OPENLOOKENG_DEPENDENCIES_PATH
    fi
    if [[ $offline == 0 ]]
    then
        curl -fsSL -o $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar $wget_url/$openlk_version/hetu-cli-$openlk_version-executable.jar
        if [[ $? == 0 ]]
        then
            chmod u+x $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar
        else
            echo "[ERROR] DownLoad openLooKeng client failed."
            return 1
        fi
    else
        if [[ ! -f $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar ]]
        then
            echo "[ERROR] OpenLooKeng client didn't found."
            return 1
        else
            chmod u+x $OPENLOOKENG_DEPENDENCIES_PATH/hetu-cli-$openlk_version-executable.jar
        fi
    fi
}

function main()
{
    offline=$2
    if [[ $1 =~ "sshpass" ]]
    then
        check_sshpass
        return $?
    fi
    if [[ $1 =~ "java" ]]
    then
        java_check
        return $?
    fi
    if [[ $1 =~ "memory" ]]
    then
        memory_check
        return $?
    fi
    if [[ $1 =~ "reacheable" ]]
    then
        check_node_reacheable
        return $?
    fi

    if [[ $1 =~ "cli" ]]
    then
        download_cli
        return $?
    fi
}
main $@
