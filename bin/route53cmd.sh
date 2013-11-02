#!/bin/bash

zone_id="Z3DQNPKIXZKPS5"
reouterip=""
record_name=""
record_ttl=300
record_type=""
record_value=""

function print_routerip() {
  curl ifconfig.me
}

function print_current_record(){
  local name=$1

  local cmd="aws route53 list-resource-record-sets --hosted-zone-id $zone_id"
  cmd="$cmd --start-record-name ${name} --max-items 1"
  json=$($cmd)
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

  local json=$1

  record_name=$(echo "$json" | sed -n -e 's/^.*"Name": "\([^"]*\)".*$/\1/p')
  if [ "$record_name" = "" ] ; then
    echo "no Name found" >&2
  else
    echo "current name=${record_name}"
  fi

  record_value=$(echo "$json" | sed -n -e 's/^.*"Value": "\([^"]*\)".*$/\1/p')
  if [ "${record_value}" = "" ] ; then
    echo "no Value found" >&2
  else
    echo "current value=${record_value}"
  fi

  record_type=$(echo "$json" | sed -n -e 's/^.*"Type": "\([^"]*\)".*$/\1/p')
  if [ "${record_type}" = "" ] ; then
    echo "no Type found" >&2
  else
    echo "current type=${record_type}"
  fi

  record_ttl=$(echo "$json" | sed -n -e 's/^.*"TTL": "\([^"]*\)".*$/\1/p')
  if [ "${record_ttl}" = "" ] ; then
    echo "no TTL found" >&2
  else
    echo "current ttl=${record_ttl}"
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
        "Name": "${record_name}",
        "Type": "${record_type}",
        "TTL": ${record_ttl},
        "ResourceRecords":[
          {
	    "Value": "${record_value}"
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

local new_type=$1
local new_value=$2 

read -d '' record << EOF
    {
      "Action": "CREATE",
      "ResourceRecordSet":
      {
        "Name": "${record_name}",
        "Type": "${new_type}",
        "TTL": ${record_ttl},
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
record_name=$1
local new_ip=$2

local recordjson=$(print_current_record ${record_name})
parse_record "$recordjson"

print_2_CHANGES "$(print_DELETE)" "$(print_CREATE A ${new_ip})" > changes.json

local cmd="aws route53 change-resource-record-sets --hosted-zone-id $zone_id"
cmd="$cmd --change-batch file://changes.json"

echo "$cmd"
$cmd


}

main $1 $2
#print_current_record $1
