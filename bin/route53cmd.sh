#!/bin/bash

reouterip=""

arg_zone_id=""
arg_name=""
arg_ttl=0
arg_type=""
arg_value=""

current_name=""
current_ttl=0
current_type=""
current_value=""

function print_routerip() {
  curl ifconfig.me
}

function print_current_record(){
  local zone_id=$1
  local name=$2

  json=$(aws route53 list-resource-record-sets  --hosted-zone-id $zone_id --start-record-name  ${name} --max-items 1)

  record_name=$(echo "$json" | sed -n -e 's/^.*"Name": "\([^"]*\)".*$/\1/p')
  match=$(echo "$record_name" | sed -n -e "/${name}/p") 
  if [ "$match" = "" ] ; then
    echo "no record found for $name" >&2  
    return 1
  else
    echo $json
    return 0
  fi
}

function parse_record(){

  local zone_id=$1
  local json=$2

  current_name=$(echo "$json" | sed -n -e 's/^.*"Name": "\([^"]*\)".*$/\1/p')
  if [ "$current_name" = "" ] ; then
    echo "no Name found" >&2
  else
    echo "current name=${current_name}"
  fi

  current_value=$(echo "$json" | sed -n -e 's/^.*"Value": "\([^"]*\)".*$/\1/p')
  if [ "${current_value}" = "" ] ; then
    echo "no Value found" >&2
  else
    echo "current value=${current_value}"
  fi

  current_type=$(echo "$json" | sed -n -e 's/^.*"Type": "\([^"]*\)".*$/\1/p')
  if [ "${current_type}" = "" ] ; then
    echo "no Type found" >&2
  else
    echo "current type=${current_type}"
  fi

  current_ttl=$(echo "$json" | sed -n -e 's/^.*"TTL": \([0-9]*\).*$/\1/p')
  if [ "${current_ttl}" = "" ] ; then
    echo "no TTL found" >&2
  else
    echo "current ttl=${current_ttl}"
  fi

}

function print_DELETE(){

local new_type=$1
local new_value=$2 

read -d '' record << EOF
    {
      "Action": "DELETE",
      "ResourceRecordSet":
      {
        "Name": "${current_name}",
        "Type": "${current_type}",
        "TTL": ${current_ttl},
        "ResourceRecords":[
          {
	    "Value": "${current_value}"
	  }
        ]
      }
    }
EOF

echo $record

}

function print_1_CHANGES(){

read -d '' record << EOF
{
  "Changes":
  [
    $1
  ]
}
EOF

echo $record

}


function print_2_CHANGES(){

read -d '' record << EOF
{
  "Changes":
  [
    $1
    ,
    $2
  ]
}
EOF

echo $record

}

function print_CREATE(){

local new_name=$1
local new_type=$2
local new_ttl=$3 
local new_value=$4

read -d '' record << EOF
    {
      "Action": "CREATE",
      "ResourceRecordSet":
      {
        "Name": "${new_name}",
        "Type": "${new_type}",
        "TTL": ${new_ttl},
        "ResourceRecords":[
          {
	    "Value": "${new_value}"
	  }
        ]
      }
    }
EOF

echo $record

}


function main(){
  local change_batch_filepath=$(tempfile)

  local recordjson=$(print_current_record ${arg_zone_id} ${arg_name})
  parse_record ${arg_zone_id} "$recordjson"
  if [ "$current_name" = "" ] ; then
    print_1_CHANGES \
    "$(print_CREATE ${arg_name} $arg_type $arg_ttl ${arg_value})" > \
    $change_batch_filepath
  else
    print_2_CHANGES "$(print_DELETE)" \
    "$(print_CREATE $current_name $arg_type $arg_ttl ${arg_value})" > \
    $change_batch_filepath
  fi

  aws route53 change-resource-record-sets \
  --hosted-zone-id $arg_zone_id --change-batch \
  file://$change_batch_filepath

  rm $change_batch_filepath

}

function get_user_input() {

  local next_is_zone_id=0
  local next_is_name=0
  local next_is_value=0
  local next_is_ttl=0
  local next_is_type=0

  for el in $@; do
    if [[ "$el" == "-z" || "$el" == "--zone-id" ]]; then
      next_is_zone_id=1
    elif [[ "$el" == "-n" || "$el" == "--name" ]]; then
      next_is_name=1
    elif [[ "$el" == "-v" || "$el" == "--value" ]]; then
      next_is_value=1
    elif [[ "$el" == "-t" || "$el" == "--type" ]]; then
      next_is_type=1
    elif [ "$el" = "--ttl" ]; then
      next_is_ttl=1
    elif [ $next_is_zone_id -eq 1 ]; then
      arg_zone_id=$el
      next_is_zone_id=0
    elif [ $next_is_name -eq 1 ]; then
      arg_name=$el
      next_is_name=0
    elif [ $next_is_type -eq 1 ]; then
      arg_type=$el
      next_is_type=0
    elif [ $next_is_ttl -eq 1 ]; then
      arg_ttl=$el
      next_is_ttl=0
    elif [ $next_is_value -eq 1 ]; then
      arg_value=$el
      next_is_value=0
    fi
  done

  local errors=0

  if [ "$arg_zone_id" = "" ] ; then
    echo "You must specify a zone id: [a-zA-Z0-9]{5,20}"
    echo "E.g.: $(basename $0) --base-id Z3DQNPKIXZKPS5"
    errors=1
  fi

  if [ "$arg_name" = "" ] ; then
    echo "You must specify a dns name: [a-zA-Z0-9\.]{1,250}"
    echo "E.g.: $(basename $0) --name yourname.yourdomain.com"
    errors=1
  fi

  if [ "$arg_type" = "" ]; then
    arg_type="A"
  fi

  if [ "$arg_ttl" = "0" ]; then
    arg_ttl=300
  fi

  if [ "$arg_value" = "" ] ; then
    echo "You must specify a value: {1,500}"
    echo "E.g.: $(basename $0) --value 10.10.10.10"
    errors=1
  fi


  if [ $errors -eq 1 ]; then
    exit
  fi
}

get_user_input $@
main

