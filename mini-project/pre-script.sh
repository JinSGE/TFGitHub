#!/bin/bash

# 에러 스크립트 내용 중 실패하면 바로 종료
set -e

DIR=$HOME/tf/minipro1

cat <<EOF
############################################################
# 다음 과정은 키 쌍 생성하고, 개발자 환경을 구축합니다.              #
############################################################
EOF

# 키 쌍 입력
echo -n "[ INFO ] 키 쌍 이름을 입력하시오(예: mykeypair): "
read FILE

# 키 쌍 생성
ssh-keygen -t rsa -N "" -f ~/.ssh/$FILE \
  && echo "[ OK ] 키 쌍이 생성되었습니다."

# 환경 구축 시작
echo "[ INFO ] 개발자 환경을 구축합니다."
cd $DIR

sed -i "s/mykeypair/$FILE/g" $DIR/main.tf

# terraform init
# terraform plan
# terraform apply -auto-approve \
#   && echo "[ OK ] 인프라가 완성되었습니다. 다음 스텝을 진행합니다."