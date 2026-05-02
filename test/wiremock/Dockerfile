FROM openjdk:8-jre

# based on https://github.com/rodolpheche/wiremock-docker/blob/master/Dockerfile

ENV WIREMOCK_VERSION 2.27.2

# grab wiremock standalone jar
RUN mkdir -p /var/wiremock/lib/ \
  && wget https://repo1.maven.org/maven2/com/github/tomakehurst/wiremock-jre8-standalone/$WIREMOCK_VERSION/wiremock-jre8-standalone-$WIREMOCK_VERSION.jar \
    -O /var/wiremock/lib/wiremock-jre8-standalone.jar

WORKDIR /home/wiremock
VOLUME /home/wiremock

EXPOSE 8080 8443

CMD java $JAVA_OPTS -cp /var/wiremock/lib/*:/var/wiremock/extensions/* com.github.tomakehurst.wiremock.standalone.WireMockServerRunner