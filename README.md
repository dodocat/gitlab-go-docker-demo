# 基于 Gitlab 交付 Go 程序的 Docker 镜像

Gitlab 提供了完整 CI/CD 功能并且集成了 docker 镜像服务, 可以在此基础上快速实现 docker 镜像交付.

样例工程目录结构如下[https://github.com/dodocat/gitlab-go-docker-demo](https://github.com/dodocat/gitlab-go-docker-demo):

```
├── .gitlab-ci.yml
├── Dockerfile
├── Gopkg.lock
├── Gopkg.toml
├── README.md
├── app.conf
├── main.go
└── vendor
```

## 依赖管理

项目使用 golang 官方包管理工具 `dep` 进行依赖管理, 参考官方文档: [https://github.com/golang/dep](https://github.com/golang/dep)

直接通过 go get 安装 dep

```
go get -u github.com/golang/dep/cmd/dep
```

记得设置环境变量

```
export PATH=$PATH:$GOPATH/bin
```

在工程根目录初始 dep

```
dep init
```

执行之后会生成  `Gopkg.toml` `Gopkg.lock` `vendor/` 这三文件都需要 commit 进入版本管理系统. 所有的依赖文件都在 `vendor/` 目录里. 详细信息参阅 dep 文档. 添加新库或者更新了已有库导致 `vendor` 目录变更, 需要将变更 commit 进入版本管理里.

## Dockerfile

编写 Dockerfile:

```
FROM golang:1.9.0
WORKDIR /app

ADD main /app/
ADD app.conf /app/app.conf
ENTRYPOINT ["/app/main"]
```

## Gitlab registry

Gitlab 内集成了 registry 可以为所有项目提供 docker 镜像服务. 

```
go build -o main
docker login # 输入用户名密码登陆
docker built -t registry.gitlab.example.com/group/project -f Dockerfile . # 编译 Docker 镜像
docker push registry.gitlab.example.com/group/project # 把 docker 镜像发布到 gitlab registry
```

本地测试docker环境编译执行:

```
go build -o main
docker build -t gitlab-go-docker-demo docker/test/Dockerfile .
docker run gitlab-go-docker-demo
```

## Gitlab CI 配置

CI 配置文件 `.gitlab-ci.yml` 内容如下

```
image: golang:1.9.0

stages:
  - test
  - build
  - deploy

before_script:
  - mkdir -p $GOPATH/src/$(echo $CI_PROJECT_URL | sed 's/^http\(\|s\):\/\///g') && cd $_ && cd .. && rm -rf $CI_PROJECT_NAME
  - ln -sf $CI_PROJECT_DIR
  - cd $CI_PROJECT_NAME
  - pwd

test:
  stage: test
  script:
    - go test

build:
  stage: build
  script:
    - go build -o main
  artifacts:
      expire_in: 1 week
      paths:
        - main

deploy:
  image: docker:git
  services:
    - docker:dind
  stage: deploy
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE/$CI_COMMIT_REF_NAME -f docker/test/Dockerfile .
    - docker push $CI_REGISTRY_IMAGE/$CI_COMMIT_REF_NAME:latest
```

## 部署

在服务器上登陆 docker registry:

```
docker login registry.gitlab.dreamdev.cn
```

登陆成功后拉取 docker 镜像:

```
# 以测试服务器为例, 正式服务器需指定相应版本
docker pull registry.gitlab.examlple.com/group/project/test:latest
```

运行:

```
docker run -p 80:80 -v /var/log/:/app/log/ --restart unless-stopped registry.gitlab.example.com/group/project/test
```

## 参考阅读
* https://github.com/golang/dep

* https://docs.gitlab.com/ce/ci/docker/using_docker_build.html
  详解了如何配置 gitlab-ci docker 构建

* https://about.gitlab.com/2016/05/23/gitlab-container-registry/
  介绍了关于 gitlab container registry 的使用

* https://blog.stackahoy.io/a-guide-to-automated-docker-deployments-w-gitlab-ci-510966dd6022
  云服务商 stackahoy.io 关于 go 的部署教程

* https://docs.gitlab.com/ee/ci/yaml/
* https://docs.gitlab.com/ee/ci/variables/README.html
