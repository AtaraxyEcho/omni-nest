FROM eclipse-temurin:21-jre

RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY omninest-app/target/omninest-app-*.jar app.jar

# 镜像默认生产 profile；开发对照构建可用 --build-arg OMNINEST_PROFILE=dev 覆盖。
ARG OMNINEST_PROFILE=prod
ENV OMNINEST_PROFILE=${OMNINEST_PROFILE} \
    OMNINEST_ROLE=api
EXPOSE 8080

ENTRYPOINT ["java", "-Duser.timezone=Asia/Shanghai", "-jar", "/app/app.jar"]
