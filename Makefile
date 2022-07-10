.SILENT:
.PHONY: vote

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'


dynamo-ecr-create: # 1) terraform create dynamo table + ecr repo + iam user
	./make.sh dynamo-ecr-create

vote: # 1) run vote website using npm - dev mode
	./make.sh vote

build: # 1) build vote image
	./make.sh build

run: # 1) run vote image
	./make.sh run

stop: # 1) stop vote container
	./make.sh stop

vote-env: # 2) run vote website using npm - dev mode
	./make.sh vote-env

build-env: # 2) build vote-env image
	./make.sh build-env

run-env: # 2) run vote-env image
	./make.sh run-env

stop-env: # 2) stop vote-env container
	./make.sh stop-env

ecr-push: # 2) push vote + vote-env image to ecr
	./make.sh ecr-push

vpc-eks-create: # 3) terraform create vpc + eks cluster
	./make.sh vpc-eks-create

kubectl-vote: # 3) kubectl deploy vote
	./make.sh kubectl-vote

kubectl-vote-log: # 3) kubectl logs vote app
	./make.sh kubectl-vote-log

load-balancer: # 3) get load balancer url
	./make.sh load-balancer

kubectl-vote-env: # 3) kubectl deploy vote-env
	./make.sh kubectl-vote-env

kubectl-vote-sa: # 4) kubectl deploy vote with service-account
	./make.sh kubectl-vote-sa

vpc-eks-destroy: # 5) terraform destroy vpc + eks cluster
	./make.sh vpc-eks-destroy

dynamo-ecr-destroy: # 5) terraform destroy dynamo table + ecr repo + iam user
	./make.sh dynamo-ecr-destroy
