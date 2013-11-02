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
  record_name=$(echo "$json" | sed -n -e 's/^.*\"Name\": \"\(.*\)\".*$/\1/p')
  match=$(echo "$record_name" | sed -n -e "/${name}/p") 
  if [ -n $match ] ; then
    echo $json
  else
    echo "no record found for $name" >&2  
  fi
}

function parse_record(){

  local json=$1

  record_name=$(echo "$json" | sed -n -e 's/^.*\"Name\": \"\(.*\)\".*$/\1/p')
  if [ -n $record_name ] ; then
    echo "current name=${record_name}"
  else
    echo "no Name found" >&2

  record_value=$(echo "$json" | sed -n -e 's/^.*\"Value\": \"\(.*\)\".*$/\1/p')
  if [ -n ${record_value} ] ; then
    echo "current value=${record_value}"
  else
    echo "no Value found" >&2

  record_type=$(echo "$json" | sed -n -e 's/^.*\"Type\": "\(.*\)".*$/\1/p')
  if [ -n ${record_type} ] ; then
    echo "current type=${record_type}"
  else
    echo "no Type found" >&2

  record_ttl=$(echo "$json" | sed -n -e 's/^.*\"TTL\": \([0-9]*\).*$/\1/p')
  if [ -n ${record_ttl} ] ; then
    echo "current ttl=${record_ttl}"
  else
    echo "no TTL found" >&2


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

