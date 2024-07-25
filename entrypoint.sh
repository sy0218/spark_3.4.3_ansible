#!/bin/bash

system_file="/data/work/system_download.txt"
work_dir=$1
ip_array=($(grep spark_ip ${system_file} | awk -F '|' '{for(i=2; i<=NF; i++) print $i}'))
len_ip_array=${#ip_array[@]}

# cp 함수
copy_functions() {
	local template_type=$1
	local now_ip=$2
	template=$(ssh ${now_ip} "find ${work_dir}/spark/conf -name ${template_type} -type f")
	cp_file_name=${template%.template}

	ssh "${now_ip}" "[ ! -f ${cp_file_name} ]" && ssh "${now_ip}" "cp $template $cp_file_name"	
}

# 설정파일 동적 setup 함수
#setup_functions() {
#	local setup_file_name=$1
#	local now_ip=$2
#	setup_config=$(awk "/\[${setup_file_name}-start\]/{flag=1; next} /\[${setup_file_name}-end\]/{flag=0} flag" ${system_file})
#	file_name=$(find ${work_dir} -type f -name spark-env.sh)
#	while IFS= read -r setup_config_low;
#        do
#		env_name=$(echo "${setup_config_low}" | awk -F '|' '{print $1}' | sed 's/[][]//g')
#		env_value=$(echo "${setup_config_low}" | awk -F '|' '{print $2}')
#
#                echo $env_name $env_value
#        done <<< $setup_config
#}

setup_functions() {
    local setup_file_name=$1
    local remote_ip=$2

    # 원격 서버에서 실행할 명령어를 정의합니다.
    local command=$(cat <<EOF
setup_config=\$(awk "/\[${setup_file_name}-start\]/{flag=1; next} /\[${setup_file_name}-end\]/{flag=0} flag" ${system_file})
file_name=\$(find ${work_dir} -type f -name spark-env.sh)

while IFS= read -r setup_config_low; do
    env_name=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$1}' | sed 's/[][]//g')
    env_value=\$(echo "\${setup_config_low}" | awk -F '|' '{print \$2}')
    echo \$env_name \$env_value
    echo \${env_name}\${env_value} >> \${file_name}
done <<< "\${setup_config}"
EOF
    )

    # 원격 서버에서 명령어 실행
    ssh "${remote_ip}" "bash -s" <<< "$command"
}


for ((i=0; i<len_ip_array; i++)); do
        current_ip=${ip_array[$i]}
	echo $current_ip

	#copy_functions "*spark-env*template" "${current_ip}"
	#copy_functions "*spark-defaults*template" "${current_ip}"
	#copy_functions "*workers*template" "${current_ip}"

	setup_functions "spark-env.sh" ${current_ip}
	break
done


#sed -i "s|.*${env_name}.*$|${env_name}${env_value}|" \${file_name}
