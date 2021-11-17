FROM openjdk:8-jdk-buster

ADD Fortify_ScanCentral_Controller_20.2.0_x64.zip /tmp 
RUN unzip /tmp/Fortify_ScanCentral_Controller_20.2.0_x64.zip -d /usr/local && \
    chmod +x /usr/local/tomcat/bin/*.sh && \
	rm /tmp/Fortify_ScanCentral_Controller_20.2.0_x64.zip

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
WORKDIR $CATALINA_HOME

EXPOSE 8080
CMD ["catalina.sh", "run"]

RUN rm -f /usr/local/tomcat/conf/server.xml && \
    ln -s /sastctrlsecrets/server.xml \
              /usr/local/tomcat/conf/ && \
	rm -f /usr/local/openjdk-8/jre/lib/security/cacerts && \
    ln -s /sastctrlsecrets/cacerts \
	          /usr/local/openjdk-8/jre/lib/security/
