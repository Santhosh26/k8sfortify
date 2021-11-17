FROM openjdk:8-jdk-buster

ADD SonatypeFortifyIntegration-20.1.20200914.jar /root/

RUN rm -f /usr/local/openjdk-8/jre/lib/security/cacerts && \
    ln -s /nexusiqsyncsecrets/cacerts \
	          /usr/local/openjdk-8/jre/lib/security/

WORKDIR /nexusiqsyncsecrets
ENTRYPOINT ["java", "-jar", "/root/SonatypeFortifyIntegration-20.1.20200914.jar"]
