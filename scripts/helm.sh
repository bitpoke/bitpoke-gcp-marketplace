#!/bin/bash

# NOTE: this is deprecated, we are using helm v3 which don't requires tiller
# this will be removed in the future versions.

# kill subporcess when exiting
trap "kill 0" EXIT

TILLER_NAMESPACE=presslabs-system

# start tiller
TILLER_NAMESPACE=$TILLER_NAMESPACE \
    tiller -history-max=10 -storage=secret 2>/dev/null &

# run helm
HELM_HOST=localhost:44134 \
    helm $@
