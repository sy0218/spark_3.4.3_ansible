#!/bin/bash

system_file="/data/work/system_download.txt"
conf_dir=$1
work_dir=$2
ip_array=($(grep hadoop_ip ${system_file} | awk -F '|' '{for(i=2; i<=NF; i++) print $i}'))
len_ip_array=${#ip_array[@]}
hadoop_need_dir=($(grep need_dir ${system_file} | awk -F '|' '{for(i=2; i<=NF; i++) print $i}'))
len_need_dir=${#hadoop_need_dir[@]}

for core_config_low in $(awk '/\[core-site.xml-start\]/{flag=1; next} /\[core-site.xml-end\]/{flag=0} flag' ${system_file});
do
        file_name=$(find ${conf_dir} -type f -name *core-site.xml*)
        core_site_name=$(echo ${core_config_low} | awk -F '|' '{print $1}' | sed 's/[][]//g')
        core_site_value=$(echo ${core_config_low} | awk -F '|' '{print $2}')
        sed -i "/<name>${core_site_name}<\/name>/!b;n;c<value>${core_site_value}</value>" ${file_name}
done


for hdfs_site_config_low in $(awk '/\[hdfs-site.xml-start\]/{flag=1; next} /\[hdfs-site.xml-end\]/{flag=0} flag' ${system_file});
do
        file_name=$(find ${conf_dir} -type f -name *hdfs-site.xml*)
        hdfs_site_name=$(echo ${hdfs_site_config_low} | awk -F '|' '{print $1}' | sed 's/[][]//g')
        hdfs_site_value=$(echo ${hdfs_site_config_low} | awk -F '|' '{print $2}')
        sed -i "/<name>${hdfs_site_name}<\/name>/!b;n;c<value>${hdfs_site_value}</value>" ${file_name}
done


for mapred_site_config_low in $(awk '/\[mapred-site.xml-start\]/{flag=1; next} /\[mapred-site.xml-end\]/{flag=0} flag' ${system_file});
do
        file_name=$(find ${conf_dir} -type f -name *mapred-site.xml*)
        mapred_site_name=$(echo ${mapred_site_config_low} | awk -F '|' '{print $1}' | sed 's/[][]//g')
        mapred_site_value=$(echo ${mapred_site_config_low} | awk -F '|' '{print $2}')
        sed -i "/<name>${mapred_site_name}<\/name>/!b;n;c<value>${mapred_site_value}</value>" ${file_name}
done


for yarn_site_config_low in $(awk '/\[yarn-site.xml-start\]/{flag=1; next} /\[yarn-site.xml-end\]/{flag=0} flag' ${system_file});
do
        file_name=$(find ${conf_dir} -type f -name *yarn-site.xml*)
        yarn_site_name=$(echo ${yarn_site_config_low} | awk -F '|' '{print $1}' | sed 's/[][]//g')
        yarn_site_value=$(echo ${yarn_site_config_low} | awk -F '|' '{print $2}')
        sed -i "/<name>${yarn_site_name}<\/name>/!b;n;c<value>${yarn_site_value}</value>" ${file_name}
done


hadoop_env_config=$(awk '/\[hadoop-env.sh-start\]/{flag=1; next} /\[hadoop-env.sh-end\]/{flag=0} flag' ${system_file})
while IFS= read -r hadoop_env_config_low;
do
        file_name=$(find ${conf_dir} -type f -name *hadoop-env.sh*)
        hadoop_env_name=$(echo $hadoop_env_config_low | awk -F '|' '{print $1}' | sed 's/[][]//g')
        hadoop_env_value=$(echo $hadoop_env_config_low | awk -F '|' '{print $2}')
        sed -i "s|^${hadoop_env_name}.*$|${hadoop_env_name}${hadoop_env_value}|" ${file_name}
done <<< $hadoop_env_config


work_file_name=$(find ${conf_dir} -type f -name *workers*)
truncate -s 0 $work_file_name
for workers_low in $(awk '/\[workers-start\]/{flag=1; next} /\[workers-end\]/{flag=0} flag' ${system_file});
do
        echo $workers_low >> $work_file_name
done

# 하둡 서버 필요 디렉토리 생성
for ((i=0; i<len_ip_array; i++)); do
        current_ip=${ip_array[$i]}

        for ((j=0; j<len_need_dir; j++)); do
                current_dir=${hadoop_need_dir[$j]}
                echo "${current_ip} 서버 필요 디렉토리 삭제 후 생성 $current_dir"
                ssh ${current_ip} "rm -rf ${current_dir}"
                ssh ${current_ip} "mkdir -p ${current_dir}"
                done
done


# 동적 setup된 하둡 설정 관련 파일 하둡 클러스터에 scp
for cp_file in $(ls ${conf_dir});
do
        if [[ "$cp_file" != "entrypoint.sh" && "$cp_file" != "hadoop-3.3.5.tar.gz" && "$cp_file" != *.yml && "$cp_file" != *.ini ]]; then
                if [[ "$cp_file" == "fair-scheduler.xml" ]]; then
                        local_path=$(find ${work_dir}/*hadoop*/etc/hadoop -name hadoop -type d)
                else
                        local_path=$(find ${work_dir}/ -name ${cp_file} -type f ! -path "*/sample-conf/*")
                fi
        for ((i=0; i<len_ip_array; i++));
        do
                current_ip=${ip_array[$i]}
                scp ${conf_dir}/${cp_file} root@${current_ip}:${local_path}
        done
        fi
done
