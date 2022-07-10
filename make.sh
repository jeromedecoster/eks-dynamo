#!/bin/bash

#
# variables
#
# AWS variables
export AWS_PROFILE=default
export AWS_REGION=eu-west-3
# project variables
export PROJECT_NAME=eks-dynamo
# the directory containing the script file
export PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"

#
# overwrite TF variables
#
export TF_VAR_project_name=$PROJECT_NAME
export TF_VAR_region=$AWS_REGION
export TF_VAR_project_dir=$PROJECT_DIR

log() { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }          # $1 uppercase background white
info() { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }       # $1 uppercase background green
warn() { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; }  # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red

# export functions : https://unix.stackexchange.com/a/22867
export -f log info warn error

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

dynamo-ecr-create() {
    export CHDIR="$PROJECT_DIR/terraform/dynamo-ecr"
    scripts/terraform-init.sh
    scripts/terraform-validate.sh
    scripts/terraform-apply.sh
}

dynamo-ecr-destroy() {
    terraform -chdir=$PROJECT_DIR/terraform/dynamo-ecr destroy -auto-approve
}

# run vote website using npm - dev mode | local
vote() {
    cd vote
    # https://unix.stackexchange.com/a/454554
    command npm install
    npx livereload . --wait 750 --extraExts 'njk' & \
        NODE_ENV=development \
        VERSION=od1s2faz \
        WEBSITE_PORT=4000 \
        DYNAMO_TABLE=$PROJECT_NAME \
        DYNAMO_REGION=$AWS_REGION \
        npx nodemon --ext js,json,njk index.js
}

vote-env() {
    AWS_ACCESS_KEY_ID=$(cat $PROJECT_DIR/.env_AWS_ACCESS_KEY_ID)
    log AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY=$(cat $PROJECT_DIR/.env_AWS_SECRET_ACCESS_KEY)
    log AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY

    cd vote
    command npm install
    npx livereload . --wait 750 --extraExts 'njk' & \
        NODE_ENV=development \
        VERSION=od1s2faz \
        WEBSITE_PORT=4000 \
        DYNAMO_TABLE=$PROJECT_NAME \
        DYNAMO_REGION=$AWS_REGION \
        AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        npx nodemon --ext js,json,njk index-env.js
}

build() {
    cd "$PROJECT_DIR/vote"
    docker image build \
        --file Dockerfile \
        --tag vote \
        .
}

build-env() {
    cd "$PROJECT_DIR/vote"
    docker image build \
        --file Dockerfile.env \
        --tag vote-env \
        .
}

run() {
    docker run \
        --rm \
        -e WEBSITE_PORT=4000 \
        -e DYNAMO_TABLE=$PROJECT_NAME \
        -e DYNAMO_REGION=$AWS_REGION \
        -p 4000:4000 \
        --name vote \
        vote
}

run-env() {
    AWS_ACCESS_KEY_ID=$(cat $PROJECT_DIR/.env_AWS_ACCESS_KEY_ID)
    log AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY=$(cat $PROJECT_DIR/.env_AWS_SECRET_ACCESS_KEY)
    log AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY
    docker run \
        --rm \
        -e WEBSITE_PORT=4000 \
        -e DYNAMO_TABLE=$PROJECT_NAME \
        -e DYNAMO_REGION=$AWS_REGION \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        -p 4000:4000 \
        --name vote-env \
        vote-env
}

stop() {
    docker rm --force vote 2>/dev/null
}

stop-env() {
    docker rm --force vote-env 2>/dev/null
}

ecr-push() {
    info MAKE build
    build

    info MAKE build-env
    build-env

    AWS_ACCOUNT_ID=$(cat $PROJECT_DIR/.env_AWS_ACCOUNT_ID)
    log AWS_ACCOUNT_ID $AWS_ACCOUNT_ID

    REPOSITORY_URL=$(cat $PROJECT_DIR/.env_REPOSITORY_URL)
    log REPOSITORY_URL $REPOSITORY_URL

    # add login data into /home/$USER/.docker/config.json (create or update authorization token)
    aws ecr get-login-password \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        | docker login \
        --username AWS \
        --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    # https://docs.docker.com/engine/reference/commandline/tag/
    docker tag vote $REPOSITORY_URL:vote
    # https://docs.docker.com/engine/reference/commandline/push/
    docker push $REPOSITORY_URL:vote

    docker tag vote-env $REPOSITORY_URL:vote-env
    docker push $REPOSITORY_URL:vote-env
}

vpc-eks-create() {
    export CHDIR="$PROJECT_DIR/terraform/vpc-eks"
    scripts/terraform-init.sh
    scripts/terraform-validate.sh
    scripts/terraform-apply.sh
}

vpc-eks-destroy() {
    kubectl config use-context $PROJECT_NAME
    kubectl config current-context
    
    kubectl delete ns vote --ignore-not-found --wait

    terraform -chdir=$PROJECT_DIR/terraform/vpc-eks destroy -auto-approve

    AWS_ACCOUNT_ID=$(cat $PROJECT_DIR/.env_AWS_ACCOUNT_ID)
    log AWS_ACCOUNT_ID $AWS_ACCOUNT_ID

    kubectl config delete-context $PROJECT_NAME
    kubectl config delete-cluster arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/$PROJECT_NAME
}

kubectl-vote() {
    REPOSITORY_URL=$(cat $PROJECT_DIR/.env_REPOSITORY_URL)
    log REPOSITORY_URL $REPOSITORY_URL
    
    kubectl apply --filename k8s/namespace.yaml
    kubectl apply --filename k8s/service.yaml

    # https://github.com/frigus02/kyml#kyml-tmpl---inject-dynamic-values
    kyml tmpl \
        -v DYNAMO_TABLE=$PROJECT_NAME \
        -v DYNAMO_REGION=$AWS_REGION \
        -v DOCKER_IMAGE=$REPOSITORY_URL:vote \
        < k8s/deployment-vote.yaml \
        | kubectl apply -f -
}

kubectl-vote-sa() {
    REPOSITORY_URL=$(cat $PROJECT_DIR/.env_REPOSITORY_URL)
    log REPOSITORY_URL $REPOSITORY_URL
    
    kubectl apply --filename k8s/namespace.yaml
    kubectl apply --filename k8s/service.yaml

    # https://github.com/frigus02/kyml#kyml-tmpl---inject-dynamic-values
    kyml tmpl \
        -v DYNAMO_TABLE=$PROJECT_NAME \
        -v DYNAMO_REGION=$AWS_REGION \
        -v DOCKER_IMAGE=$REPOSITORY_URL:vote \
        < k8s/deployment-vote-with-sa.yaml \
        | kubectl apply -f -

}

kubectl-vote-log() {
    # https://stackoverflow.com/a/51612372
    POD_NAME=$(kubectl get pod --selector app=vote --output name --no-headers=true --namespace vote)

    # AccessDeniedException: User: arn:aws:sts::xxxxx:assumed-role/green-eks-node-group-xxxxx/i-xxxxx is not authorized to perform: 
    # dynamodb:GetItem on resource: arn:aws:dynamodb:eu-west-3:xxxxx:table/eks-dynamo because no identity-based policy 
    # allows the dynamodb:GetItem action
    kubectl logs $POD_NAME --follow --namespace vote
}

load-balancer() {
    LOAD_BALANCER=$(kubectl get svc vote \
        --namespace vote \
        --output json \
        | jq --raw-output '.status.loadBalancer.ingress[0].hostname')
    log LOAD_BALANCER $LOAD_BALANCER
}

kubectl-vote-env() {
    REPOSITORY_URL=$(cat $PROJECT_DIR/.env_REPOSITORY_URL)
    log REPOSITORY_URL $REPOSITORY_URL

    AWS_ACCESS_KEY_ID=$(cat $PROJECT_DIR/.env_AWS_ACCESS_KEY_ID)
    log AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID

    AWS_SECRET_ACCESS_KEY=$(cat $PROJECT_DIR/.env_AWS_SECRET_ACCESS_KEY)
    log AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY

    kubectl apply --filename k8s/namespace.yaml
    kubectl apply --filename k8s/service.yaml

    # https://github.com/frigus02/kyml#kyml-tmpl---inject-dynamic-values
    kyml tmpl \
        -v DYNAMO_TABLE=$PROJECT_NAME \
        -v DYNAMO_REGION=$AWS_REGION \
        -v DOCKER_IMAGE=$REPOSITORY_URL:vote-env \
        -v AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -v AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        < k8s/deployment-vote-env.yaml \
        | kubectl apply -f -
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && {
    info execute $1
    eval $1
} || usage
exit 0
