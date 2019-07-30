#!/bin/bash

dir_path=${1:-.}
shift
manifests=${@}

chartFile=.build/files_from_chart.txt
filesinKustomizeFile=.build/files_from_kustomize.txt

find $dir_path -name '*.yaml' |\
    grep -v '/prometheus-operator/charts/' |\
    grep -v '/prometheus-operator/templates/prometheus/' |\
    grep -v '/prometheus-operator/templates/grafana' |\
    grep -v '/prometheus-operator/templates/prometheus-operator/servicemonitor.yaml' |\
    grep -ve '/prometheus-operator/.*/exporters/' |\
    grep -ve '/cert-manager/.*/serviceaccount.yaml' |\
    grep -v 'controller-clusterrole-kubebuilder.yaml' |\
    grep -v 'application-crd.yaml' |\
    grep -v 'smtp-defaults.yaml' |\
    sed 's/.build\/manifest/../g' | sort > $chartFile

echo -n "" > $filesinKustomizeFile.tmp
for kustomizationFile in $manifests; do
    yq r $kustomizationFile resources >> $filesinKustomizeFile.tmp
done

cat $filesinKustomizeFile.tmp | awk '{print $2}' | sort > $filesinKustomizeFile
rm $filesinKustomizeFile.tmp

diff $chartFile $filesinKustomizeFile
