# Kubectl in a docker

The prupose of this tool is to have a subset of commands totally portable to operate a k8s cluster. This is heavily inspired by the [kubectl-container](https://github.com/Piotr1215/kubectl-container)

## What does it include
The default container image includes the follwing tools:
- `kubectl`: k8s command line
- `awscli`: AWS command line
- `krew`: plugins manager for kubectl (with default plugins already setup)
- `yq`: same as `jq` but for YAML file (ex: `kubectl get endpoints mongodb-staging-svc -o yaml | yq`)
- `k9s`: k8s dashboarding tools
- `fzf`: Fuzzy search
- `helm`: k8s package manager
- `velero`: velero command line
- `direnv`: in case you would like to customized your `${HOME}`

## Bash completion:
Bash completion is available for:
- kubectl
- fzf

## Bash PS1
To have a better visibility when handling you k8s cluster [kube_ps1](https://github.com/jonmosco/kube-ps1) is also used for your prompt.

## How to build it
Use your favorite docker image builder (in the example `buildah`)
```
 buildah bud --format docker -t docker.io/localregistry/kubectl-container:$(date "+%Y%m%d") Dockerfile
```

## How to use it
Just use your favorite container orchestrator (in the example `podman`)
```
podman run --rm --name kubectl$(basename $(tty)) --tty=true --interactive --volume ~/.aws:/root/.aws --volume ~/.kube:/root/.kube docker.io/localregistry/kubectl-container:20220913
```
