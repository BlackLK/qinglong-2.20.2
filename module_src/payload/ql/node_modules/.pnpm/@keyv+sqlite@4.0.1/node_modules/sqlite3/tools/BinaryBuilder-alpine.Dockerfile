ARG TARGET

FROM python:3.10-alpine3.15

RUN apk add make g++ nodejs npm && npm install -g yarn

WORKDIR /usr/src/build

COPY . .

RUN yarn install --ignore-scripts

ENV CFLAGS="${CFLAGS:-} -include ../src/gcc-preinclude.h"
ENV CXXFLAGS="${CXXFLAGS:-} -include ../src/gcc-preinclude.h"

RUN yarn node-pre-gyp install --build-from-source --target_arch="$TARGET"

RUN yarn node-pre-gyp package --target_arch="$TARGET"

CMD ["sh"]
