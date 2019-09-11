#!/bin/bash

dir_path=${1:-.}
shift
manifests=${@}

chartFile=.build/files_from_chart.txt
filesinKustomizeFile=.build/files_from_kustomize.txt

find $dir_path -name '*.yaml' |\
    grep -v '/prometheus-operator/' |\
    grep -ve '/cert-manager/.*/serviceaccount.yaml' |\
    grep -v 'controller-clusterrole-kubebuilder.yaml' |\
    grep -v 'application-crd.yaml' |\
    grep -v 'application.yaml' |\
    grep -v 'smtp-defaults.yaml' |\
    sed 's/.build\/manifest/../g' | sort > $chartFile

echo -n "" > $filesinKustomizeFile.tmp
for kustomizationFile in $manifests; do
    yq r $kustomizationFile resources >> $filesinKustomizeFile.tmp
done

cat $filesinKustomizeFile.tmp | awk '{print $2}' | grep -v 'application.yaml' | sort > $filesinKustomizeFile
rm $filesinKustomizeFile.tmp

diff $chartFile $filesinKustomizeFile
