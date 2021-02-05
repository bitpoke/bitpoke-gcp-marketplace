#!/bin/bash

dir_path=${1:-.}
shift
manifests=${@}

chartFile=.build/files_from_chart.txt
filesInKustomizeFile=.build/files_from_kustomize.txt

# lists files from chart and filter them
find $dir_path -name '*.yaml' |\
    grep -v 'controller-clusterrole-kubebuilder.yaml' |\
    sed 's/.build\/manifest/../g' | sort > $chartFile

echo -n "" > $filesInKustomizeFile.tmp
for kustomizationFile in $manifests; do
    yq r $kustomizationFile resources | sed '/^#/d' >> $filesInKustomizeFile.tmp
done

# lists files from kustomization files and filter them
cat $filesInKustomizeFile.tmp | awk '{print $2}' |\
    grep -v 'namespace.yaml' |\
    grep -v 'google-config-connector-crds.yaml' |\
    sort > $filesInKustomizeFile

rm $filesInKustomizeFile.tmp

diff $chartFile $filesInKustomizeFile
