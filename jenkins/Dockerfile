FROM jenkins/jenkins:2.263.4-lts-centos7
VOLUME /var/jenkins_home

USER root
RUN yum -y install rpm-build

COPY Fortify_SCA_and_Apps_20.2.2_linux_x64.run /tmp
COPY fortify.license /tmp
COPY installerSettings /tmp

RUN chmod +x /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run && \
    /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run --mode unattended --optionfile /tmp/installerSettings && \
    /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/bin/fortifyupdate && \
    rm /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run /tmp/fortify.license /tmp/installerSettings

RUN rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/client.properties && \
    ln -s /jenkinssecrets/client.properties \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/ && \
    rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/jre/lib/security/cacerts && \
    ln -s /jenkinssecrets/cacerts \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/jre/lib/security/ && \
    rm -f /usr/lib/jvm/adoptopenjdk-8-hotspot/jre/lib/security/cacerts && \
    ln -s /jenkinssecrets/cacerts \
	          /usr/lib/jvm/adoptopenjdk-8-hotspot/jre/lib/security/ && \
    rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/fortify.license && \
	ln -s /jenkinssecrets/fortify.license \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/

ENV FORTIFY_HOME=/opt/Fortify/Fortify_SCA_and_Apps_20.2.2
ENV PATH $FORTIFY_HOME/bin:$PATH

RUN yum -y install maven
COPY settings.xml /etc/maven/
RUN mkdir -p /tmp/fortifymvn && \
    tar xvzf /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/plugins/maven/maven-plugin-src.tar.gz -C /tmp/fortifymvn && \
	chown -R jenkins:jenkins /tmp/fortifymvn
# Will need to run the actual mvn install later so the artifacts end up on the PV

USER jenkins
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
