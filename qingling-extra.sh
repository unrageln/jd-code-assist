#!/usr/bin/env bash

ShellDir=${QL_DIR:-$(

	cd $(dirname $0)

	pwd

)}

[[ $QL_DIR ]] && ShellJs=js

ConfigDir=$ShellDir/config

ListCronCurrent=$ConfigDir/crontab.list

AuthConf=$ConfigDir/auth.json

declare -A BlackListDict

author='monk-coder'

repo='dust'

path='i-chenzhe|normal|car|member'

blackword=''

gitpullstatus=0

diyscriptsdir=/ql/diyscripts

function monkcoder() {

	apk add --no-cache --upgrade grep

	mkdir -p ${diyscriptsdir}/${author}_${repo}

	cd ${diyscriptsdir}/${author}_${repo}

	i=1

	while [ "$i" -le 5 ]; do

		folders="$(curl -sX POST "https://share.r2ray.com/dust/" | grep -oP "name.*?\.folder" | cut -d, -f1 | cut -d\" -f3 | grep -vE "backup|pics|rewrite" | tr "\n" " ")"

		test -n "$folders" && {

			rm -rf ${diyscriptsdir}/${author}_${repo}

			break

		} || {

			echo 第 $i/5 次目录列表获取失败

			i=$((i + 1))

		}

	done

   if [ "$i" -eq 5 ];then gitpullstatus=$((gitpullstatus + 1));fi

	for folder in $folders; do

		i=1

		while [ "$i" -le 5 ]; do

			jsnames="$(curl -sX POST "https://share.r2ray.com/dust/${folder}/" | grep -oP "name.*?\.js\"" | grep -oE "[^\"]*\.js\"" | cut -d\" -f1 | tr "\n" " ")"

			test -n "$jsnames" && break || {

				echo 第 $i/5 次 $folder 目录下文件列表获取失败

				i=$((i + 1))

			}

		done

		if [ "$i" -eq 5 ];then gitpullstatus=$((gitpullstatus + 1));continue;fi

		mkdir -p ${diyscriptsdir}/${author}_${repo}/$folder

		cd ${diyscriptsdir}/${author}_${repo}/$folder

		for jsname in $jsnames; do

			i=1

			while [ "$i" -le 5 ]; do

				curl -so ${jsname} "https://share.r2ray.com/dust/${folder}/${jsname}"

				test "$(wc -c <"${jsname}")" -ge 1000 && break || {

					echo 第 $i/5 次 $folder 目录下 $jsname 文件下载失败

					i=$((i + 1))

				}

			done

        if [ "$i" -eq 5 ];then gitpullstatus=$((gitpullstatus + 1));continue;fi    

			echo $folder/$jsname文件下载成功

		done

	done

}

rand() {

	min=$1

	max=$(($2 - $min + 1))

	num=$(cat /proc/sys/kernel/random/uuid | cksum | awk -F ' ' '{print $1}')

	echo $(($num % $max + $min))

}

addnewcron() {

	addname=""

	cd ${diyscriptsdir}/${author}_${repo}

	express=$(find . -name "*.js")

	if [ $path ]; then

		express=$(find . -name "*.js" | egrep $path)

	fi

	if [ $blackword ]; then

		express=$(find . -name "*.js" | egrep -v $blackword | egrep $path)

	fi

	for js in $express; do

		base=$(basename $js)

		croname=$(echo "${author}_$base" | awk -F\. '{print $1}')

		script_date=$(cat $js | grep ^[0-9] | awk '{print $1,$2,$3,$4,$5}' | egrep -v "[a-zA-Z]|:|\." | sort | uniq | head -n 1)

		[ -z "${script_date}" ] && script_date=$(cat $js | grep -Eo "([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9][,-].*)" | sort | uniq | head -n 1)

		[ -z "${script_date}" ] && cron_min=$(rand 1 59) && cron_hour=$(rand 7 9) && script_date="${cron_min} ${cron_hour} * * *"

		local oldCron=$(grep -c -w "$croname" "$ListCronCurrent")

		if [[ oldCron -eq 0 ]]; then

			local name=$(cat "$js" | grep -E "new Env\(" | perl -pe "s|(^.+)new Env\(\'*\"*(.+?)'*\"*\).+|\2|")

			add_cron_api "$script_date" "js $croname" "$name"

			addname="${addname}\n${croname}"

			echo -e "添加了新的脚本${croname}."

		fi

		if [ ! -f "/ql/scripts/${author}_$base" ]; then

			\cp $js /ql/scripts/${author}_$base

		else

			change=$(diff $js /ql/scripts/${author}_$base)

			[ -n "${change}" ] && \cp $js /ql/scripts/${author}_$base && echo -e "${author}_$base 脚本更新了."

		fi

	done

	[ "$addname" != "" ] && notify "新增 ${author} 自定义脚本" "${addname}"

}

delcron() {

	delname=""

	cronfiles=$(grep "$author" /ql/config/crontab.list | grep -v "^#" | perl -pe "s|.*ID=(.*) js (${author}_.*)\.*|\1:\2|")

	for filename in $cronfiles; do

		local id=$(echo "$1" | awk -F ":" '{print $1}')

		local name=$(echo "$1" | awk -F ":" '{print $2}')

		hasFile=$(cd ${diyscriptsdir}/${author}_${repo} && find . -name "$filename.js" | wc -l)

		if [[ $hasFile != 0 ]]; then

			del_cron_api "$id"

			echo -e "删除失效脚本${name}."

			delname="${delname}\n${author}_${filename}"

		fi

	done

	[ "$delname" != "" ] && notify "删除 ${author} 失效脚本" "${delname}"

}

. $ShellDir/shell/api.sh

get_token

monkcoder

if [[ ${gitpullstatus} -eq 0 ]]; then

	addnewcron

	delcron

else

	echo -e "$author 仓库更新失败了."

	notify "自定义仓库更新失败" "$author"

fi

exit 0

