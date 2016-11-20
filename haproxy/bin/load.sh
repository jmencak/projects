#!/bin/sh

cluster_loader_dir=/root/svt/openshift_scalability
routes=$(printf "%04d" $(oc get routes --all-namespaces | grep hello-openshift | wc -l))
template=../apps/hello-openshift/hello-openshift.json
project_basename=hello-openshift-
projects=180	# 10, 20, 30, 60, 180
project_start=125
templates=10	# templates per project

max_not_running() {
  local max_not_running="${1:-10}"
  local not_running

  while true
  do
    not_running=$(oc get pods --all-namespaces --no-headers | grep -v Running | wc -l)
    test "$not_running" -le "$max_not_running" && break
    echo "$not_running pods not running"
    sleep 1
  done
}

new_project_or_reuse() {
  local project="$1"

  if oc project $project 2>&1 ; then
    # $project exists, recycle it
    for res in rc dc bc pod service route ; do
      oc delete $res --all -n $project 2>&1
    done
  else
    # $project doesn't exist
    oc new-project $project
  fi
}

main() {
  local project
  local data=$(printf "%1024s"|tr ' ' '.')	# data to send back from hello pods

  for p in $(seq $project_start $projects)
  do
    project=${project_basename}$p
    new_project_or_reuse $project
    i=1
    while test $i -le $templates
    do
      oc process -vIDENTIFIER=$i -vREPLICAS=1 -vRESPONSE="$data" -f $template | \
        oc create -f- -n $project
      i=$((i+1))
      
      max_not_running 5
    done
  done
}

main
