FROM openjdk:8-jre

# based on https://github.com/vepo/jmeter-docker

ENV JMETER_VERSION 5.4

RUN mkdir /jmeter \
    && cd /jmeter/ \
    && wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-$JMETER_VERSION.tgz \
    && tar -xvzf apache-jmeter-$JMETER_VERSION.tgz \
    && rm apache-jmeter-$JMETER_VERSION.tgz

ENV JMETER_HOME /jmeter/apache-jmeter-$JMETER_VERSION/
ENV PATH $JMETER_HOME/bin:$PATH


WORKDIR /opt/jmeter