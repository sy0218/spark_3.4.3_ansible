#!/bin/bash

system_file="/data/work/system_download.txt"
work_dir=$1
SPARK_LOG_DIR=$(grep -i ".*spark.eventLog.dir.*" "/data/work/system_download.txt" | awk -F '|' '{print $2}')
ip_array=($(grep spark_ip ${system_file} | awk -F '|' '{for(i=2; i<=NF; i++) print $i}'))
len_ip_array=${#ip_array[@]}

echo $SPARK_LOG_DIR
# cp 함수
copy_functions() {
	local template_type=$1
	local now_ip=$2
	template=$(ssh ${now_ip} "find ${work_dir}/spark/conf -name ${template_type} -type f")
	cp_file_name=${template%.template}

	ssh "${now_ip}" "[ ! -f ${cp_file_name} ]" && ssh "${now_ip}" "cp $template $cp_file_name"	
}


setup_functions() {
    local setup_file_name=$1
    local remote_ip=$2

    # 원격 서버에서 실행할 명령어를 정의합니다.
    local command=$(cat <<EOF
    
setup_config=\$(awk "/\[${setup_file_name}-start\]/{flag=1; next} /\[${setup_file_name}-end\]/{flag=0} flag" ${system_file})
file_name=\$(find ${work_dir}/spark/conf -type f -name $(echo $setup_file_name | awk -F ':' '{print $1}'))

while IFS= read -r setup_config_low; do
    env_name=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$1}' | sed 's/[][]//g')
    env_value=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$2}')
    if grep -q "\${env_name}" "\${file_name}"; then
        sed -i "s|.*\${env_name}.*|\${env_name}\${env_value}|" "\${file_name}"
    else
        echo "\${env_name}\${env_value}" >> "\${file_name}"
    fi
done <<< "\${setup_config}"
EOF
    )

    # 원격 서버에서 명령어 실행
    ssh "${remote_ip}" "bash -s" <<< "$command"
}

setup_space_functions() {
    local setup_file_name=$1
    local remote_ip=$2

    # 원격 서버에서 실행할 명령어를 정의합니다.
    local command=$(cat <<EOF
setup_config=\$(awk "/\[${setup_file_name}-start\]/{flag=1; next} /\[${setup_file_name}-end\]/{flag=0} flag" ${system_file})
file_name=\$(find ${work_dir}/spark/conf -type f -name ${setup_file_name})

while IFS= read -r setup_config_low; do
    env_name=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$1}' | sed 's/[][]//g')
    env_value=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$2}')
    if grep -q "\${env_name}" "\${file_name}"; then
        sed -i "s|.*\${env_name}.*|\${env_name}     \${env_value}|" "\${file_name}"
    else
        echo "\${env_name}     \${env_value}" >> "\${file_name}"
    fi
done <<< "\${setup_config}"
EOF
    )

    # 원격 서버에서 명령어 실행
    ssh "${remote_ip}" "bash -s" <<< "$command"
}



for ((i=0; i<len_ip_array; i++)); do
        current_ip=${ip_array[$i]}
	echo $current_ip

	copy_functions "*spark-env*template" "${current_ip}"
	copy_functions "*spark-defaults*template" "${current_ip}"

	setup_functions "spark-env.sh" ${current_ip}
	setup_space_functions "spark-defaults.conf" ${current_ip}
	ssh ${current_ip} "mkdir -p ${SPARK_LOG_DIR} && chown -R $USER:$USER ${SPARK_HOME}" # 스파크 로그 디렉토리 생성
	
	ssh ${current_ip} "touch ${work_dir}/spark/conf/workers" # 워커 파일 생성
	setup_functions "workers:spark" ${current_ip}

	ssh ${current_ip} "pip install pyspark" # pyspark 설치
done
