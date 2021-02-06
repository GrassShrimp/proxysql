# ProxySQL Query Log Demo

This is a demo code for fetch query log of mysql from proxysql cluster

## Prerequisites
- [terraform](https://www.terraform.io/downloads.html)
- [docker](https://www.docker.com/products/docker-desktop) and enable kubernetes
- [skaffold](https://skaffold.dev/docs/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize)
- [mysql shell](https://dev.mysql.com/doc/mysql-shell/8.0/en/mysql-shell-install.html)
## Usage
check current context of kubernetes is __docker-desktop__
```bash
$ kubectl config current-context
```
initialize terrafrom module
```bash
$ terraform init
```
launch proxysql cluster and mysql on kubernetes
```bash
$ terraform apply -auto-approve
```
connect to mysql via proxysql
```bash
$ mysql -h localhost -P 6033 -u demo --password=demo
```
deploy code into kubernetes and check log
```bash
$ cd query_log
$ skaffold dev
```
destroy proxysql cluster and mysql from kubernetes
```bash
$ terrafrom destroy -auto-approve
```